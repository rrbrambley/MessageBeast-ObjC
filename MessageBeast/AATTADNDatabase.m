//
//  AATTADNDatabase.m
//  MessageBeast
//
//  Created by Rob Brambley on 10/30/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTActionMessageSpec.h"
#import "AATTADNDatabase.h"
#import "AATTAnnotationInstances.h"
#import "AATTCustomPlace.h"
#import "AATTDisplayLocation.h"
#import "AATTDisplayLocationInstances.h"
#import "AATTGeolocation.h"
#import "AATTHashtagInstances.h"
#import "AATTMessagePlus.h"
#import "AATTOrderedMessageBatch.h"
#import "AATTPendingFile.h"
#import "AATTPendingFileAttachment.h"
#import "AATTPendingMessageDeletion.h"
#import "AATTSharedDateFormatter.h"
#import "ANKMessage+AATTAnnotationHelper.h"
#import "FMDatabase.h"
#import "FMDatabaseQueue.h"
#import "M13OrderedDictionary.h"

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

static NSString *const kCreateMessagesTable = @"CREATE TABLE IF NOT EXISTS messages (message_id INTEGER PRIMARY KEY, message_message_id TEXT UNIQUE, message_channel_id TEXT NOT NULL, message_date INTEGER NOT NULL, message_json TEXT NOT NULL, message_text TEXT, message_unsent BOOLEAN, message_send_attempts INTEGER)";

static NSString *const kCreateMessagesSearchTable = @"CREATE VIRTUAL TABLE messages_search USING fts4(content=\"messages\", message_message_id TEXT, message_channel_id TEXT, message_text TEXT)";

static NSString *const kCreateDisplayLocationInstancesTable = @"CREATE TABLE IF NOT EXISTS location_instances (location_id INTEGER PRIMARY KEY, location_message_id TEXT UNIQUE, location_name TEXT NOT NULL, location_short_name TEXT, location_channel_id TEXT NOT NULL, location_latitude REAL NOT NULL, location_longitude REAL NOT NULL, location_factual_id TEXT, location_date INTEGER NOT NULL)";

static NSString *const kCreateDisplayLocationInstancesSearchTable = @"CREATE VIRTUAL TABLE location_instances_search USING fts4(content=\"location_instances\", location_message_id TEXT, location_channel_id TEXT, location_name TEXT)";

static NSString *const kCreateHashtagInstancesTable = @"CREATE TABLE IF NOT EXISTS hashtag_instances (hashtag_name TEXT NOT NULL, hashtag_message_id TEXT NOT NULL, hashtag_channel_id TEXT NOT NULL, hashtag_date INTEGER NOT NULL, PRIMARY KEY (hashtag_name, hashtag_message_id))";

static NSString *const kCreateAnnotationInstancesTable = @"CREATE TABLE IF NOT EXISTS annotation_instances (annotation_type TEXT NOT NULL, annotation_message_id TEXT NOT NULL, annotation_channel_id TEXT NOT NULL, annotation_count INTEGER NOT NULL, annotation_date INTEGER NOT NULL, PRIMARY KEY(annotation_type, annotation_message_id))";

static NSString *const kCreateGeolocationsTable = @"CREATE TABLE IF NOT EXISTS geolocations (geolocation_locality TEXT NOT NULL, geolocation_sublocality TEXT, geolocation_latitude REAL NOT NULL, geolocation_longitude REAL NOT NULL, PRIMARY KEY (geolocation_latitude, geolocation_longitude))";

static NSString *const kCreatePendingMessageDeletionsTable = @"CREATE TABLE IF NOT EXISTS pending_message_deletions (pending_message_deletion_message_id TEXT PRIMARY KEY, pending_message_deletion_channel_id TEXT NOT NULL)";

static NSString *const kCreatePendingFilesTable = @"CREATE TABLE IF NOT EXISTS pending_files (pending_file_id TEXT PRIMARY KEY, pending_file_url TEXT NOT NULL, pending_file_type TEXT NOT NULL, pending_file_name TEXT NOT NULL, pending_file_mimetype TEXT NOT NULL, pending_file_kind TEXT, pending_file_public BOOLEAN, pending_file_send_attempts INTEGER)";

static NSString *const kCreatePendingFileAttachmentsTable = @"CREATE TABLE IF NOT EXISTS pending_file_attachments (pending_file_attachment_file_id TEXT NOT NULL, pending_file_attachment_message_id TEXT NOT NULL, pending_file_attachment_channel_id TEXT NOT NULL, pending_file_attachment_is_oembed INTEGER NOT NULL, PRIMARY KEY (pending_file_attachment_file_id, pending_file_attachment_message_id))";

static NSString *const kCreateActionMessageSpecsTable = @"CREATE TABLE IF NOT EXISTS action_messages (action_message_id TEXT PRIMARY KEY, action_message_channel_id TEXT NOT NULL, action_message_target_message_id TEXT NOT NULL, action_message_target_channel_id TEXT NOT NULL, action_message_target_message_display_date INTEGER NOT NULL)";

static NSString *const kCreatePendingFileDeletionsTable = @"CREATE TABLE IF NOT EXISTS pending_file_deletions (pending_file_deletion_file_id TEXT PRIMARY KEY)";

