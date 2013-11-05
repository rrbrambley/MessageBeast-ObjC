//
//  AATTADNDatabase.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/30/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTADNDatabase.h"
#import "AATTDisplayLocation.h"
#import "AATTDisplayLocationInstances.h"
#import "AATTGeolocation.h"
#import "AATTHashtagInstances.h"
#import "AATTMessagePlus.h"
#import "AATTOrderedMessageBatch.h"
#import "FMDatabase.h"
#import "FMDatabaseQueue.h"
#import "NSOrderedDictionary.h"

@interface AATTADNDatabase ()
@property FMDatabaseQueue *databaseQueue;
@end

@implementation AATTADNDatabase

+ (AATTADNDatabase *)sharedInstance {
    static AATTADNDatabase *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[AATTADNDatabase alloc] init];
    });
    
    return _sharedInstance;
}

#pragma mark - Table creation

static NSString *const kCreateMessagesTable = @"CREATE TABLE IF NOT EXISTS messages (message_id TEXT PRIMARY KEY, message_channel_id TEXT NOT NULL, message_date INTEGER NOT NULL, message_json TEXT NOT NULL)";

static NSString *const kCreateDisplayLocationInstancesTable = @"CREATE TABLE IF NOT EXISTS location_instances (location_name TEXT NOT NULL, location_message_id TEXT NOT NULL, location_channel_id TEXT NOT NULL, location_latitude REAL NOT NULL, location_longitude REAL NOT NULL, location_factual_id TEXT, location_date INTEGER NOT NULL, PRIMARY KEY (location_name, location_message_id, location_latitude, location_longitude))";

static NSString *const kCreateHashtagInstancesTable = @"CREATE TABLE IF NOT EXISTS hashtag_instances (hashtag_name TEXT NOT NULL, hashtag_message_id TEXT NOT NULL, hashtag_channel_id TEXT NOT NULL, hashtag_date INTEGER NOT NULL, PRIMARY KEY (hashtag_name, hashtag_message_id))";

static NSString *const kCreateOEmbedInstancesTable = @"CREATE TABLE IF NOT EXISTS oembed_instances (oembed_type TEXT NOT NULL, oembed_message_id TEXT NOT NULL, oembed_channel_id TEXT NOT NULL, oembed_count INTEGER NOT NULL, oembed_date INTEGER NOT NULL, PRIMARY KEY(oembed_type, oembed_message_id))";

static NSString *const kCreateGeolocationsTable = @"CREATE TABLE IF NOT EXISTS geolocations (geolocation_locality TEXT NOT NULL, geolocation_sublocality TEXT, geolocation_latitude REAL NOT NULL, geolocation_longitude REAL NOT NULL, PRIMARY KEY (geolocation_latitude, geolocation_longitude))";

#pragma mark - Initializer

- (id)init {
    self = [super init];
    if(self) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSString *writableDBPath = [documentsDirectory stringByAppendingPathComponent:@"aattadndatabbase.sqlite3"];
        
        self.databaseQueue = [FMDatabaseQueue databaseQueueWithPath:writableDBPath];
        [self.databaseQueue inDatabase:^(FMDatabase *db) {
            [db setLogsErrors:YES];
            
            [db executeUpdate:kCreateMessagesTable];
            [db executeUpdate:kCreateDisplayLocationInstancesTable];
            [db executeUpdate:kCreateHashtagInstancesTable];
            [db executeUpdate:kCreateOEmbedInstancesTable];
            [db executeUpdate:kCreateGeolocationsTable];
        }];
    }
    return self;
}

#pragma mark - Insertion

- (void)insertOrReplaceMessage:(AATTMessagePlus *)messagePlus {
    static NSString *insertOrReplaceMessage = @"INSERT OR REPLACE INTO messages (message_id, message_channel_id, message_date, message_json) VALUES(?, ?, ?, ?)";
    [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollBack) {
        NSString *jsonString = [self JSONStringWithMessage:messagePlus.message];
        if(![db executeUpdate:insertOrReplaceMessage, messagePlus.message.messageID, messagePlus.message.channelID, [NSNumber numberWithDouble:[messagePlus.displayDate timeIntervalSince1970]], jsonString]) {
            *rollBack = YES;
        }
    }];
}

