//
//  AATTActionMessageManager.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 12/1/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTActionMessageSpec.h"
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

+ (AATTActionMessageManager *)sharedInstanceWithMessageManager:(AATTMessageManager *)messageManager {
    static AATTActionMessageManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[AATTActionMessageManager alloc] initWithMessageManager:messageManager];
    });
    
    return sharedInstance;
}

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

#pragma mark - Action Channel

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

#pragma mark - Lookup

- (BOOL)isActionedTargetMessageID:(NSString *)targetMessageID inActionChannelWithID:(NSString *)actionChannelID {
    return [self.database hasActionMessageSpecForActionChannelWithID:actionChannelID targetMessageID:targetMessageID];
}

#pragma mark - Retrieval

- (void)fetchAndPersistAllMessagesInActionChannelWithID:(NSString *)actionChannelId targetChannelId:(NSString *)targetChannelId completionBlock:(AATTMessageManagerCompletionBlock)completionBlock {
    [self.messageManager fetchAndPersistAllMessagesInChannelWithID:actionChannelId batchSyncBlock:^(NSArray *messagePlusses, ANKAPIResponseMeta *meta, NSError *error) {
        if(!error) {
            NSLog(@"synced batch of %d messages", messagePlusses.count);
            for(AATTMessagePlus *messagePlus in messagePlusses) {
                NSString *targetMessageId = [messagePlus.message targetMessageId];
                [self.database insertOrReplaceActionMessageSpec:messagePlus targetMessageId:targetMessageId targetChannelId:targetChannelId];
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

#pragma mark - Apply/Remove Actions

- (void)applyActionForActionChannelWithID:(NSString *)actionChannelID toTargetMessagePlus:(AATTMessagePlus *)messagePlus  {
    if(![self isActionedTargetMessageID:messagePlus.message.messageID inActionChannelWithID:actionChannelID]) {
        NSMutableOrderedDictionary *actionedMessages = [self existingOrNewActionedMessagesMapForActionChannelWithID:actionChannelID];
        ANKMessage *message = messagePlus.message;
        NSString *targetMessageID = message.messageID;
        if(![actionedMessages objectForKey:targetMessageID]) {
            ANKMessage *m = [[ANKMessage alloc] init];
            m.isMachineOnly = YES;
            [m addTargetMessageAnnotationWithTargetMessageID:targetMessageID];
            
            AATTMessagePlus *unsentActionMessage = [self.messageManager createUnsentMessageAndAttemptSendInChannelWithID:actionChannelID message:m];
            [actionedMessages setObject:messagePlus forKey:targetMessageID];
            [self.database insertOrReplaceActionMessageSpec:unsentActionMessage targetMessageId:targetMessageID targetChannelId:message.channelID];
        }
    }
}

- (void)removeActionForActionChannelWithID:(NSString *)actionChannelID fromTargetMessageWithID:(NSString *)targetMessageID  {
    NSArray *targetMessageIDs = @[targetMessageID];
    NSArray *actionMessageSpecs = [self.database actionMessageSpecsForTargetMessagesWithIDs:targetMessageIDs inActionChannelWithID:actionChannelID];
    
    if(actionMessageSpecs.count == 1) {
        [self.database deleteActionMessageSpecWithTargetMessageID:targetMessageID actionChannelID:actionChannelID];
        NSMutableOrderedDictionary *actionedMessages = [self existingOrNewActionedMessagesMapForActionChannelWithID:actionChannelID];
        if([actionedMessages objectForKey:targetMessageID]) {
            [actionedMessages removeEntryWithKey:targetMessageID];
        }
        
        AATTActionMessageSpec *spec = [actionMessageSpecs objectAtIndex:0];
        AATTMessagePlus *actionMessagePlus = [self.database messagePlusForMessageInChannelWithID:actionChannelID messageID:spec.actionMessageID];
        [self.messageManager deleteMessage:actionMessagePlus completionBlock:^(ANKAPIResponseMeta *meta, NSError *error) {
            if(!error) {
                NSLog(@"Successfully deleted action message %@ for target message %@", spec.actionMessageID, targetMessageID);
            } else {
                NSLog(@"Failed to delete action message %@ for target message %@", spec.actionMessageID, targetMessageID);
            }
        }];
    } else {
        NSLog(@"Attempting to remove action channel %@ action; target message ID %@ yielded %d db results", actionChannelID, targetMessageID, actionMessageSpecs.count);
    }
}

#pragma mark - Private

- (NSMutableOrderedDictionary *)existingOrNewActionedMessagesMapForActionChannelWithID:(NSString *)channelID {
    NSMutableOrderedDictionary *channelDictionary = [self.actionedMessages objectForKey:channelID];
    if(!channelDictionary) {
        channelDictionary = [[NSMutableOrderedDictionary alloc] init];
        [self.actionedMessages setObject:channelDictionary forKey:channelID];
    }
    return channelDictionary;
}

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