static NSString *const kCreatePlacesTable = @"CREATE TABLE IF NOT EXISTS places (place_id TEXT PRIMARY KEY, place_name TEXT NOT NULL, place_rounded_latitude REAL NOT NULL, place_rounded_longitude REAL NOT NULL, place_is_custom INTEGER NOT NULL, place_json TEXT NOT NULL)";

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
            [db setDateFormat:[AATTSharedDateFormatter dateFormatter]];
            
            [db executeUpdate:kCreateMessagesTable];
            [db executeUpdate:kCreateDisplayLocationInstancesTable];
            [db executeUpdate:kCreateHashtagInstancesTable];
            [db executeUpdate:kCreateAnnotationInstancesTable];
            [db executeUpdate:kCreateGeolocationsTable];
            [db executeUpdate:kCreatePendingMessageDeletionsTable];
            [db executeUpdate:kCreatePendingFilesTable];
            [db executeUpdate:kCreatePendingFileAttachmentsTable];
            [db executeUpdate:kCreateActionMessageSpecsTable];
            [db executeUpdate:kCreatePendingFileDeletionsTable];
            [db executeUpdate:kCreatePlacesTable];
            
            //
            //"IF NOT EXISTS" not available for VIRTUAL / FTS tables.
            //
            
            static NSString *checkSearchExists = @"SELECT name FROM sqlite_master WHERE type='table' AND name='messages_search'";
            FMResultSet *resultSet = [db executeQuery:checkSearchExists];
            if(![resultSet next]) {
                [db executeUpdate:kCreateMessagesSearchTable];
            }
            [resultSet close];
            
            static NSString *checkLocationSearchExists = @"SELECT name FROM sqlite_master WHERE type='table' AND name='location_instances_search'";
            resultSet = [db executeQuery:checkLocationSearchExists];
            if(![resultSet next]) {
                [db executeUpdate:kCreateDisplayLocationInstancesSearchTable];
            }
            [resultSet close];
        }];
    }
    return self;
}

#pragma mark - Insertion

- (void)insertOrReplaceMessage:(AATTMessagePlus *)messagePlus {
    static NSString *insertOrReplaceMessage = @"INSERT OR REPLACE INTO messages (message_id, message_message_id, message_channel_id, message_date, message_json, message_text, message_unsent, message_send_attempts) VALUES(?, ?, ?, ?, ?, ?, ?, ?)";

    ANKMessage *message = messagePlus.message;
    NSString *messageID = message.messageID;
    NSString *messageText = message.text;
    
    [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollBack) {
        message.text = nil;
        
        NSString *jsonString = [self JSONStringWithANKResource:message];
        NSNumber *unsent = [NSNumber numberWithBool:messagePlus.isUnsent];
        NSNumber *sendAttempts = [NSNumber numberWithInteger:messagePlus.sendAttemptsCount];
        
        if(![db executeUpdate:insertOrReplaceMessage, nil, messageID, messagePlus.message.channelID, [NSNumber numberWithDouble:[messagePlus.displayDate timeIntervalSince1970]], jsonString, messageText, unsent, sendAttempts]) {
            *rollBack = YES;
        }
        
        if(messagePlus.pendingFileAttachments.count > 0) {
            for(NSString *pendingFileID in [messagePlus.pendingFileAttachments allKeys]) {
                AATTPendingFileAttachment *attachment = [messagePlus.pendingFileAttachments objectForKey:pendingFileID];
                [self insertOrReplacePendingFileAttachmentWithPendingFileID:pendingFileID messageID:message.messageID channelID:message.channelID isOEmbed:attachment.isOEmbed db:db];
            }
        }
        message.text = messageText;
    }];
    
    NSUInteger maxID = [self maxMessageID];
    [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollBack) {
        [self insertSearchableMessageTextForMessageWithRowID:maxID messageID:messageID channelID:message.channelID text:messageText withDB:db];
    }];

}

- (void)insertOrReplacePendingFileAttachmentWithPendingFileID:(NSString *)pendingFileID messageID:(NSString *)messageID channelID:(NSString *)channelID isOEmbed:(BOOL)isOEmbed db:(FMDatabase *)db {
    static NSString *insert = @"INSERT OR REPLACE INTO pending_file_attachments (pending_file_attachment_file_id, pending_file_attachment_message_id, pending_file_attachment_channel_id, pending_file_attachment_is_oembed) VALUES (?, ?, ?, ?)";
    [db executeUpdate:insert, pendingFileID, messageID, channelID, [NSNumber numberWithBool:isOEmbed]];
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

- (void)insertOrReplacePlace:(ANKPlace *)place {
    static NSString *insert = @"INSERT OR REPLACE INTO places (place_id, place_name, place_rounded_latitude, place_rounded_longitude, place_is_custom, place_json) VALUES(?, ?, ?, ?, ?, ?)";
    [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        BOOL isCustom = [place isKindOfClass:[AATTCustomPlace class]];
        NSString *ID = isCustom ? [(AATTCustomPlace *)place ID] : place.factualID;
        NSNumber *latitude = [NSNumber numberWithDouble:[self roundValue:place.latitude decimalPlaces:3]];
        NSNumber *longitude = [NSNumber numberWithDouble:[self roundValue:place.longitude decimalPlaces:3]];
        NSNumber *placeIsCustom = [NSNumber numberWithBool:isCustom];
        NSString *placeJSONString = [self JSONStringWithANKResource:place];
        if(![db executeUpdate:insert, ID, place.name, latitude, longitude, placeIsCustom, placeJSONString]) {
            *rollback = YES;
        }
    }];
}