- (void)insertOrReplaceGeolocation:(AATTGeolocation *)geolocation {
    static NSString *insertOrReplaceGeolocation = @"INSERT OR REPLACE INTO geolocations (geolocation_locality, geolocation_sublocality, geolocation_latitude, geolocation_longitude) VALUES(?, ?, ?, ?)";
    [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollBack) {
        double latitude = [self roundValue:geolocation.latitude decimalPlaces:3];
        double longitude = [self roundValue:geolocation.longitude decimalPlaces:3];
        if(![db executeUpdate:insertOrReplaceGeolocation, geolocation.locality, geolocation.subLocality, [NSNumber numberWithDouble:latitude], [NSNumber numberWithDouble:longitude]]) {
            *rollBack = YES;
        }
    }];
}

- (void)insertOrReplaceDisplayLocationInstance:(AATTMessagePlus *)messagePlus {
    if(messagePlus.displayLocation) {
        static NSString *insertOrReplaceDisplayLocationInstance = @"INSERT OR REPLACE INTO location_instances (location_name, location_message_id, location_channel_id, location_latitude, location_longitude, location_factual_id, location_date) VALUES(?, ?, ?, ?, ?, ?, ?)";
        [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollBack) {
            AATTDisplayLocation *l = messagePlus.displayLocation;
            NSString *name = l.name;
            NSString *messageID = messagePlus.message.messageID;
            NSString *channelID = messagePlus.message.channelID;
            NSNumber *latitude = [NSNumber numberWithDouble:l.latitude];
            NSNumber *longitude = [NSNumber numberWithDouble:l.longitude];
            NSString *factualID = l.factualID;
            NSNumber *date = [NSNumber numberWithDouble:[messagePlus.displayDate timeIntervalSince1970]];
            
            if(![db executeUpdate:insertOrReplaceDisplayLocationInstance, name, messageID, channelID, latitude, longitude, factualID, date]) {
                *rollBack = YES;
            }
        }];
    }
}

- (void)insertOrReplaceHashtagInstances:(AATTMessagePlus *)messagePlus {
    NSArray *hashtags = messagePlus.message.entities.hashtags;
    if(hashtags.count > 0) {
        static NSString *insertOrReplaceHashtagInstances = @"INSERT OR REPLACE INTO hashtag_instances (hashtag_name, hashtag_message_id, hashtag_channel_id, hashtag_date) VALUES(?, ?, ?, ?)";
        [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollBack) {
            
            for(ANKHashtagEntity *hashtag in hashtags) {
                NSString *name = hashtag.hashtag;
                NSString *messageID = messagePlus.message.messageID;
                NSString *channelID = messagePlus.message.channelID;
                NSNumber *date = [NSNumber numberWithDouble:[messagePlus.displayDate timeIntervalSince1970]];
                
                if(![db executeUpdate:insertOrReplaceHashtagInstances, name, messageID, channelID, date]) {
                    *rollBack = YES;
                    return;
                }
            }
        }];
    }
}

- (void)insertOrReplaceOEmbedInstances:(AATTMessagePlus *)messagePlus {
    [self insertOrReplaceOEmbedInstances:messagePlus OEmbedAnnotations:messagePlus.photoOEmbeds];
    [self insertOrReplaceOEmbedInstances:messagePlus OEmbedAnnotations:messagePlus.html5VideoOEmbeds];
}

- (void)insertOrReplaceOEmbedInstances:(AATTMessagePlus *)messagePlus OEmbedAnnotations:(NSArray *)OEmbedAnnotations {
    if(OEmbedAnnotations.count > 0) {
        static NSString *insertOrReplaceOEmbedInstance = @"INSERT OR REPLACE INTO oembed_instances (oembed_type, oembed_message_id, oembed_channel_id, oembed_count, oembed_date) VALUES (?, ?, ?, ?, ?)";
        [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollBack) {
            ANKAnnotation *annotation = [OEmbedAnnotations objectAtIndex:0];
            NSString *type = [[annotation value] objectForKey:@"type"];
            NSString *messageID = messagePlus.message.messageID;
            NSString *channelID = messagePlus.message.channelID;
            NSNumber *count = [NSNumber numberWithUnsignedInteger:OEmbedAnnotations.count];
            NSNumber *date = [NSNumber numberWithDouble:[messagePlus.displayDate timeIntervalSince1970]];
            
            if(![db executeUpdate:insertOrReplaceOEmbedInstance, type, messageID, channelID, count, date]) {
                *rollBack = YES;
                return;
            }
        }];
    }
}

#pragma mark - Retrieval

- (AATTOrderedMessageBatch *)messagesInChannelWithID:(NSString *)channelId limit:(NSUInteger)limit {
    return [self messagesInChannelWithID:channelId beforeDate:nil limit:limit];
}

