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

static NSString *const kCreateMessagesTable = @"CREATE TABLE IF NOT EXISTS messages (message_id TEXT PRIMARY KEY, message_channel_id TEXT NOT NULL, message_date INTEGER NOT NULL, message_json TEXT NOT NULL)";

static NSString *const kCreateDisplayLocationInstancesTable = @"CREATE TABLE IF NOT EXISTS location_instances (location_name TEXT NOT NULL, location_message_id TEXT NOT NULL, location_channel_id TEXT NOT NULL, location_latitude REAL NOT NULL, location_longitude REAL NOT NULL, location_factual_id TEXT, location_date INTEGER NOT NULL, PRIMARY KEY (location_name, location_message_id, location_latitude, location_longitude))";

static NSString *const kCreateGeolocationsTable = @"CREATE TABLE IF NOT EXISTS geolocations (geolocation_name TEXT NOT NULL, geolocation_latitude REAL NOT NULL, geolocation_longitude REAL NOT NULL)";

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
            [db executeUpdate:kCreateGeolocationsTable];
        }];
    }
    return self;
}

- (void)insertOrReplaceMessage:(AATTMessagePlus *)messagePlus {
    static NSString *insertOrReplaceMessage = @"INSERT OR REPLACE INTO messages (message_id, message_channel_id, message_date, message_json) VALUES(?, ?, ?, ?)";
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        NSString *jsonString = [self JSONStringWithMessage:messagePlus.message];
        [db executeUpdate:insertOrReplaceMessage, messagePlus.message.messageID, messagePlus.message.channelID, [NSNumber numberWithDouble:[messagePlus.displayDate timeIntervalSince1970]], jsonString];
    }];
}

- (void)insertOrReplaceGeolocation:(AATTGeolocation *)geolocation {
    static NSString *insertOrReplaceGeolocation = @"INSERT OR REPLACE INTO geolocations (geolocation_name, geolocation_latitude, geolocation_longitude) VALUES(?, ?, ?)";
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        double latitude = [self roundValue:geolocation.latitude decimalPlaces:3];
        double longitude = [self roundValue:geolocation.longitude decimalPlaces:3];
        [db executeUpdate:insertOrReplaceGeolocation, geolocation.name, [NSNumber numberWithDouble:latitude], [NSNumber numberWithDouble:longitude]];
    }];
}

- (void)insertOrReplaceDisplayLocationInstance:(AATTMessagePlus *)messagePlus {
    if(messagePlus.displayLocation) {
        static NSString *insertOrReplaceDisplayLocationInstance = @"INSERT OR REPLACE INTO location_instances (location_name, location_message_id, location_channel_id, location_latitude, location_longitude, location_factual_id, location_date) VALUES(?, ?, ?, ?, ?, ?, ?)";
        [self.databaseQueue inDatabase:^(FMDatabase *db) {
            AATTDisplayLocation *l = messagePlus.displayLocation;
            NSString *name = l.name;
            NSString *messageID = messagePlus.message.messageID;
            NSString *channelID = messagePlus.message.channelID;
            NSNumber *latitude = [NSNumber numberWithDouble:l.latitude];
            NSNumber *longitude = [NSNumber numberWithDouble:l.longitude];
            NSString *factualID = l.factualID;
            NSNumber *date = [NSNumber numberWithDouble:[messagePlus.displayDate timeIntervalSince1970]];
            
            [db executeUpdate:insertOrReplaceDisplayLocationInstance, name, messageID, channelID, latitude, longitude, factualID, date];
        }];
    }
}

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

- (AATTGeolocation *)geolocationForLatitude:(double)latitude longitude:(double)longitude {
    __block AATTGeolocation *geolocation = nil;
    static NSString *select = @"SELECT * FROM geolocations WHERE geolocation_latitude = ? AND geolocation_longitude = ?";
    NSMutableArray *args = [[NSMutableArray alloc] initWithCapacity:2];
    [args addObject:[NSNumber numberWithDouble:[self roundValue:latitude decimalPlaces:3]]];
    [args addObject:[NSNumber numberWithDouble:[self roundValue:longitude decimalPlaces:3]]];
    
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQuery:select withArgumentsInArray:args];
        if([resultSet next]) {
            geolocation = [[AATTGeolocation alloc] initWithName:[resultSet stringForColumnIndex:0] latitude:latitude longitude:longitude];
            [resultSet close];
        }
    }];
    return geolocation;
}

#pragma mark - Private stuff.

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