- (void)insertOrReplaceDisplayLocationInstance:(AATTMessagePlus *)messagePlus {
    if(messagePlus.displayLocation) {
        static NSString *insertOrReplaceDisplayLocationInstance = @"INSERT OR REPLACE INTO location_instances (location_id, location_message_id, location_name, location_short_name, location_channel_id, location_latitude, location_longitude, location_factual_id, location_date) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)";
        
        AATTDisplayLocation *l = messagePlus.displayLocation;
        NSString *messageID = messagePlus.message.messageID;
        NSString *name = l.name;
        NSString *shortName = l.shortName;
        NSString *channelID = messagePlus.message.channelID;
        NSNumber *latitude = [NSNumber numberWithDouble:l.latitude];
        NSNumber *longitude = [NSNumber numberWithDouble:l.longitude];
        NSString *factualID = l.factualID;
        NSNumber *date = [NSNumber numberWithDouble:[messagePlus.displayDate timeIntervalSince1970]];
        
        [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollBack) {
            if(![db executeUpdate:insertOrReplaceDisplayLocationInstance, nil, messageID, name, shortName, channelID, latitude, longitude, factualID, date]) {
                *rollBack = YES;
            }
        }];
        
        NSUInteger maxID = [self maxDisplayLocationInstanceID];
        [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollBack) {
            [self insertSearchableDisplayLocationInstanceWithRowID:maxID messageID:messageID channelID:channelID name:name withDB:db];
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

- (void)insertOrReplaceAnnotationInstancesOfType:(NSString *)annotationType forTargetMessagePlus:(AATTMessagePlus *)messagePlus {
    NSArray *annotations = [messagePlus.message annotationsWithType:annotationType];
    if(annotations.count > 0) {
        static NSString *insertOrReplaceAnnotationInstance = @"INSERT OR REPLACE INTO annotation_instances (annotation_type, annotation_message_id, annotation_channel_id, annotation_count, annotation_date) VALUES (?, ?, ?, ?, ?)";
        [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollBack) {
            NSString *messageID = messagePlus.message.messageID;
            NSString *channelID = messagePlus.message.channelID;
            NSNumber *count = [NSNumber numberWithUnsignedInteger:annotations.count];
            NSNumber *date = [NSNumber numberWithDouble:[messagePlus.displayDate timeIntervalSince1970]];
            
            if(![db executeUpdate:insertOrReplaceAnnotationInstance, annotationType, messageID, channelID, count, date]) {
                *rollBack = YES;
                return;
            }
        }];
    }
}

- (void)insertOrReplaceActionMessageSpec:(AATTMessagePlus *)messagePlus targetMessageID:(NSString *)targetMessageID targetChannelID:(NSString *)targetChannelID targetMessageDisplayDate:(NSDate *)targetMessageDisplayDate {
    [self insertOrReplaceActionMessageSpecForActionMessageWithID:messagePlus.message.messageID actionChannelID:messagePlus.message.channelID targetMessageID:targetMessageID targetChannelID:targetChannelID targetMessageDisplayDate:targetMessageDisplayDate];
}

- (void)insertOrReplaceActionMessageSpecForActionMessageWithID:(NSString *)actionMessageID actionChannelID:(NSString *)actionChannelID targetMessageID:(NSString *)targetMessageID targetChannelID:(NSString *)targetChannelID targetMessageDisplayDate:(NSDate *)targetMessageDisplayDate {
    static NSString *insertOrReplaceActionMessageSpec = @"INSERT OR REPLACE INTO action_messages (action_message_id, action_message_channel_id, action_message_target_message_id, action_message_target_channel_id, action_message_target_message_display_date) VALUES (?, ?, ?, ?, ?)";
    [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        NSNumber *targetMessageDisplayDateNumber = [NSNumber numberWithDouble:[targetMessageDisplayDate timeIntervalSince1970]];
        if(![db executeUpdate:insertOrReplaceActionMessageSpec, actionMessageID, actionChannelID, targetMessageID, targetChannelID, targetMessageDisplayDateNumber]) {
            *rollback = YES;
            return;
        }
    }];
}

- (void)insertOrReplacePendingDeletionForMessagePlus:(AATTMessagePlus *)messagePlus {
    static NSString *insertOrReplacePendingDeletion = @"INSERT OR REPLACE INTO pending_message_deletions (pending_message_deletion_message_id, pending_message_deletion_channel_id) VALUES (?, ?)";
    [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        ANKMessage *message = messagePlus.message;
        if(![db executeUpdate:insertOrReplacePendingDeletion, message.messageID, message.channelID]) {
            *rollback = YES;
            return;
        }
    }];
}

- (void)insertOrReplacePendingFile:(AATTPendingFile *)pendingFile {
    static NSString *insert = @"INSERT OR REPLACE INTO pending_files (pending_file_id, pending_file_url, pending_file_type, pending_file_name, pending_file_mimetype, pending_file_kind, pending_file_public, pending_file_send_attempts) VALUES (?, ?, ?, ?, ?, ?, ?, ?)";
    NSParameterAssert(pendingFile.URL);
    [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        NSNumber *public = [NSNumber numberWithBool:pendingFile.isPublic];
        NSNumber *sendAttempts = [NSNumber numberWithInteger:pendingFile.sendAttemptsCount];
        if(![db executeUpdate:insert, pendingFile.ID, pendingFile.URL.description, pendingFile.type, pendingFile.name, pendingFile.mimeType, pendingFile.kind, public, sendAttempts]) {
            *rollback = YES;
            return;
        }
    }];
}

