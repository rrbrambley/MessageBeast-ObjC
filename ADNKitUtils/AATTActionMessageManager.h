//
//  AATTActionMessageManager.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 12/1/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AATTMessageManager.h"

/**
 The AATTActionMessageManager is used to perform mutable actions on Messages.

 Since Annotations are not mutable, user-invoked actions on individual Messages (e.g.
 marking a Message as a favorite, as read/unread, etc.) are not manageable with the App.net API.
 This Manager class is used to hack around this limitation.

 We use Action Channels (Channels of type com.alwaysallthetime.action)
 with machine-only Messages to perform Actions on another Channel's Messages. These Action Messages
 have metadata annotations (type com.alwaysallthetime.action.metadata) that point to their associated
 "target" message in another Channel. All Messages in an Action Channel correspond to the same
 action (i.e. there is only one action per Action Channel). Since Messages can be deleted, deleting
 an Action Message effectively undoes a performed Action on the target Message.

 The ActionMessageManager abstracts away this hack by providing simple applyActionForActionChannelWithID:toTargetMessagePlus:
 and removeActionForActionChannelWithID:fromTargetMessageWithID: methods. Before performing either of these actions, you must call
 initActionChannelWithType:targetChannel:completionBlock: to create or get an existing Channel to host the Action Messages.
 To check if an action has been performed on a specific target message, use isActionedTargetMessageID:inActionChannelWithID:
 */
@interface AATTActionMessageManager : NSObject

typedef void (^AATTActionMessageManagerChannelInitBlock)(ANKChannel *actionChannel, NSError *error);

+ (AATTActionMessageManager *)sharedInstanceWithMessageManager:(AATTMessageManager *)messageManager;

#pragma mark - Action Channel

/*
 Initialize an Action Channel. This is typically done at app startup and must be done before any other
 AATTActionMessageManager methods are used on the Channel.
 
 @param actionType the identifier for the Action Channel (e.g. com.alwaysallthetime.pizzaparty)
 @param targetChannel the Channel whose messages will have actions performed.
 @param completionBlock AATTActionMessageManagerChannelInitBlock
 */
- (void)initActionChannelWithType:(NSString *)actionType targetChannel:(ANKChannel *)targetChannel completionBlock:(AATTActionMessageManagerChannelInitBlock)completionBlock;

#pragma mark - Lookup

/*
 Return YES if the specified target Message has had an action performed on it.
 
 @param targetMessageID the id of the target Message.
 @param actionChannelID the id of the Action Channel.
 */
- (BOOL)isActionedTargetMessageID:(NSString *)targetMessageID inActionChannelWithID:(NSString *)actionChannelID;

#pragma mark - Other Getters

/*
 Get the AATTMessageManager instance used by this manager.
 */
- (AATTMessageManager *)messageManager;

#pragma mark - Retrieval

/*
 Sync and persist all Action Messages in a Channel.
 
 Instead of using the similar MessageManager method, this method should be used
 to sync messages for an Action Channel. As batches of Messages are obtained, the target Message id
 for each Action Message will be extracted from annotations and stored to the sqlite database
 for lookup at a later time.
 
 @param actionChannelID The id of the Action Channel for which Messages will be synced
 @param targetChannelID The id of the target Channel
 @param completionBlock AATTMessageManagerCompletionBlock
 */
- (void)fetchAndPersistAllMessagesInActionChannelWithID:(NSString *)actionChannelID targetChannelID:(NSString *)targetChannelID completionBlock:(AATTMessageManagerCompletionBlock)completionBlock;

/*
 Fetch the newest messages in an Action Channel.
 
 @param actionChannelID the id of the Action Channel for which Messages should be fetched
 @param targetChannelID the id of the target Channel associated with the Action Channel
 @param completionBlock the AATTMessageManagerCompletionBlock
 @return NO if unsent messages are preventing new messages from being fetched, YES otherwise. If NO is returned, you should
         use the MessageManager to send all unsent messages in the specified Action Channel.
 */
- (BOOL)fetchNewestMessagesInActionChannelWithID:(NSString *)actionChannelID targetChannelID:(NSString *)targetChannelID completionBlock:(AATTMessageManagerCompletionBlock)completionBlock;

#pragma mark - Apply/Remove Actions

/*
 Apply the action associated with an Action Channel to the provided target Message.
 
 This creates a machine-only Message in the Action Channel that points to the target Message.
 
 @param actionChannelID the id of the Action Channel
 @param messagePlus the AATTMessagePlus with which to associate this action.
 */
- (void)applyActionForActionChannelWithID:(NSString *)actionChannelID toTargetMessagePlus:(AATTMessagePlus *)messagePlus;

/*
 Remove the action associated with an Action Channel from the Message associated with the provided target Message id.
 
 @param actionChannelID the id of the Action Channel
 @param targetMessageID the id of the target Message to which the action should no longer be applied
 */
- (void)removeActionForActionChannelWithID:(NSString *)actionChannelID fromTargetMessageWithID:(NSString *)targetMessageID;

@end
