//
//  AATTADNDatabase.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/30/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTActionMessageSpec.h"
#import "AATTADNDatabase.h"
#import "AATTDisplayLocation.h"
#import "AATTDisplayLocationInstances.h"
#import "AATTGeolocation.h"
#import "AATTHashtagInstances.h"
#import "AATTMessagePlus.h"
#import "AATTOrderedMessageBatch.h"
#import "AATTPendingFile.h"
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

static NSString *const kCreateMessagesTable = @"CREATE VIRTUAL TABLE IF NOT EXISTS messages USING fts3 (message_id TEXT PRIMARY KEY, message_channel_id TEXT NOT NULL, message_date INTEGER NOT NULL, message_json TEXT NOT NULL, message_text TEXT, message_unsent BOOLEAN, message_send_attempts INTEGER)";

static NSString *const kCreateDisplayLocationInstancesTable = @"CREATE TABLE IF NOT EXISTS location_instances (location_name TEXT NOT NULL, location_short_name TEXT, location_message_id TEXT NOT NULL, location_channel_id TEXT NOT NULL, location_latitude REAL NOT NULL, location_longitude REAL NOT NULL, location_factual_id TEXT, location_date INTEGER NOT NULL, PRIMARY KEY (location_name, location_message_id, location_latitude, location_longitude))";

static NSString *const kCreateHashtagInstancesTable = @"CREATE TABLE IF NOT EXISTS hashtag_instances (hashtag_name TEXT NOT NULL, hashtag_message_id TEXT NOT NULL, hashtag_channel_id TEXT NOT NULL, hashtag_date INTEGER NOT NULL, PRIMARY KEY (hashtag_name, hashtag_message_id))";

static NSString *const kCreateOEmbedInstancesTable = @"CREATE TABLE IF NOT EXISTS oembed_instances (oembed_type TEXT NOT NULL, oembed_message_id TEXT NOT NULL, oembed_channel_id TEXT NOT NULL, oembed_count INTEGER NOT NULL, oembed_date INTEGER NOT NULL, PRIMARY KEY(oembed_type, oembed_message_id))";

static NSString *const kCreateGeolocationsTable = @"CREATE TABLE IF NOT EXISTS geolocations (geolocation_locality TEXT NOT NULL, geolocation_sublocality TEXT, geolocation_latitude REAL NOT NULL, geolocation_longitude REAL NOT NULL, PRIMARY KEY (geolocation_latitude, geolocation_longitude))";

static NSString *const kCreatePendingMessageDeletionsTable = @"CREATE TABLE IF NOT EXISTS pending_message_deletions (pending_message_deletion_message_id TEXT PRIMARY KEY, pending_message_deletion_channel_id TEXT NOT NULL, pending_message_deletion_delete_associated_files BOOLEAN NOT NULL)";

static NSString *const kCreatePendingFilesTable = @"CREATE TABLE IF NOT EXISTS pending_files (pending_file_id TEXT PRIMARY KEY, pending_file_url TEXT NOT NULL, pending_file_type TEXT NOT NULL, pending_file_name TEXT NOT NULL, pending_file_mimetype TEXT NOT NULL, pending_file_kind TEXT, pending_file_public BOOLEAN, pending_file_send_attempts INTEGER)";

static NSString *const kCreatePendingOEmbedsTable = @"CREATE TABLE IF NOT EXISTS pending_oembeds (pending_oembed_pending_file_id TEXT NOT NULL, pending_oembed_message_id TEXT NOT NULL, pending_oembed_channel_id TEXT NOT NULL, PRIMARY KEY (pending_oembed_pending_file_id, pending_oembed_message_id, pending_oembed_channel_id))";

static NSString *const kCreateActionMessageSpecsTable = @"CREATE TABLE IF NOT EXISTS action_messages (action_message_id TEXT PRIMARY KEY, action_message_channel_id TEXT NOT NULL, action_message_target_message_id TEXT NOT NULL, action_message_target_channel_id TEXT NOT NULL)";

#pragma mark - Initializer

- (id)init {
    self = [super init];
    if(self) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSString *writableDBPath = [documentsDirectory stringByAppendingPathComponent:@"aattadndatabase.sqlite3"];
        
        self.databaseQueue = [FMDatabaseQueue databaseQueueWithPath:writableDBPath];
        [self.databaseQueue inDatabase:^(FMDatabase *db) {
            [db setLogsErrors:YES];
            
            [db executeUpdate:kCreateMessagesTable];
            [db executeUpdate:kCreateDisplayLocationInstancesTable];
            [db executeUpdate:kCreateHashtagInstancesTable];
            [db executeUpdate:kCreateOEmbedInstancesTable];
            [db executeUpdate:kCreateGeolocationsTable];
            [db executeUpdate:kCreatePendingMessageDeletionsTable];
            [db executeUpdate:kCreatePendingFilesTable];
            [db executeUpdate:kCreatePendingOEmbedsTable];
            [db executeUpdate:kCreateActionMessageSpecsTable];
        }];
    }
    return self;
}

