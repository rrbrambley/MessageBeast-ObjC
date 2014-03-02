//
//  AATTActionMessageManager.m
//  MessageBeast
//
//  Created by Rob Brambley on 12/1/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTActionMessageSpec.h"
#import "AATTOrderedMessageBatch.h"
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
        [messageManager attachActionMessageManager:self];
        
        self.messageManager = messageManager;
        self.actionChannels = [NSMutableDictionary dictionaryWithCapacity:1];
        self.database = [AATTADNDatabase sharedInstance];
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

- (NSArray *)actionedMessagesInActionChannelWithID:(NSString *)actionChannelID beforeDate:(NSDate *)beforeDate limit:(NSUInteger)limit {
    NSArray *actionMessageSpecs = [self.database actionMessageSpecsOrderedByTargetMessageDisplayDateInActionChannelWithID:actionChannelID beforeDate:beforeDate limit:limit];
    NSMutableSet *targetMessageIDs = [NSMutableSet setWithCapacity:actionMessageSpecs.count];
    for(AATTActionMessageSpec *spec in actionMessageSpecs) {
        [targetMessageIDs addObject:spec.targetMessageID];
    }
    NSOrderedDictionary *targetMessages = [self.messageManager persistedMessagesWithMessageIDs:targetMessageIDs];
    return [NSArray arrayWithArray:targetMessages.allObjects];
}

#pragma mark - Other Getters

- (AATTMessageManager *)messageManager {
    return _messageManager;
}

#pragma mark - Retrieval

- (void)fetchAndPersistAllMessagesInActionChannelWithID:(NSString *)actionChannelID completionBlock:(AATTMessageManagerCompletionBlock)completionBlock {
    [self.messageManager fetchAndPersistAllMessagesInChannelWithID:actionChannelID batchSyncBlock:^(NSArray *messagePlusses, ANKAPIResponseMeta *meta, NSError *error) {
        if(!error) {
            NSLog(@"synced batch of %lu messages", (unsigned long)messagePlusses.count);
            [self processNewActionMessages:messagePlusses];
        } else {
            NSLog(@"Batch sync failed with error: %@", error.localizedDescription);
        }
    } completionBlock:^(NSArray *messagePlusses, ANKAPIResponseMeta *meta, NSError *error) {
        if(!error) {
            completionBlock(messagePlusses, meta, error);
        } else {
            completionBlock(messagePlusses, meta, error);
        }
    }];
}

- (BOOL)fetchNewestMessagesInActionChannelWithID:(NSString *)actionChannelID completionBlock:(AATTMessageManagerCompletionBlock)completionBlock {
    NSArray *messages = [self.messageManager loadedMessagesForChannelWithID:actionChannelID];
    if(!messages || messages.count == 0) {
        //we do this so that the max id is known.
        [self.messageManager loadPersistedMesssageForChannelWithID:actionChannelID limit:1];
    }
    BOOL canFetch = [self.messageManager fetchNewestMessagesInChannelWithID:actionChannelID completionBlock:^(NSArray *messagePlusses, ANKAPIResponseMeta *meta, NSError *error) {
        if(!error) {
            [self processNewActionMessages:messagePlusses];
        }
        completionBlock(messagePlusses, meta, error);
    }];
    return canFetch;
}

#pragma mark - Apply/Remove Actions