- (AATTOrderedMessageBatch *)messagesInChannelWithID:(NSString *)channelId beforeDate:(NSDate *)beforeDate limit:(NSUInteger)limit {
    
    NSMutableArray *args = [NSMutableArray arrayWithCapacity:2];
    [args addObject:channelId];
    NSString *select = @"SELECT * FROM messages WHERE message_channel_id = ?";
    if(beforeDate) {
        select = [NSString stringWithFormat:@"%@ %@", select, @" AND message_date < ?"];
        [args addObject:[NSNumber numberWithDouble:[beforeDate timeIntervalSince1970]]];
    }
    
    select = [NSString stringWithFormat:@"%@ ORDER BY message_date DESC LIMIT %d", select, limit];
    
    __block NSMutableOrderedDictionary *messagePlusses = [NSMutableOrderedDictionary orderedDictionaryWithCapacity:limit];
    __block NSString *maxID = nil;
    __block NSString *minID = nil;
    
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQuery:select withArgumentsInArray:args];
        
        ANKMessage *m = nil;
        while([resultSet next]) {
            NSString *messageID = [resultSet stringForColumnIndex:0];
            NSDate *date = [NSDate dateWithTimeIntervalSince1970:[resultSet doubleForColumnIndex:2]];
            NSString *messageString = [resultSet stringForColumnIndex:3];
            NSDictionary *messageJSON = [self JSONDictionaryWithString:messageString];
            m = [[ANKMessage alloc] initWithJSONDictionary:messageJSON];
            
            AATTMessagePlus *messagePlus = [[AATTMessagePlus alloc] initWithMessage:m];
            [messagePlus setDisplayDate:date];
            [messagePlusses setObject:messagePlus forKey:messageID];
            
            if(!maxID) {
                maxID = messageID;
            }
        }
        if(m) {
            minID = m.messageID;
        }
    }];
    
    AATTMinMaxPair *minMaxPair = [[AATTMinMaxPair alloc] init];
    minMaxPair.minID = minID;
    minMaxPair.maxID = maxID;
    return [[AATTOrderedMessageBatch alloc] initWithOrderedMessagePlusses:messagePlusses minMaxPair:minMaxPair];
}

- (AATTOrderedMessageBatch *)messagesInChannelWithID:(NSString *)channelID messageIDs:(NSSet *)messageIDs {
    __block NSMutableOrderedDictionary *messagePlusses = [[NSMutableOrderedDictionary alloc] initWithCapacity:messageIDs.count];
    __block NSString *maxID = nil;
    __block NSString *minID = nil;
    
    NSString *select = @"SELECT message_id, message_date, message_json FROM messages WHERE message_channel_id = ? AND message_id IN (";
    NSMutableArray *args = [NSMutableArray arrayWithCapacity:(messageIDs.count + 1)];
    [args addObject:channelID];
    
    NSUInteger index = 1;
    for(NSString *messageID in messageIDs) {
        [args addObject:messageID];
        
        NSString *append;
        if(index > 1) {
            append = @", ?";
        } else {
            append = @" ?";
        }
        select = [NSString stringWithFormat:@"%@%@", select, append];
        index++;
    }
    select = [NSString stringWithFormat:@"%@ ) ORDER BY message_date DESC", select];

    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQuery:select withArgumentsInArray:args];
        
        ANKMessage *m = nil;
        while([resultSet next]) {
            NSString *messageID = [resultSet stringForColumnIndex:0];
            NSDate *date = [NSDate dateWithTimeIntervalSince1970:[resultSet doubleForColumnIndex:1]];
            NSString *messageString = [resultSet stringForColumnIndex:2];
            NSDictionary *messageJSON = [self JSONDictionaryWithString:messageString];
            m = [[ANKMessage alloc] initWithJSONDictionary:messageJSON];
            
            AATTMessagePlus *messagePlus = [[AATTMessagePlus alloc] initWithMessage:m];
            [messagePlus setDisplayDate:date];
            [messagePlusses setObject:messagePlus forKey:messageID];
            
            if(!maxID) {
                maxID = messageID;
            }
        }
        if(m) {
            minID = m.messageID;
        }
    }];
    
    AATTMinMaxPair *minMaxPair = [[AATTMinMaxPair alloc] init];
    minMaxPair.minID = minID;
    minMaxPair.maxID = maxID;
    return [[AATTOrderedMessageBatch alloc] initWithOrderedMessagePlusses:messagePlusses minMaxPair:minMaxPair];
}