#pragma mark - Insertion

- (void)insertOrReplaceMessage:(AATTMessagePlus *)messagePlus {
    static NSString *insertOrReplaceMessage = @"INSERT OR REPLACE INTO messages (message_id, message_channel_id, message_date, message_json, message_text, message_unsent, message_send_attempts) VALUES(?, ?, ?, ?, ?, ?, ?)";
    [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollBack) {
        ANKMessage *message = messagePlus.message;
        NSString *messageText = message.text;
        
        message.text = nil;
        
        NSString *jsonString = [self JSONStringWithMessage:message];
        NSNumber *unsent = [NSNumber numberWithBool:messagePlus.isUnsent];
        NSNumber *sendAttempts = [NSNumber numberWithInteger:messagePlus.sendAttemptsCount];
        
        if(![db executeUpdate:insertOrReplaceMessage, messagePlus.message.messageID, messagePlus.message.channelID, [NSNumber numberWithDouble:[messagePlus.displayDate timeIntervalSince1970]], jsonString, messageText, unsent, sendAttempts]) {
            *rollBack = YES;
        }
        
        if(messagePlus.pendingOEmbeds.count > 0) {
            for(NSString *pendingOEmbed in messagePlus.pendingOEmbeds) {
                [self insertOrReplacePendingOEmbedForPendingFileID:pendingOEmbed messageID:message.messageID channelID:message.channelID db:db];
            }
        }
        
        message.text = messageText;
    }];
}