- (void)insertOrReplacePendingFileDeletion:(NSString *)fileID {
    static NSString *insert = @"INSERT OR REPLACE INTO pending_file_deletions (pending_file_deletion_file_id) VALUES (?)";
    [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        if(![db executeUpdate:insert, fileID]) {
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
        select = [NSString stringWithFormat:@"%@ %@", select, @" AND CAST(message_date AS INTEGER) < ?"];
        [args addObject:[NSNumber numberWithDouble:[beforeDate timeIntervalSince1970]]];
    }
    
    select = [NSString stringWithFormat:@"%@ ORDER BY message_date DESC LIMIT %lu", select, (unsigned long)limit];
    return [self messagesWithSelectStatement:select arguments:args];
}

- (AATTOrderedMessageBatch *)messagesInChannelWithID:(NSString *)channelID searchQuery:(NSString *)query {
    NSString *select = @"SELECT message_message_id FROM messages_search WHERE message_channel_id = ? AND message_text MATCH ?";
    NSMutableSet *messageIDs = [NSMutableSet set];
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQuery:select, channelID, query];
        while([resultSet next]) {
            NSString *messageID = [resultSet stringForColumnIndex:0];
            [messageIDs addObject:messageID];
        }
    }];
    
    return [self messagesWithIDs:messageIDs];
}

- (AATTOrderedMessageBatch *)messagesInChannelWithID:(NSString *)channelID displayLocationSearchQuery:(NSString *)displayLocationSearchQuery {
    NSString *select = @"SELECT location_message_id FROM location_instances_search WHERE location_channel_id = ? AND location_name MATCH ?";
    NSMutableSet *messageIDs = [NSMutableSet set];
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQuery:select, channelID, displayLocationSearchQuery];
        while([resultSet next]) {
            NSString *messageID = [resultSet stringForColumnIndex:0];
            [messageIDs addObject:messageID];
        }
    }];
    
    return [self messagesWithIDs:messageIDs];
}

- (AATTOrderedMessageBatch *)messagesWithIDs:(NSSet *)messageIDs {
    NSString *select = @"SELECT * FROM messages WHERE message_message_id IN (";
    NSMutableArray *args = [NSMutableArray arrayWithCapacity:messageIDs.count];
    
    NSUInteger index = 0;
    for(NSString *messageID in messageIDs) {
        [args addObject:messageID];
        
        NSString *append;
        if(index > 0) {
            append = @", ?";
        } else {
            append = @" ?";
        }
        select = [NSString stringWithFormat:@"%@%@", select, append];
        index++;
    }
    select = [NSString stringWithFormat:@"%@ ) ORDER BY message_date DESC", select];

    return [self messagesWithSelectStatement:select arguments:args];
}

- (AATTMessagePlus *)messagePlusForMessageID:(NSString *)messageID {
    NSMutableSet *messageIDs = [NSMutableSet setWithCapacity:1];
    [messageIDs addObject:messageID];
    AATTOrderedMessageBatch *messageBatch = [self messagesWithIDs:messageIDs];
    M13OrderedDictionary *orderedMessages = messageBatch.messagePlusses;
    if(orderedMessages.count == 1) {
        return [orderedMessages lastObject];
    }
    return nil;
}

- (NSSet *)messageIDsDependentOnPendingFileWithID:(NSString *)pendingFileID {
    static NSString *select = @"SELECT pending_file_attachment_message_id FROM pending_file_attachments WHERE pending_file_attachment_file_id = ?";
    NSMutableSet *messageIDs = [NSMutableSet set];
    
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQuery:select, pendingFileID];
        while([resultSet next]) {
            [messageIDs addObject:[resultSet stringForColumnIndex:0]];
        }
    }];
    return messageIDs;
}

- (M13OrderedDictionary *)unsentMessagesInChannelWithID:(NSString *)channelID {
    NSMutableOrderedDictionary *messagePlusses = [[NSMutableOrderedDictionary alloc] init];
    
    static NSString *select = @"SELECT message_date, message_json, message_text, message_send_attempts FROM messages WHERE message_channel_id = ? AND message_unsent = ? ORDER BY message_date ASC";
    
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQuery:select, channelID, [NSNumber numberWithInt:1]];
        while([resultSet next]) {
            NSDate *date = [NSDate dateWithTimeIntervalSince1970:[resultSet doubleForColumnIndex:0]];
            NSString *messageJSONString = [resultSet stringForColumnIndex:1];
            NSString *messageText = [resultSet stringForColumnIndex:2];
            NSInteger sendAttemptsCount = [resultSet intForColumnIndex:3];
            
            NSDictionary *messageJSON = [self JSONDictionaryWithString:messageJSONString];
            ANKMessage *message = [[ANKMessage alloc] initWithJSONDictionary:messageJSON];
            message.text = messageText;
            
            AATTMessagePlus *messagePlus = [[AATTMessagePlus alloc] initWithMessage:message];
            messagePlus.displayDate = date;
            messagePlus.isUnsent = YES;
            messagePlus.sendAttemptsCount = sendAttemptsCount;
            [messagePlusses setObject:messagePlus forKey:message.messageID];
        }
    }];
    
    [self populatePendingFileAttachmentsForMessagePlusses:messagePlusses.allObjects];
    
    return messagePlusses;
}

- (AATTAnnotationInstances *)annotationInstancesOfType:(NSString *)annotationType inChannelWithID:(NSString *)channelID {
    AATTAnnotationInstances *instances = [[AATTAnnotationInstances alloc] initWithAnnotationType:annotationType];
    
    static NSString *select = @"SELECT annotation_message_id FROM annotation_instances WHERE annotation_channel_id = ? AND annotation_type = ?";
    
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQuery:select, channelID, annotationType];
        while([resultSet next]) {
            [instances addMessageID:[resultSet stringForColumnIndex:0]];
        }
    }];
    return instances;
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
    NSUInteger precisionDigits = [self precisionDigitsForLocationPrecision:locationPrecision];
    
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

