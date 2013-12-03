//
//  AATTActionMessageManager.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 12/1/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "ANKClient+PrivateChannel.h"
#import "ANKMessage+AATTAnnotationHelper.h"
#import "AATTActionMessageManager.h"
#import "AATTADNDatabase.h"
#import "AATTMessageManager.h"
#import "AATTMessagePlus.h"
#import "NSOrderedDictionary.h"

@interface AATTActionMessageManager ()
@property AATTMessageManager *messageManager;
@property NSMutableDictionary *actionChannels;
@property NSMutableDictionary *actionedMessages;
@property AATTADNDatabase *database;
@end

@implementation AATTActionMessageManager

- (id)initWithMessageManager:(AATTMessageManager *)messageManager {
    self = [super init];
    if(self) {
        self.messageManager = messageManager;
        self.actionChannels = [NSMutableDictionary dictionaryWithCapacity:1];
        self.actionedMessages = [NSMutableDictionary dictionaryWithCapacity:1];
        self.database = [AATTADNDatabase sharedInstance];
    }
    return self;
}

- (void)initActionChannelWithType:(NSString *)actionType targetChannel:(ANKChannel *)targetChannel completionBlock:(AATTActionMessageManagerChannelInitBlock)completionBlock {
    [self.messageManager.client getOrCreateActionChannelWithType:actionType targetChannel:targetChannel completionBlock:^(id responseObject, NSError *error) {
        if(responseObject) {
            ANKChannel *channel = responseObject;
            NSDictionary *parameters = @{@"include_deleted" : @0, @"include_machine" : @1, @"include_message_annotations" : @1};
            [self.messageManager setQueryParametersForChannelWithID:channel.channelID parameters:parameters];
            completionBlock(responseObject, error);
        } else {
            completionBlock(responseObject, error);
        }
    }];
}

- (void)fetchAndPersistAllMessagesInActionChannelWithID:(NSString *)actionChannelId targetChannelId:(NSString *)targetChannelId completionBlock:(AATTMessageManagerCompletionBlock)completionBlock {
    [self.messageManager fetchAndPersistAllMessagesInChannelWithID:actionChannelId batchSyncBlock:^(NSArray *messagePlusses, ANKAPIResponseMeta *meta, NSError *error) {
        if(!error) {
            NSLog(@"synced batch of %d messages", messagePlusses.count);
            for(AATTMessagePlus *messagePlus in messagePlusses) {
                NSString *targetMessageId = [messagePlus.message targetMessageId];
                [self.database insertOrReplaceActionMessage:messagePlus targetMessageId:targetMessageId targetChannelId:targetChannelId];
            }
        } else {
            NSLog(@"Batch sync failed with error: %@", error.localizedDescription);
        }
    } completionBlock:^(NSArray *messagePlusses, BOOL appended, ANKAPIResponseMeta *meta, NSError *error) {
        if(!error) {
            [self storeTargetMessagesInMemoryForActionMessages:messagePlusses actionChannelId:actionChannelId targetChannelId:targetChannelId];
            completionBlock(messagePlusses, appended, meta, error);
        } else {
            completionBlock(messagePlusses, appended, meta, error);
        }
    }];
}

#pragma mark - Private

- (NSArray *)storeTargetMessagesInMemoryForActionMessages:(NSArray *)actionMessages actionChannelId:(NSString *)actionChannelId targetChannelId:(NSString *)targetChannelId {
    NSSet *targetMessageIds = [self targetMessageIdsForMessagePlusses:actionMessages];
    NSOrderedDictionary *targetMessages = [self.messageManager loadPersistedMessagesTemporarilyForChannelWithID:targetChannelId messageIDs:targetMessageIds];
    //TODO: prolly wanna sort dat.
    [self.actionedMessages setObject:targetMessages forKey:actionChannelId];
    return [targetMessages allObjects];
}

- (NSSet *)targetMessageIdsForMessagePlusses:(NSArray *)messagePlusses {
    NSMutableSet *targetMessageIds = [NSMutableSet setWithCapacity:messagePlusses.count];
    for(AATTMessagePlus *mp in messagePlusses) {
        [targetMessageIds addObject:[mp.message targetMessageId]];
    }
    return targetMessageIds;
}

@end