- (void)insertOrReplacePendingOEmbedForPendingFileID:(NSString *)pendingFileID messageID:(NSString *)messageID channelID:(NSString *)channelID db:(FMDatabase *)db {
    static NSString *insert = @"INSERT OR REPLACE INTO pending_oembeds (pending_oembed_pending_file_id, pending_oembed_message_id, pending_oembed_channel_id) VALUES (?, ?, ?)";
    [db executeUpdate:insert, pendingFileID, messageID, channelID];
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
        static NSString *insertOrReplaceDisplayLocationInstance = @"INSERT OR REPLACE INTO location_instances (location_name, location_short_name, location_message_id, location_channel_id, location_latitude, location_longitude, location_factual_id, location_date) VALUES(?, ?, ?, ?, ?, ?, ?, ?)";
        [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollBack) {
            AATTDisplayLocation *l = messagePlus.displayLocation;
            NSString *name = l.name;
            NSString *shortName = l.shortName;
            NSString *messageID = messagePlus.message.messageID;
            NSString *channelID = messagePlus.message.channelID;
            NSNumber *latitude = [NSNumber numberWithDouble:l.latitude];
            NSNumber *longitude = [NSNumber numberWithDouble:l.longitude];
            NSString *factualID = l.factualID;
            NSNumber *date = [NSNumber numberWithDouble:[messagePlus.displayDate timeIntervalSince1970]];
            
            if(![db executeUpdate:insertOrReplaceDisplayLocationInstance, name, shortName, messageID, channelID, latitude, longitude, factualID, date]) {
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

- (void)insertOrReplaceActionMessageSpec:(AATTMessagePlus *)messagePlus targetMessageId:(NSString *)targetMessageId targetChannelId:(NSString *)targetChannelId {
    static NSString *insertOrReplaceActionMessageSpec = @"INSERT OR REPLACE INTO action_messages (action_message_id, action_message_channel_id, action_message_target_message_id, action_message_target_channel_id) VALUES (?, ?, ?, ?)";
    [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        ANKMessage *message = messagePlus.message;
        if(![db executeUpdate:insertOrReplaceActionMessageSpec, message.messageID, message.channelID, targetMessageId, targetChannelId]) {
            *rollback = YES;
            return;
        }
    }];
}

- (void)insertOrReplacePendingDeletionForMessagePlus:(AATTMessagePlus *)messagePlus deleteAssociatedFiles:(BOOL)deleteAssociatedFiles {
    static NSString *insertOrReplacePendingDeletion = @"INSERT OR REPLACE INTO pending_message_deletions (pending_message_deletion_message_id, pending_message_deletion_channel_id, pending_message_deletion_delete_associated_files) VALUES (?, ?, ?)";
    [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        ANKMessage *message = messagePlus.message;
        NSNumber *delete = [NSNumber numberWithBool:deleteAssociatedFiles];
        if(![db executeUpdate:insertOrReplacePendingDeletion, message.messageID, message.channelID, delete]) {
            *rollback = YES;
            return;
        }
    }];
}

- (void)insertOrReplacePendingFile:(AATTPendingFile *)pendingFile {
    static NSString *insert = @"INSERT OR REPLACE INTO pending_files (pending_file_id, pending_file_url, pending_file_type, pending_file_name, pending_file_mimetype, pending_file_kind, pending_file_public, pending_file_send_attempts) VALUES (?, ?, ?, ?, ?, ?, ?, ?)";
    [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        NSNumber *public = [NSNumber numberWithBool:pendingFile.isPublic];
        NSNumber *sendAttempts = [NSNumber numberWithInteger:pendingFile.sendAttemptsCount];
        if(![db executeUpdate:insert, pendingFile.ID, pendingFile.URL.description, pendingFile.type, pendingFile.name, pendingFile.mimeType, pendingFile.kind, public, sendAttempts]) {
            *rollback = YES;
            return;
        }
    }];
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
            NSString *messageJSONString = [resultSet stringForColumnIndex:3];
            NSString *messageText = [resultSet stringForColumnIndex:4];
            BOOL isUnsent = [resultSet boolForColumnIndex:5];
            NSInteger sendAttemptsCount = [resultSet intForColumnIndex:6];
            
            NSDictionary *messageJSON = [self JSONDictionaryWithString:messageJSONString];
            m = [[ANKMessage alloc] initWithJSONDictionary:messageJSON];
            m.text = messageText;

            AATTMessagePlus *messagePlus = [[AATTMessagePlus alloc] initWithMessage:m];
            messagePlus.isUnsent = isUnsent;
            messagePlus.sendAttemptsCount = sendAttemptsCount;
            messagePlus.displayDate = date;
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
    
    NSString *select = @"SELECT message_id, message_date, message_json, message_text, message_unsent, message_send_attempts FROM messages WHERE message_channel_id = ? AND message_id IN (";
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
            NSString *messageJSONString = [resultSet stringForColumnIndex:2];
            NSString *messageText = [resultSet stringForColumnIndex:3];
            BOOL isUnsent = [resultSet boolForColumnIndex:4];
            NSInteger sendAttemptsCount = [resultSet intForColumnIndex:5];
            
            NSDictionary *messageJSON = [self JSONDictionaryWithString:messageJSONString];
            m = [[ANKMessage alloc] initWithJSONDictionary:messageJSON];
            m.text = messageText;
            
            AATTMessagePlus *messagePlus = [[AATTMessagePlus alloc] initWithMessage:m];
            messagePlus.isUnsent = isUnsent;
            messagePlus.sendAttemptsCount = sendAttemptsCount;
            messagePlus.displayDate = date;
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

- (NSOrderedDictionary *)unsentMessagesInChannelWithID:(NSString *)channelID {
    NSMutableOrderedDictionary *messagePlusses = [[NSMutableOrderedDictionary alloc] init];
    
    static NSString *select = @"SELECT message_id, message_date, message_json, message_text, message_send_attempts FROM messages WHERE message_channel_id = ? AND message_unsent = ? ORDER BY message_date ASC";
    
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQuery:select, channelID, [NSNumber numberWithInt:1]];
        while([resultSet next]) {
            NSString *messageID = [resultSet objectForColumnIndex:0];
            NSDate *date = [NSDate dateWithTimeIntervalSince1970:[resultSet doubleForColumnIndex:1]];
            NSString *messageJSONString = [resultSet stringForColumnIndex:2];
            NSString *messageText = [resultSet stringForColumnIndex:3];
            NSInteger sendAttemptsCount = [resultSet intForColumnIndex:4];
            
            NSDictionary *messageJSON = [self JSONDictionaryWithString:messageJSONString];
            ANKMessage *message = [[ANKMessage alloc] initWithJSONDictionary:messageJSON];
            message.text = messageText;
            
            AATTMessagePlus *messagePlus = [[AATTMessagePlus alloc] initWithMessage:message];
            messagePlus.displayDate = date;
            messagePlus.isUnsent = YES;
            messagePlus.sendAttemptsCount = sendAttemptsCount;
            [messagePlusses setObject:messagePlus forKey:messageID];
        }
    }];
    
    return messagePlusses;
}