- (ANKPlace *)placeForID:(NSString *)ID {
    static NSString *select = @"SELECT place_is_custom, place_json FROM places WHERE place_id = ? LIMIT 1";
    __block ANKPlace *place = nil;
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQuery:select, ID];
        if([resultSet next]) {
            BOOL placeIsCustom = [resultSet boolForColumnIndex:0];
            NSString *json = [resultSet stringForColumnIndex:1];
            NSDictionary *placeJSON = [self JSONDictionaryWithString:json];
            place = [[ANKPlace alloc] initWithJSONDictionary:placeJSON];
            
            if(placeIsCustom) {
                place = [[AATTCustomPlace alloc] initWithID:ID place:place];
            }
            [resultSet close];
        }
    }];
    return place;
}

- (NSArray *)placesForLatitude:(double)latitude longitude:(double)longitude locationPrecision:(AATTLocationPrecision)locationPrecision {
    static NSString *select = @"SELECT place_id, place_is_custom, place_json FROM places WHERE place_rounded_latitude LIKE ? AND place_rounded_longitude LIKE ?";
    NSMutableArray *places = [NSMutableArray array];
    
    NSUInteger precisionDigits = [self precisionDigitsForLocationPrecision:locationPrecision];
    
    NSString *latArg = [NSString stringWithFormat:@"%@%%", [self roundedValueAsString:latitude decimalPlaces:precisionDigits]];
    NSString *longArg = [NSString stringWithFormat:@"%@%%", [self roundedValueAsString:longitude decimalPlaces:precisionDigits]];
    
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQuery:select, latArg, longArg];
        while([resultSet next]) {
            NSString *placeID = [resultSet stringForColumnIndex:0];
            BOOL isCustom = [resultSet boolForColumnIndex:1];
            NSString *json = [resultSet stringForColumnIndex:2];
            NSDictionary *placeJSON = [self JSONDictionaryWithString:json];
            
            ANKPlace *place = [[ANKPlace alloc] initWithJSONDictionary:placeJSON];
            if(isCustom) {
                place = [[AATTCustomPlace alloc] initWithID:placeID place:place];
            }
            [places addObject:place];
        }
    }];
    
    return places;
}

- (NSArray *)placesWithNameMatchingQuery:(NSString *)query {
    return [self placesWithNameMatchingQuery:query excludeCustom:NO];
}

- (NSArray *)placesWithNameMatchingQuery:(NSString *)query excludeCustom:(BOOL)excludeCustom {
    static NSString *select = @"SELECT location_name FROM location_instances_search WHERE location_name MATCH ?";
    
    NSMutableArray *places = [NSMutableArray array];
    
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        NSMutableSet *placeNames = [NSMutableSet set];
        FMResultSet *resultSet = [db executeQuery:select, query];
        
        while([resultSet next]) {
            [placeNames addObject:[resultSet stringForColumnIndex:0]];
        }
        
        [resultSet close];
        
        if(placeNames.count > 0) {
            NSString *placeSelect = @"SELECT place_id, place_is_custom, place_json FROM places WHERE place_name IN (";
            NSMutableArray *args = [NSMutableArray arrayWithCapacity:placeNames.count + (excludeCustom ? 1 : 0)];
            
            for(NSString *placeName in placeNames) {
                [args addObject:placeName];
                
                NSString *append;
                if(args.count > 1) {
                    append = @", ?";
                } else {
                    append = @" ?";
                }
                placeSelect = [NSString stringWithFormat:@"%@%@", placeSelect, append];
            }
            placeSelect = [NSString stringWithFormat:@"%@)", placeSelect];

            if(excludeCustom) {
                placeSelect = [NSString stringWithFormat:@"%@ AND place_is_custom = ?", placeSelect];
                [args addObject:@"0"];
            }
            
            resultSet = [db executeQuery:placeSelect withArgumentsInArray:args];
            while([resultSet next]) {
                NSString *placeID = [resultSet stringForColumnIndex:0];
                BOOL isCustom = [resultSet intForColumnIndex:1] == 1;
                
                NSString *json = [resultSet stringForColumnIndex:2];
                NSDictionary *placeJSON = [self JSONDictionaryWithString:json];
                
                ANKPlace *place = [[ANKPlace alloc] initWithJSONDictionary:placeJSON];
                if(isCustom) {
                    place = [[AATTCustomPlace alloc] initWithID:placeID place:place];
                }
                [places addObject:place];
            }
        }
    }];
    
    return places;
}

- (AATTActionMessageSpec *)actionMessageSpecForActionMessageWithID:(NSString *)actionMessageID {
    NSString *select = @"SELECT * FROM action_messages WHERE action_message_id = ?";
    NSArray *specs = [self actionMessageSpecsWithSelectStatement:select arguments:@[actionMessageID]];
    if(specs.count > 0) {
        return [specs objectAtIndex:0];
    }
    return nil;
}

- (NSArray *)actionMessageSpecsForTargetMessagesWithIDs:(NSArray *)targetMessageIDs {
    return [self actionMessageSpecsForTargetMessagesWithIDs:targetMessageIDs inActionChannelWithID:nil];
}

- (NSArray *)actionMessageSpecsForTargetMessagesWithIDs:(NSArray *)targetMessageIDs inActionChannelWithID:(NSString *)actionChannelID {
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

    return [self actionMessageSpecsWithSelectStatement:select arguments:args];
}