- (void)applyActionForActionChannelWithID:(NSString *)actionChannelID toTargetMessagePlus:(AATTMessagePlus *)messagePlus  {
    if(![self isActionedTargetMessageID:messagePlus.message.messageID inActionChannelWithID:actionChannelID]) {
        ANKMessage *message = messagePlus.message;
        NSString *targetMessageID = message.messageID;
        ANKMessage *m = [[ANKMessage alloc] init];
        m.isMachineOnly = YES;
        [m addTargetMessageAnnotationWithTargetMessageID:targetMessageID];
        
        AATTMessagePlus *unsentActionMessage = [self.messageManager createUnsentMessageAndAttemptSendInChannelWithID:actionChannelID message:m attemptToSendImmediately:!messagePlus.isUnsent];
        [self.database insertOrReplaceActionMessageSpec:unsentActionMessage targetMessageID:targetMessageID targetChannelID:message.channelID targetMessageDisplayDate:messagePlus.displayDate];
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
    AATTMessagePlus *actionMessagePlus = [self.database messagePlusForMessageID:spec.actionMessageID];
    
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

#pragma mark - Other

- (BOOL)sendUnsentActionMessagesForChannelWithID:(NSString *)actionChannelID {
    if([self.actionChannels objectForKey:actionChannelID]) {
        NSOrderedDictionary *unsentActionMessages = [self.database unsentMessagesInChannelWithID:actionChannelID];
        NSMutableSet *targetMessageIDs = [NSMutableSet set];
        
        for(AATTMessagePlus *unsentActionMessage in [unsentActionMessages allObjects]) {
            [targetMessageIDs addObject:[unsentActionMessage.message targetMessageID]];
        }
        
        //
        //check to see if all target messages associated with messages in this action channel have
        //been sent. if so, we are good to call sendAllUnsentForChannelWithID:
        //
        BOOL allSent = YES;
        AATTOrderedMessageBatch *targetMessageBatch = [self.database messagesWithIDs:targetMessageIDs];
        NSOrderedDictionary *messagePlusses = targetMessageBatch.messagePlusses;
        for(AATTMessagePlus *targetMessagePlus in [messagePlusses allObjects]) {
            allSent &= !targetMessagePlus.isUnsent;
        }
        
        if(allSent) {
            [self.messageManager sendAllUnsentForChannelWithID:actionChannelID];
            return YES;
        }
    } else {
        NSLog(@"Calling sendUnsentActionMessagesForChannelWithID: for a channel that AATTActionMessageManager is unaware of. Did you forget to init the channel first?");
    }
    return NO;
}

- (void)didSendUnsentMessagesInChannelWithID:(NSString *)channelID sentMessageIDs:(NSArray *)sentMessageIDs replacementMessageIDs:(NSArray *)replacementMessageIDs {

    //this is not an action channel.
    //it might be a target channel of one of our action channels though.
    if(![self.actionChannels objectForKey:channelID]) {
        //for any action messages that targeted the unsent message,
        //we now need to create a new action message spec that points to the NEW message id
        //to replace the former one.
        //
        //additionally, we need to make sure to send unsent action messages now that their
        //associated target messages have been sent.
        //
        
        NSMutableSet *actionChannelIDs = [NSMutableSet set];
        NSArray *actionMessageSpes = [self.database actionMessageSpecsForTargetMessagesWithIDs:sentMessageIDs];
        for(AATTActionMessageSpec *actionMessageSpec in actionMessageSpes) {
            NSString *actionMessageID = actionMessageSpec.actionMessageID;
            NSString *actionChannelID = actionMessageSpec.actionChannelID;
            NSString *oldTargetMessageID = actionMessageSpec.targetMessageID;
            NSString *newTargetMessageID = [replacementMessageIDs objectAtIndex:[sentMessageIDs indexOfObject:oldTargetMessageID]];
            NSString *targetMessageChannelID = channelID;
            NSDate *targetMessageDisplayDate = actionMessageSpec.targetMessageDate;
            
            NSLog(@"Updating action message spec; target id change: %@ ---> %@", oldTargetMessageID, newTargetMessageID);
            
            [self.database insertOrReplaceActionMessageSpecForActionMessageWithID:actionMessageID actionChannelID:actionChannelID targetMessageID:newTargetMessageID targetChannelID:targetMessageChannelID targetMessageDisplayDate:targetMessageDisplayDate];
            
            AATTMessagePlus *actionMessage = [self.database messagePlusForMessageID:actionMessageID];
            if(actionMessage) {
                NSString *formerTargetMessageID = [actionMessage.message targetMessageID];
                if(formerTargetMessageID) {
                    [actionMessage replaceTargetMessageAnnotationMessageID:newTargetMessageID];
                    [self.database insertOrReplaceMessage:actionMessage];
                    [self.messageManager replaceInMemoryMessagePlusWithMessagePlus:actionMessage];
                    
                    NSLog(@"replaced message's target message id annotation: %@ --> %@", formerTargetMessageID, [actionMessage.message targetMessageID]);
                } else {
                    NSLog(@"message %@ is not actually an action message. we're in a bad state. bummer.", actionMessageID);
                }
            }
            
            [actionChannelIDs addObject:actionChannelID];
        }
        
        for(NSString *actionChannelID in actionChannelIDs) {
            [self.messageManager sendAllUnsentForChannelWithID:actionChannelID];
            NSLog(@"didSendUnsentMessagesInChannelWithID; sending all unsent messages for action channel %@", actionChannelID);
        }
        [self.messageManager sendUnsentMessagesSentNotificationForChannelID:channelID sentMessageIDs:sentMessageIDs replacementMessageIDs:replacementMessageIDs];
    } else {
        //it's an action channel
        //replace the old specs' action message ids with the replacement ones
        
        for(NSUInteger i = 0; i < sentMessageIDs.count; i++) {
            NSString *actionMessageID = [sentMessageIDs objectAtIndex:i];
            AATTActionMessageSpec *oldSpec = [self.database actionMessageSpecForActionMessageWithID:actionMessageID];
            if(oldSpec) {
                NSString *newActionMessageID = [replacementMessageIDs objectAtIndex:i];
                [self.database insertOrReplaceActionMessageSpecForActionMessageWithID:newActionMessageID actionChannelID:oldSpec.actionChannelID targetMessageID:oldSpec.targetMessageID targetChannelID:oldSpec.targetChannelID targetMessageDisplayDate:oldSpec.targetMessageDate];
                NSLog(@"replaced action message spec; action message id %@ ---> %@ (target message id %@)", oldSpec.actionMessageID, newActionMessageID, oldSpec.targetMessageID);
            } else {
                NSLog(@"No action message spec to update for action message with id %@", actionMessageID);
            }
        }
        
        [self.messageManager sendUnsentMessagesSentNotificationForChannelID:channelID sentMessageIDs:sentMessageIDs replacementMessageIDs:replacementMessageIDs];
    }
}

#pragma mark - Private

- (NSArray *)targetMessagePlussesForActionMessages:(NSArray *)actionMessages actionChannelId:(NSString *)actionChannelId {
    NSSet *targetMessageIDs = [self targetMessageIDsForMessagePlusses:actionMessages];
    NSOrderedDictionary *targetMessages = [self.messageManager persistedMessagesWithMessageIDs:targetMessageIDs];
    return [targetMessages allObjects];
}

- (NSSet *)targetMessageIDsForMessagePlusses:(NSArray *)messagePlusses {
    NSMutableSet *targetMessageIDs = [NSMutableSet setWithCapacity:messagePlusses.count];
    for(AATTMessagePlus *mp in messagePlusses) {
        [targetMessageIDs addObject:[mp.message targetMessageID]];
    }
    return targetMessageIDs;
}

- (NSString *)targetChannelIDForActionChannelWithID:(NSString *)actionChannelID {
    ANKChannel *actionChannel = [self.actionChannels objectForKey:actionChannelID];
    return actionChannel.targetChannelID;
}

- (void)processNewActionMessages:(NSArray *)actionMessages {
    NSMutableDictionary *targetMessageIDToActionMessage = [NSMutableDictionary dictionaryWithCapacity:actionMessages.count];
    
    for(AATTMessagePlus *messagePlus in actionMessages) {
        NSString *targetMessageID = messagePlus.message.targetMessageID;
        if(targetMessageID) {
            [targetMessageIDToActionMessage setObject:messagePlus forKey:targetMessageID];
        } else {
            NSLog(@"action message %@ is missing target message metadata!", messagePlus.message.messageID);
        }
    }
    
    NSSet *keySet = [NSSet setWithArray:targetMessageIDToActionMessage.allKeys];
    NSOrderedDictionary *targetMessages = [self.messageManager persistedMessagesWithMessageIDs:keySet];
    for(AATTMessagePlus *targetMessage in targetMessages.allObjects) {
        NSString *targetMessageID = targetMessage.message.messageID;
        NSString *targetChannelID = targetMessage.message.channelID;
        AATTMessagePlus *actionMessage = [targetMessageIDToActionMessage objectForKey:targetMessageID];
        NSDate *targetMessageDisplayDate = targetMessage.displayDate;
        [self.database insertOrReplaceActionMessageSpec:actionMessage targetMessageID:targetMessageID targetChannelID:targetChannelID targetMessageDisplayDate:targetMessageDisplayDate];
    }
}

@end