- (NSArray *)displayLocationInstancesInChannelWithID:(NSString *)channelID {
    static NSString *select = @"SELECT location_name, location_short_name, location_message_id, location_latitude, location_longitude FROM location_instances WHERE location_channel_id = ? ORDER BY location_date DESC";
    
    NSMutableOrderedDictionary *allInstances = [[NSMutableOrderedDictionary alloc] init];
    
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQuery:select, channelID];
        while([resultSet next]) {
            NSString *name = [resultSet stringForColumnIndex:0];
            NSString *shortName = [resultSet stringForColumnIndex:1];
            NSString *messageID = [resultSet stringForColumnIndex:2];
            double latitude = [resultSet doubleForColumnIndex:3];
            double longitude = [resultSet doubleForColumnIndex:4];
            
            NSString *roundedLatitude = [self roundedValueAsString:latitude decimalPlaces:1];
            NSString *roundedLongitude = [self roundedValueAsString:longitude decimalPlaces:1];
            NSString *key = [NSString stringWithFormat:@"%@ %@ %@", name, roundedLatitude, roundedLongitude];
            AATTDisplayLocationInstances *instances = [allInstances objectForKey:key];
            if(!instances) {
                AATTDisplayLocation *loc = [[AATTDisplayLocation alloc] initWithName:name latitude:latitude longitude:longitude];
                instances = [[AATTDisplayLocationInstances alloc] initWithDisplayLocation:loc];
                loc.shortName = shortName;
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

- (NSArray *)hashtagInstancesInChannelWithID:(NSString *)channelID {
    return [self hashtagInstancesInChannelWithID:channelID sinceDate:nil];
}

- (NSArray *)hashtagInstancesInChannelWithID:(NSString *)channelID sinceDate:(NSDate *)sinceDate {
    return [self hashtagInstancesInChannelWithID:channelID beforeDate:nil sinceDate:sinceDate];
}

- (NSArray *)hashtagInstancesInChannelWithID:(NSString *)channelID beforeDate:(NSDate *)beforeDate sinceDate:(NSDate *)sinceDate {
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
    
    return [allInstances allObjects];
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
    static NSString *select = @"SELECT geolocation_locality, geolocation_sublocality FROM geolocations WHERE geolocation_latitude = ? AND geolocation_longitude = ? LIMIT 1";
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

- (NSArray *)actionMessageSpecsForTargetMessagesWithIDs:(NSArray *)targetMessageIDs {
    return [self actionMessageSpecsForTargetMessagesWithIDs:targetMessageIDs inActionChannelWithID:nil];
}

- (NSArray *)actionMessageSpecsForTargetMessagesWithIDs:(NSArray *)targetMessageIDs inActionChannelWithID:(NSString *)actionChannelID {
    NSMutableArray *actionMessageSpecs = [[NSMutableArray alloc] initWithCapacity:targetMessageIDs.count];
    NSString *select = @"SELECT * FROM action_messages WHERE";
    
    NSInteger startIndex = 0;
    NSMutableArray *args = nil;
    if(actionChannelID) {
        args = [NSMutableArray arrayWithCapacity:targetMessageIDs.count + 1];
        [args setObject:actionChannelID atIndexedSubscript:0];
        select = [NSString stringWithFormat:@"%@ action_message_channel_id = ? AND", select];
        startIndex = 1;
    } else {
        args = [NSMutableArray arrayWithCapacity:targetMessageIDs.count];
    }
    
    select = [NSString stringWithFormat:@"%@ action_message_target_message_id IN (", select];
    
    NSUInteger index = startIndex;
    for(NSString *messageID in targetMessageIDs) {
        [args setObject:messageID atIndexedSubscript:index];
        
        NSString *append;
        if(index > startIndex) {
            append = @", ?";
        } else {
            append = @" ?";
        }
        index++;
        select = [NSString stringWithFormat:@"%@%@", select, append];
    }
    select = [NSString stringWithFormat:@"%@)", select];

    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQuery:select withArgumentsInArray:args];
        while([resultSet next]) {
            NSString *aMessageID = [resultSet stringForColumnIndex:0];
            NSString *aChannelID = [resultSet stringForColumnIndex:1];
            NSString *tMessageID = [resultSet stringForColumnIndex:2];
            NSString *tChannelID = [resultSet stringForColumnIndex:3];
            
            AATTActionMessageSpec *spec = [[AATTActionMessageSpec alloc] init];
            spec.actionMessageID = aMessageID;
            spec.actionChannelID = aChannelID;
            spec.targetMessageID = tMessageID;
            spec.targetChannelID = tChannelID;
            [actionMessageSpecs addObject:spec];
        }
    }];
    
    return actionMessageSpecs;
}