- (NSArray *)displayLocationInstancesInChannelWithID:(NSString *)channelID {
    static NSString *select = @"SELECT location_name, location_message_id, location_latitude, location_longitude FROM location_instances WHERE location_channel_id = ? ORDER BY location_date DESC";
    
    NSMutableOrderedDictionary *allInstances = [[NSMutableOrderedDictionary alloc] init];
    
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQuery:select, channelID];
        while([resultSet next]) {
            NSString *name = [resultSet stringForColumnIndex:0];
            NSString *messageID = [resultSet stringForColumnIndex:1];
            double latitude = [resultSet doubleForColumnIndex:2];
            double longitude = [resultSet doubleForColumnIndex:3];
            
            NSString *roundedLatitude = [self roundedValueAsString:latitude decimalPlaces:1];
            NSString *roundedLongitude = [self roundedValueAsString:longitude decimalPlaces:1];
            NSString *key = [NSString stringWithFormat:@"%@ %@ %@", name, roundedLatitude, roundedLongitude];
            AATTDisplayLocationInstances *instances = [allInstances objectForKey:key];
            if(!instances) {
                AATTDisplayLocation *loc = [[AATTDisplayLocation alloc] initWithName:name latitude:latitude longitude:longitude];
                instances = [[AATTDisplayLocationInstances alloc] initWithDisplayLocation:loc];
                [allInstances addObject:instances pairedWithKey:key];
            }
            [instances addMessageID:messageID];
        }
    }];
    
    return [allInstances allObjects];
}

- (AATTDisplayLocationInstances *)displayLocationInstancesInChannelWithID:(NSString *)channelID displayLocation:(AATTDisplayLocation *)displayLocation {
    return [self displayLocationInstancesInChannelWithID:channelID displayLocation:displayLocation locationPrecision:AATTLocationPrecisionOneHundredMeters];
}

- (AATTDisplayLocationInstances *)displayLocationInstancesInChannelWithID:(NSString *)channelID displayLocation:(AATTDisplayLocation *)displayLocation locationPrecision:(AATTLocationPrecision)locationPrecision {
    static NSString *select = @"SELECT location_message_id FROM location_instances WHERE location_channel_id = ? AND location_name = ? AND location_latitude LIKE ? AND location_longitude LIKE ? ORDER BY location_date DESC";
    
    AATTDisplayLocationInstances *instances = [[AATTDisplayLocationInstances alloc] initWithDisplayLocation:displayLocation];
    NSUInteger precisionDigits = 3;
    if(locationPrecision == AATTLocationPrecisionOneThousandMeters) {
        precisionDigits = 2;
    } else if(locationPrecision == AATTLocationPrecisionTenThousandMeters) {
        precisionDigits = 1;
    }
    
    NSString *latArg = [NSString stringWithFormat:@"%@%%", [self roundedValueAsString:displayLocation.latitude decimalPlaces:precisionDigits]];
    NSString *longArg = [NSString stringWithFormat:@"%@%%", [self roundedValueAsString:displayLocation.longitude decimalPlaces:precisionDigits]];
    
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQuery:select, channelID, displayLocation.name, latArg, longArg];
        while([resultSet next]) {
            NSString *messageID = [resultSet stringForColumnIndex:0];
            [instances addMessageID:messageID];
        }
    }];
    
    return instances;
}

- (NSOrderedDictionary *)hashtagInstancesInChannelWithID:(NSString *)channelID {
    return [self hashtagInstancesInChannelWithID:channelID sinceDate:nil];
}

- (NSOrderedDictionary *)hashtagInstancesInChannelWithID:(NSString *)channelID sinceDate:(NSDate *)sinceDate {
    return [self hashtagInstancesInChannelWithID:channelID beforeDate:nil sinceDate:sinceDate];
}