- (NSArray *)actionMessageSpecsOrderedByTargetMessageDisplayDateInActionChannelWithID:(NSString *)actionChannelID limit:(NSUInteger)limit {
    return [self actionMessageSpecsOrderedByTargetMessageDisplayDateInActionChannelWithID:actionChannelID beforeDate:nil limit:limit];
}

- (NSArray *)actionMessageSpecsOrderedByTargetMessageDisplayDateInActionChannelWithID:(NSString *)actionChannelID beforeDate:(NSDate *)beforeDate limit:(NSUInteger)limit {
    NSString *select = @"SELECT * FROM action_messages WHERE action_message_channel_id = ?";
    NSArray *arguments = nil;
    
    if(beforeDate) {
        select = [NSString stringWithFormat:@"%@ AND CAST(action_message_target_message_display_date AS INTEGER) < ?", select];
        arguments = @[actionChannelID, [NSNumber numberWithDouble:[beforeDate timeIntervalSince1970]]];
    } else {
        arguments = @[actionChannelID];
    }
    
    select = [NSString stringWithFormat:@"%@ ORDER BY action_message_target_message_display_date DESC LIMIT %lu", select, (unsigned long)limit];
    
    return [self actionMessageSpecsWithSelectStatement:select arguments:arguments];
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

- (NSArray *)pendingFileAttachmentsForMessageWithID:(NSString *)messageID {
    static NSString *select = @"SELECT * FROM pending_file_attachments WHERE pending_file_attachment_message_id = ?";
    NSMutableArray *pendingAttachments = [NSMutableArray array];
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQuery:select, messageID];
        while([resultSet next]) {
            NSString *pendingFileID = [resultSet stringForColumnIndex:0];
            BOOL isOEmbed = [resultSet boolForColumnIndex:1];
            [pendingAttachments addObject:[[AATTPendingFileAttachment alloc] initWithPendingFileID:pendingFileID isOEmbed:isOEmbed]];
        }
    }];
    return pendingAttachments;
}

- (NSDictionary *)pendingMessageDeletionsInChannelWithID:(NSString *)channelID {
    static NSString *select = @"SELECT pending_message_deletion_message_id FROM pending_message_deletions WHERE pending_message_deletion_channel_id = ?";
    NSMutableDictionary *deletions = [[NSMutableDictionary alloc] init];
    
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQuery:select, channelID];
        while([resultSet next]) {
            NSString *messageID = [resultSet stringForColumnIndex:0];
            AATTPendingMessageDeletion *deletion = [[AATTPendingMessageDeletion alloc] initWithMessageID:messageID channelID:channelID];
            [deletions setObject:deletion forKey:messageID];
        }
    }];
    return deletions;
}

- (NSSet *)pendingFileDeletions {
    static NSString *select = @"SELECT * FROM pending_file_deletions";
    NSMutableSet *pendingFileDeletions = [NSMutableSet set];
    
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQuery:select];
        while([resultSet next]) {
            NSString *fileID = [resultSet stringForColumnIndex:0];
            [pendingFileDeletions addObject:fileID];
        }
    }];
    
    return pendingFileDeletions;
}

#pragma mark - Deletion

- (void)deleteMessagePlus:(AATTMessagePlus *)messagePlus {
    static NSString *deleteSearchableMessageText = @"DELETE FROM messages_search WHERE message_message_id=?";
    static NSString *deleteSearchableLocationInstance = @"DELETE FROM location_instances_search WHERE location_message_id=?";
    static NSString *deleteMessage = @"DELETE FROM messages WHERE message_message_id = ?";
    static NSString *deleteHashtags = @"DELETE FROM hashtag_instances WHERE hashtag_name = ? AND hashtag_message_id = ?";
    static NSString *deleteLocations = @"DELETE FROM location_instances WHERE location_message_id = ?";
    static NSString *deleteAnnotationInstances = @"DELETE FROM annotation_instances WHERE annotation_message_id = ?";
    
    ANKMessage *message = messagePlus.message;
    NSString *messageID = message.messageID;
    
    [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        //
        //IMPORTANT:
        //when adding stuff to be deleted, make sure you don't call
        //other methods that attempt to get inTransaction
        //this will cause a deadlock
        //
        [db executeUpdate:deleteSearchableMessageText, messageID];
        [db executeUpdate:deleteSearchableLocationInstance, messageID];
        [db executeUpdate:deleteAnnotationInstances, messageID];
        
        if(![db executeUpdate:deleteMessage, messageID]) {
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
        
        if(![db executeUpdate:deleteLocations, message.messageID]) {
            *rollback = YES;
            return;
        }
        
        if(messagePlus.pendingFileAttachments.count > 0) {
            for(NSString *pendingFileID in [messagePlus.pendingFileAttachments allKeys]) {
                [self deletePendingFileAttachmentForPendingFileWithID:pendingFileID messageID:message.messageID db:db];
                
                //TODO: can multiple message plus objects use the same pending file Id?
                //if so, we shouldn't do this here - must make sure no other MPs need it.
                [self deletePendingFileWithID:pendingFileID db:db];
            }
        }
    }];
}

- (void)deletePendingMessageDeletionForMessageWithID:(NSString *)messageID {
    static NSString *delete = @"DELETE FROM pending_message_deletions WHERE pending_message_deletion_message_id = ?";
    [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        if(![db executeUpdate:delete, messageID]) {
            *rollback = YES;
        }
    }];
}

