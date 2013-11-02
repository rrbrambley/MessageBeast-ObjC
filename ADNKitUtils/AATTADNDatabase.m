//
//  AATTADNDatabase.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/30/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTADNDatabase.h"
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
        }];
    }
    return self;
}

- (void)insertOrReplaceMessage:(AATTMessagePlus *)message {
    static NSString *insertOrReplaceMessage = @"INSERT OR REPLACE INTO messages (message_id, message_channel_id, message_date, message_json) VALUES(?, ?, ?, ?)";
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        NSString *jsonString = [self JSONStringWithMessage:message.message];
        [db executeUpdate:insertOrReplaceMessage, message.message.messageID, message.message.channelID, [NSNumber numberWithDouble:[message.displayDate timeIntervalSince1970]], jsonString];
    }];
}

- (AATTOrderedMessageBatch *)messagesInChannelWithId:(NSString *)channelId limit:(NSUInteger)limit {
    return [self messagesInChannelWithId:channelId beforeDate:nil limit:limit];
}

- (AATTOrderedMessageBatch *)messagesInChannelWithId:(NSString *)channelId beforeDate:(NSDate *)beforeDate limit:(NSUInteger)limit {
    
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


@end
