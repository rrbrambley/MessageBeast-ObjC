//
//  AATTActionMessageManager.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 12/1/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTActionMessageSpec.h"
#import "ANKClient+PrivateChannel.h"
#import "ANKChannel+AATTAnnotationHelper.h"
#import "ANKMessage+AATTAnnotationHelper.h"
#import "AATTActionMessageManager.h"
#import "AATTADNDatabase.h"
#import "AATTMessageManager.h"
#import "AATTMessagePlus.h"
#import "NSOrderedDictionary.h"

@interface AATTActionMessageManager ()
@property (nonatomic) AATTMessageManager *messageManager;
@property NSMutableDictionary *actionChannels;
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
        self.database = [AATTADNDatabase sharedInstance];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didSendUnsentMessages:) name:AATTMessageManagerDidSendUnsentMessagesNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Action Channel

- (void)initActionChannelWithType:(NSString *)actionType targetChannel:(ANKChannel *)targetChannel completionBlock:(AATTActionMessageManagerChannelInitBlock)completionBlock {
    [self.messageManager.client getOrCreateActionChannelWithType:actionType targetChannel:targetChannel completionBlock:^(id responseObject, NSError *error) {
        if(responseObject) {
            ANKChannel *channel = responseObject;
            [self.actionChannels setObject:channel forKey:channel.channelID];
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

#pragma mark - Other Getters

- (AATTMessageManager *)messageManager {
    return self.messageManager;
}

#pragma mark - Retrieval

- (void)fetchAndPersistAllMessagesInActionChannelWithID:(NSString *)actionChannelId targetChannelId:(NSString *)targetChannelId completionBlock:(AATTMessageManagerCompletionBlock)completionBlock {
    [self.messageManager fetchAndPersistAllMessagesInChannelWithID:actionChannelId batchSyncBlock:^(NSArray *messagePlusses, ANKAPIResponseMeta *meta, NSError *error) {
        if(!error) {
            NSLog(@"synced batch of %lu messages", (unsigned long)messagePlusses.count);
            for(AATTMessagePlus *messagePlus in messagePlusses) {
                NSString *targetMessageId = [messagePlus.message targetMessageId];
                [self.database insertOrReplaceActionMessageSpec:messagePlus targetMessageId:targetMessageId targetChannelId:targetChannelId];
            }
        } else {
            NSLog(@"Batch sync failed with error: %@", error.localizedDescription);
        }
    } completionBlock:^(NSArray *messagePlusses, BOOL appended, ANKAPIResponseMeta *meta, NSError *error) {
        if(!error) {
            completionBlock(messagePlusses, appended, meta, error);
        } else {
            completionBlock(messagePlusses, appended, meta, error);
        }
    }];
}

#pragma mark - Apply/Remove Actions

- (void)applyActionForActionChannelWithID:(NSString *)actionChannelID toTargetMessagePlus:(AATTMessagePlus *)messagePlus  {
    if(![self isActionedTargetMessageID:messagePlus.message.messageID inActionChannelWithID:actionChannelID]) {
        ANKMessage *message = messagePlus.message;
        NSString *targetMessageID = message.messageID;
        ANKMessage *m = [[ANKMessage alloc] init];
        m.isMachineOnly = YES;
        [m addTargetMessageAnnotationWithTargetMessageID:targetMessageID];
        
        AATTMessagePlus *unsentActionMessage = [self.messageManager createUnsentMessageAndAttemptSendInChannelWithID:actionChannelID message:m];
        [self.database insertOrReplaceActionMessageSpec:unsentActionMessage targetMessageId:targetMessageID targetChannelId:message.channelID];
    }
}

- (void)removeActionForActionChannelWithID:(NSString *)actionChannelID fromTargetMessageWithID:(NSString *)targetMessageID  {
    NSArray *targetMessageIDs = @[targetMessageID];
    NSArray *actionMessageSpecs = [self.database actionMessageSpecsForTargetMessagesWithIDs:targetMessageIDs inActionChannelWithID:actionChannelID];
    
    if(actionMessageSpecs.count > 0) {
        [self.database deleteActionMessageSpecWithTargetMessageID:targetMessageID actionChannelID:actionChannelID];
        [self deleteActionMessageUsingSpecFromArray:actionMessageSpecs atIndex:0 completionBlock:^(void) {
            NSLog(@"deleted %lu actionMessages in channel %@", (unsigned long)actionMessageSpecs.count, actionChannelID);
        }];
    } else {
        NSLog(@"Attempting to remove action channel %@ action; target message ID %@ yielded %lu db results", actionChannelID, targetMessageID, (unsigned long)actionMessageSpecs.count);
    }
}

//
// It is possible to have multiple action messages targeting the same message. This typically doesn't happen,
// but since it's possible, we should make sure to delete *all* of the action messages
//
- (void)deleteActionMessageUsingSpecFromArray:(NSArray *)actionMessageSpecs atIndex:(NSUInteger)currentIndex completionBlock:(void (^)(void))completionBlock {
    AATTActionMessageSpec *spec = [actionMessageSpecs objectAtIndex:currentIndex];
    NSString *actionChannelID = spec.actionChannelID;
    AATTMessagePlus *actionMessagePlus = [self.database messagePlusForMessageInChannelWithID:actionChannelID messageID:spec.actionMessageID];
    
    [self.messageManager deleteMessage:actionMessagePlus completionBlock:^(ANKAPIResponseMeta *meta, NSError *error) {
        if(error) {
            NSLog(@"Failed to delete action message %@ for target message %@", spec.actionMessageID, spec.targetMessageID);
        } else {
            NSLog(@"Successfully deleted action message %@ for target message %@", spec.actionMessageID, spec.targetMessageID);
        }
        NSInteger nextIndex = currentIndex + 1;
        if(nextIndex < actionMessageSpecs.count) {
            [self deleteActionMessageUsingSpecFromArray:actionMessageSpecs atIndex:nextIndex completionBlock:completionBlock];
        } else {
            completionBlock();
        }
    }];
}

#pragma mark - NSNotification

- (void)didSendUnsentMessages:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSString *channelID = [userInfo objectForKey:@"channelID"];
    NSArray *messageIDs = [userInfo objectForKey:@"messageIDs"];
    
    //this is not an action channel.
    //it might be a target channel of one of our action channels though.
    if(![self.actionChannels objectForKey:channelID]) {
        //remove all action messages that point to this now nonexistent target message id
        NSArray *sentTargetMessages = [self.database actionMessageSpecsForTargetMessagesWithIDs:messageIDs];
        for(AATTActionMessageSpec *spec in sentTargetMessages) {
            [self.database deleteActionMessageSpecWithTargetMessageID:spec.targetMessageID actionChannelID:spec.actionChannelID];
        }
    } else {
        //it's an action channel
        //delete the action messages in the database with the sent message ids,
        //retrieve the new ones
        
        ANKChannel *actionChannel = [self.actionChannels objectForKey:channelID];
        NSString *targetChannelID = [actionChannel targetChannelID];
        [self.messageManager fetchNewestMessagesInChannelWithID:channelID completionBlock:^(NSArray *messagePlusses, BOOL appended, ANKAPIResponseMeta *meta, NSError *error) {
            if(!error) {
                for(NSString *sentMessageID in messageIDs) {
                    [self.database deleteActionMessageSpecForActionMessageWithID:sentMessageID];
                }
                for(AATTMessagePlus *messagePlus in messagePlusses) {
                    [self.database insertOrReplaceActionMessageSpec:messagePlus targetMessageId:messagePlus.message.targetMessageId targetChannelId:targetChannelID];
                }
            } else {
                NSLog(@"Could not fetch newest messages for action channel with ID %@; %@", channelID, error.localizedDescription);
            }
        }];
    }
}

#pragma mark - Private

- (NSArray *)targetMessagePlussesForActionMessages:(NSArray *)actionMessages actionChannelId:(NSString *)actionChannelId targetChannelId:(NSString *)targetChannelId {
    NSSet *targetMessageIds = [self targetMessageIdsForMessagePlusses:actionMessages];
    NSOrderedDictionary *targetMessages = [self.messageManager loadPersistedMessagesTemporarilyForChannelWithID:targetChannelId messageIDs:targetMessageIds];
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