- (void)deletePendingFile:(AATTPendingFile *)pendingFile {
    [self deletePendingFileWithID:pendingFile.ID];
}

- (void)deletePendingFileWithID:(NSString *)pendingFileID {
    [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        if(![self deletePendingFileWithID:pendingFileID db:db]) {
            *rollback = YES;
        }
    }];
}

- (void)deletePendingFileAttachmentForPendingFileWithID:(NSString *)pendingFileID messageID:(NSString *)messageID {
    [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        if(![self deletePendingFileAttachmentForPendingFileWithID:pendingFileID messageID:messageID db:db]) {
            *rollback = YES;
        }
    }];
}

- (void)deleteActionMessageSpecForActionMessageWithID:(NSString *)actionMessageID {
    static NSString *delete = @"DELETE FROM action_messages WHERE action_message_id = ?";
    [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        if(![db executeUpdate:delete, actionMessageID]) {
            *rollback = YES;
        }
    }];
}

- (void)deleteActionMessageSpecWithTargetMessageID:(NSString *)targetMessageID actionChannelID:(NSString *)actionChannelID {
    static NSString *delete = @"DELETE FROM action_messages WHERE action_message_channel_id = ? AND action_message_target_message_id = ?";
    [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        if(![db executeUpdate:delete, actionChannelID, targetMessageID]) {
            *rollback = YES;
        }
    }];
}

- (void)deletePendingFileDeletionForFileWithID:(NSString *)fileID {
    static NSString *delete = @"DELETE FROM pending_file_deletions WHERE pending_file_deletion_file_id = ?";
    [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        if(![db executeUpdate:delete, fileID]) {
            *rollback = YES;
        }
    }];
}

- (void)deletePlaceWithID:(NSString *)ID {
    static NSString *delete = @"DELETE FROM places WHERE place_id = ?";
    [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        if(![db executeUpdate:delete, ID]) {
            *rollback = YES;
        }
    }];
}

- (void)deletePlaces {
    static NSString *delete = @"DELETE FROM places";
    [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        if(![db executeUpdate:delete]) {
            *rollback = YES;
        }
    }];
}

- (void)deleteAll {
    [self.databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        [db executeUpdate:@"DELETE FROM action_messages"];
        [db executeUpdate:@"DELETE FROM annotation_instances"];
        [db executeUpdate:@"DELETE FROM geolocations"];
        [db executeUpdate:@"DELETE FROM hashtag_instances"];
        [db executeUpdate:@"DELETE FROM location_instances"];
        [db executeUpdate:@"DELETE FROM location_instances_search"];
        [db executeUpdate:@"DELETE FROM messages"];
        [db executeUpdate:@"DELETE FROM messages_search"];
        [db executeUpdate:@"DELETE FROM pending_file_attachments"];
        [db executeUpdate:@"DELETE FROM pending_files"];
        [db executeUpdate:@"DELETE FROM pending_message_deletions"];
        [db executeUpdate:@"DELETE FROM places"];
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

- (NSUInteger)maxMessageID {
    __block NSUInteger maxID = 0;
    static NSString *select = @"SELECT MAX(message_id) FROM messages";
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQuery:select];
        if([resultSet next]) {
            maxID = [resultSet intForColumnIndex:0];
            [resultSet close];
        }
    }];
    return maxID;
}

- (NSUInteger)maxDisplayLocationInstanceID {
    __block NSUInteger maxID = 0;
    static NSString *select = @"SELECT MAX(location_id) FROM location_instances";
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQuery:select];
        if([resultSet next]) {
            maxID = [resultSet intForColumnIndex:0];
            [resultSet close];
        }
    }];
    return maxID;
}

#pragma mark - Private Stuff

- (AATTOrderedMessageBatch *)messagesWithSelectStatement:(NSString *)selectStatement arguments:(NSArray *)arguments {
    NSMutableOrderedDictionary *messagePlusses = [[NSMutableOrderedDictionary alloc] init];
    NSMutableArray *unsentMessagePlusses = [NSMutableArray array];
    __block NSInteger maxID = -1;
    __block NSInteger minID = -1;
    __block NSDate *minDate = nil;
    __block NSDate *maxDate = nil;
    
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQuery:selectStatement withArgumentsInArray:arguments];
        
        NSString *messageID = nil;
        NSDate *date = nil;
        
        ANKMessage *m = nil;
        while([resultSet next]) {
            messageID = [resultSet stringForColumnIndex:1];
            //2 is channel; will come from json
            date = [NSDate dateWithTimeIntervalSince1970:[resultSet doubleForColumnIndex:3]];
            NSString *messageJSONString = [resultSet stringForColumnIndex:4];
            NSString *messageText = [resultSet stringForColumnIndex:5];
            BOOL isUnsent = [resultSet boolForColumnIndex:6];
            NSInteger sendAttemptsCount = [resultSet intForColumnIndex:7];
            
            NSDictionary *messageJSON = [self JSONDictionaryWithString:messageJSONString];
            m = [[ANKMessage alloc] initWithJSONDictionary:messageJSON];
            m.text = messageText;
            
            AATTMessagePlus *messagePlus = [[AATTMessagePlus alloc] initWithMessage:m];
            messagePlus.isUnsent = isUnsent;
            messagePlus.sendAttemptsCount = sendAttemptsCount;
            messagePlus.displayDate = date;
            [messagePlusses setObject:messagePlus forKey:messageID];
            
            if(!maxID) {
                maxDate = date;
            }
            
            if(!isUnsent) {
                NSInteger messageIDAsInt = [messageID integerValue];
                if(!maxID) {
                    maxID = messageIDAsInt;
                    minID = messageIDAsInt;
                } else {
                    //this must happen because id order is not necessarily same as date order
                    //(and we know the results are ordered by date)
                    maxID = MAX(messageIDAsInt, maxID);
                    minID = MIN(messageIDAsInt, minID);
                }
            }
        
            //this is just for efficiency
            //if it is already sent, then we don't need to try to populate pending
            //file attachments.
            if(isUnsent) {
                [unsentMessagePlusses addObject:messagePlus];
            }
        }
        //because they're ordered by recency, we know the last one will be the minDate
        minDate = date;
    }];
    
    [self populatePendingFileAttachmentsForMessagePlusses:unsentMessagePlusses];
    
    NSString *minIDString = minID != -1 ? [NSString stringWithFormat:@"%ld", (long)minID] : nil;
    NSString *maxIDString = maxID != -1 ? [NSString stringWithFormat:@"%ld", (long)maxID] : nil;
    
    AATTMinMaxPair *minMaxPair = [[AATTMinMaxPair alloc] initWithMinID:minIDString maxID:maxIDString minDate:minDate maxDate:maxDate];
    return [[AATTOrderedMessageBatch alloc] initWithOrderedMessagePlusses:messagePlusses minMaxPair:minMaxPair];
}

