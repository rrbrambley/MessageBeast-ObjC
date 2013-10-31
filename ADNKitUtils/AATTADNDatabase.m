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
        }];
    }
    return self;
}

- (void)insertOrReplaceMessage:(AATTMessagePlus *)message {
    static NSString *insertOrReplaceMessage = @"INSERT OR REPLACE INTO messages (message_id, message_channel_id, message_date, message_json) VALUES(?, ?, ?, ?";
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:insertOrReplaceMessage, message.message.messageID, message.message.channelID, [message.displayDate timeIntervalSince1970], message.message.JSONDictionary.description];
    }];
}

- (AATTOrderedMessageBatch *)messagesInChannelWithId:(NSString *)channelId limit:(NSInteger)limit {
    return [self messagesInChannelWithId:channelId beforeDate:nil limit:limit];
}

- (AATTOrderedMessageBatch *)messagesInChannelWithId:(NSString *)channelId beforeDate:(NSDate *)beforeDate limit:(NSInteger)limit {
    NSString *messageString = nil;
    ANKMessage *m = [[ANKMessage alloc] initWithJSONDictionary:[[NSDictionary alloc] initWithContentsOfFile:messageString]];
    return nil;
}


@end