- (NSOrderedDictionary *)hashtagInstancesInChannelWithID:(NSString *)channelID beforeDate:(NSDate *)beforeDate sinceDate:(NSDate *)sinceDate {
    NSMutableOrderedDictionary *allInstances = [[NSMutableOrderedDictionary alloc] init];
    
    static NSString *select = @"SELECT hashtag_name, hashtag_message_id FROM hashtag_instances";
    
    NSString *where = @" WHERE hashtag_channel_id = ?";
    NSMutableArray *args = [[NSMutableArray alloc] initWithCapacity:3];
    [args addObject:channelID];
    
    if(sinceDate) {
        where = [NSString stringWithFormat:@"%@ AND hashtag_date >= ?", where];
        [args addObject:[NSNumber numberWithDouble:[sinceDate timeIntervalSince1970]]];
    }
    if(beforeDate) {
        where = [NSString stringWithFormat:@"%@ AND hashtag_date < ?", where];
        [args addObject:[NSNumber numberWithDouble:[beforeDate timeIntervalSince1970]]];
    }
    
    where = [NSString stringWithFormat:@"%@ ORDER BY hashtag_date DESC", where];
    
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        NSString *fullSelect = [NSString stringWithFormat:@"%@%@", select, where];
        
        FMResultSet *resultSet = [db executeQuery:fullSelect withArgumentsInArray:args];
        while([resultSet next]) {
            NSString *hashtagName = [resultSet stringForColumnIndex:0];
            NSString *messageID = [resultSet stringForColumnIndex:1];
            
            AATTHashtagInstances *instances = [allInstances objectForKey:hashtagName];
            if(!instances) {
                instances = [[AATTHashtagInstances alloc] initWithName:hashtagName];
                [allInstances addObject:instances pairedWithKey:hashtagName];
            }
            [instances addMessageID:messageID];
        }
    }];
    
    return allInstances;
}

- (AATTHashtagInstances *)hashtagInstancesInChannelWithID:(NSString *)channelID hashtagName:(NSString *)hashtagName {
    AATTHashtagInstances *instances = [[AATTHashtagInstances alloc] initWithName:hashtagName];
    
    static NSString *select = @"SELECT hashtag_message_id FROM hashtag_instances WHERE hashtag_channel_id = ? AND hashtag_name = ?";
    
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQuery:select, channelID, hashtagName];
        while([resultSet next]) {
            [instances addMessageID:[resultSet stringForColumnIndex:0]];
        }
    }];
    return instances;
}

- (AATTGeolocation *)geolocationForLatitude:(double)latitude longitude:(double)longitude {
    __block AATTGeolocation *geolocation = nil;
    static NSString *select = @"SELECT geolocation_locality, geolocation_sublocality FROM geolocations WHERE geolocation_latitude = ? AND geolocation_longitude = ?";
    NSMutableArray *args = [[NSMutableArray alloc] initWithCapacity:2];
    [args addObject:[NSNumber numberWithDouble:[self roundValue:latitude decimalPlaces:3]]];
    [args addObject:[NSNumber numberWithDouble:[self roundValue:longitude decimalPlaces:3]]];
    
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQuery:select withArgumentsInArray:args];
        if([resultSet next]) {
            NSString *locality = [resultSet stringForColumnIndex:0];
            NSString *subLocality = [resultSet stringForColumnIndex:1];
            geolocation = [[AATTGeolocation alloc] initWithLocality:locality subLocality:subLocality latitude:latitude longitude:longitude];
            [resultSet close];
        }
    }];
    return geolocation;
}

#pragma mark - Private Stuff

- (NSString *)JSONStringWithMessage:(ANKMessage *)message {
    NSError *error;
    NSData *JSONData = [NSJSONSerialization dataWithJSONObject:message.JSONDictionary options:0 error:&error];
    if(!JSONData) {
        NSLog(@"Got an error: %@", error);
        return nil;
    } else {
        return [[NSString alloc] initWithData:JSONData encoding:NSUTF8StringEncoding];
    }
}

- (NSDictionary *)JSONDictionaryWithString:(NSString *)jsonString {
    NSError *error;
    NSData *JSONData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *JSONDictionary = [NSJSONSerialization JSONObjectWithData:JSONData options:0 error:&error];
    if(!JSONDictionary) {
        NSLog(@"Got an error: %@", error);
        return nil;
    }
    return JSONDictionary;
}

- (double)roundValue:(double)value decimalPlaces:(NSUInteger)decimalPlaces {
    return [[self roundedValueAsString:value decimalPlaces:decimalPlaces] doubleValue];
}

- (NSString *)roundedValueAsString:(double)value decimalPlaces:(NSUInteger)decimalPlaces {
    static NSNumberFormatter *formatter;
    if(!formatter) {
        formatter = [[NSNumberFormatter alloc] init];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        formatter.roundingMode = NSNumberFormatterRoundDown;
    }
    formatter.maximumFractionDigits = decimalPlaces;
    return [formatter stringFromNumber:[NSNumber numberWithDouble:value]];
}

@end