- (NSArray *)actionMessageSpecsWithSelectStatement:(NSString *)select arguments:(NSArray *)arguments {
    NSMutableArray *actionMessageSpecs = [NSMutableArray array];
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQuery:select withArgumentsInArray:arguments];
        while([resultSet next]) {
            NSString *aMessageID = [resultSet stringForColumnIndex:0];
            NSString *aChannelID = [resultSet stringForColumnIndex:1];
            NSString *tMessageID = [resultSet stringForColumnIndex:2];
            NSString *tChannelID = [resultSet stringForColumnIndex:3];
            NSDate *tMessageDate = [NSDate dateWithTimeIntervalSince1970:[resultSet doubleForColumnIndex:4]];
            
            AATTActionMessageSpec *spec = [[AATTActionMessageSpec alloc] initWithActionMessageID:aMessageID actionChannelID:aChannelID targetMessageID:tMessageID targetChannelID:tChannelID targetMessageDate:tMessageDate];
            [actionMessageSpecs addObject:spec];
        }
    }];
    return actionMessageSpecs;
}

- (void)populatePendingFileAttachmentsForMessagePlusses:(NSArray *)messagePlusses {
    for(AATTMessagePlus *messagePlus in messagePlusses) {
        NSArray *pendingAttachments = [self pendingFileAttachmentsForMessageWithID:messagePlus.message.messageID];
        NSMutableDictionary *pendingAttachmentsDictionary = [NSMutableDictionary dictionaryWithCapacity:pendingAttachments.count];
        for(AATTPendingFileAttachment *attachment in pendingAttachments) {
            [pendingAttachmentsDictionary setObject:attachment forKey:attachment.pendingFileID];
        }
        messagePlus.pendingFileAttachments = pendingAttachmentsDictionary;
    }
}

- (BOOL)deletePendingFileAttachmentForPendingFileWithID:(NSString *)pendingFileID messageID:(NSString *)messageID db:(FMDatabase *)db {
    static NSString *delete = @"DELETE FROM pending_file_attachments WHERE pending_file_attachment_file_id = ? AND pending_file_attachment_message_id = ?";
    return [db executeUpdate:delete, pendingFileID, messageID];
}

- (BOOL)deletePendingFileWithID:(NSString *)pendingFileID db:(FMDatabase *)db {
    static NSString *delete = @"DELETE FROM pending_files WHERE pending_file_id = ?";
    return [db executeUpdate:delete, pendingFileID];
}

- (void)insertSearchableMessageTextForMessageWithRowID:(NSUInteger)rowID messageID:(NSString *)messageID channelID:(NSString *)channelID text:(NSString *)text withDB:(FMDatabase *)db {
    if(text) {
        static NSString *insert = @"INSERT INTO messages_search (docid, message_message_id, message_channel_id, message_text) VALUES (?, ?, ?, ?)";
        [db executeUpdate:insert, [NSNumber numberWithUnsignedInteger:rowID], messageID, channelID, text];
    }
}

- (void)insertSearchableDisplayLocationInstanceWithRowID:(NSUInteger)rowID messageID:(NSString *)messageID channelID:(NSString *)channelID name:(NSString *)name withDB:(FMDatabase *)db {
    if(name) {
        static NSString *insert = @"INSERT INTO location_instances_search (docid, location_message_id, location_channel_id, location_name) VALUES (?, ?, ?, ?)";
        [db executeUpdate:insert, [NSNumber numberWithUnsignedInteger:rowID], messageID, channelID, name];
    }
}

- (NSString *)JSONStringWithANKResource:(ANKResource *)resource {
    NSError *error;
    NSData *JSONData = [NSJSONSerialization dataWithJSONObject:resource.JSONDictionary options:0 error:&error];
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

- (NSUInteger)precisionDigitsForLocationPrecision:(AATTLocationPrecision)locationPrecision {
    NSUInteger precisionDigits = 3;
    if(locationPrecision == AATTLocationPrecisionOneThousandMeters) {
        precisionDigits = 2;
    } else if(locationPrecision == AATTLocationPrecisionTenThousandMeters) {
        precisionDigits = 1;
    }
    return precisionDigits;
}

@end