- (AATTPendingFile *)pendingFileWithID:(NSString *)pendingFileID {
    static NSString *select = @"SELECT * FROM pending_files WHERE pending_file_id = ?";
    __block AATTPendingFile *pendingFile = nil;
    
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQuery:select, pendingFileID];
        if([resultSet next]) {
            pendingFile = [[AATTPendingFile alloc] init];
            pendingFile.ID = pendingFileID;
            pendingFile.URL = [NSURL URLWithString:[resultSet stringForColumnIndex:1]];
            pendingFile.type = [resultSet stringForColumnIndex:2];
            pendingFile.name = [resultSet stringForColumnIndex:3];
            pendingFile.mimeType = [resultSet stringForColumnIndex:4];
            pendingFile.kind = [resultSet stringForColumnIndex:5];
            pendingFile.isPublic = [resultSet boolForColumnIndex:6];
            pendingFile.sendAttemptsCount = [resultSet intForColumnIndex:7];
            
            [resultSet close];
        }
    }];
    return pendingFile;
}

#pragma mark - Deletion

- (void)deleteMessagePlus:(AATTMessagePlus *)messagePlus {
    static NSString *deleteMessage = @"DELETE FROM messages WHERE message_id = ?";
    static NSString *deleteHashtags = @"DELETE FROM hashtag_instances WHERE hashtag_name = ? AND hashtag_message_id = ?";
    static NSString *deleteLocations = @"DELETE FROM location_instances WHERE location_name = ? AND location_message_id = ? AND location_latitude = ? AND location_longitude = ?";
    static NSString *deleteOEmbeds = @"DELETE FROM oembed_instances WHERE oembed_type = ? AND oembed_message_id = ?";
    
    ANKMessage *message = messagePlus.message;

    [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        if(![db executeUpdate:deleteMessage, message.messageID]) {
            *rollback = YES;
            return;
        }
        
        NSArray *hashtags = message.entities.hashtags;
        for(ANKHashtagEntity *hashtag in hashtags) {
            if(![db executeUpdate:deleteHashtags, hashtag.hashtag, message.messageID]) {
                *rollback = YES;
                return;
            }
        }
        
        AATTDisplayLocation *displayLocation = messagePlus.displayLocation;
        if(displayLocation) {
            NSNumber *latitude = [NSNumber numberWithDouble:displayLocation.latitude];
            NSNumber *longitude = [NSNumber numberWithDouble:displayLocation.longitude];
            if(![db executeUpdate:deleteLocations, displayLocation.name, message.messageID, latitude, longitude]) {
                *rollback = YES;
                return;
            }
        }
        
        if(messagePlus.photoOEmbeds.count > 0) {
            if(![db executeUpdate:deleteOEmbeds, @"photo", message.messageID]) {
                *rollback = YES;
                return;
            }
        }
        
        if(messagePlus.html5VideoOEmbeds.count > 0) {
            if(![db executeUpdate:deleteOEmbeds, @"html5video", message.messageID]) {
                *rollback = YES;
                return;
            }
        }
    }];
}

- (void)deletePendingMessageDeletionForMessagePlus:(AATTMessagePlus *)messagePlus {
    static NSString *delete = @"DELETE FROM pending_message_deletions WHERE pending_message_deletion_message_id = ?";
    [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        if(![db executeUpdate:delete, messagePlus.message.messageID]) {
            *rollback = YES;
        }
    }];
}

- (void)deletePendingFile:(AATTPendingFile *)pendingFile {
    static NSString *delete = @"DELETE FROM pending_files WHERE pending_file_id = ?";
    [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        if(![db executeUpdate:delete, pendingFile.ID]) {
            *rollback = YES;
        }
    }];
}

- (void)deletePendingOEmbedForPendingFileWithID:(NSString *)pendingFileID messageID:(NSString *)messageID channelID:(NSString *)channelID {
    static NSString *delete = @"DELETE FROM pending_oembeds WHERE pending_oembed_pending_file_id = ? AND pending_oembed_message_id = ? AND pending_oembed_channel_id = ?";
    [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        if(![db executeUpdate:delete, pendingFileID, messageID, channelID]) {
            *rollback = YES;
        }
    }];
}

#pragma mark - Other

- (BOOL)hasActionMessageSpecForActionChannelWithID:(NSString *)actionChannelID targetMessageID:(NSString *)targetMessageID {
    static NSString *select = @"SELECT action_message_id FROM action_messages WHERE action_message_channel_id = ? AND action_message_target_message_id = ?";
    
    NSArray *args = @[actionChannelID, targetMessageID];
    
    __block BOOL has = NO;
    
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQuery:select withArgumentsInArray:args];
        if([resultSet next]) {
            [resultSet close];
            has = YES;
        }
    }];
     
    return has;
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
