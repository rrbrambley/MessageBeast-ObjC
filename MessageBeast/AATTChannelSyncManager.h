//
//  AATTChannelSyncManager.h
//  MessageBeast
//
//  Created by Rob Brambley on 12/23/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AATTChannelRefreshResultSet, AATTChannelSpec, AATTTargetWithActionChannelsSpecSet;

/**
 AATTChannelSyncManager simplifies the syncing of several channels simultaneously.

 This manager is especially useful when one or more Action Channels are being synced
 for a "target" Channel. For example, a journaling app may choose to have a target Channel
 for journal entries that are accompanied by "favorite entries" and "locked entries" Action Channels –
 enabling users to mark entries as favorite entries, and locked entries, respectively. In this scenario,
 pulling the newest Messages from the server requires performing three requests; this class
 can be used to perform the three requests in one method call, with one callback.

 AATTChannelSyncManager can also perform full syncs on multiple channels with one method call.

 To use the functionality in ChannelSyncManager, it is important to first call
 initChannelsWithCompletionBlock: after instantiating it with your channel specs.
 */
@interface AATTChannelSyncManager : NSObject

@property AATTMessageManager *messageManager;
@property AATTActionMessageManager *actionMessageManager;

@property ANKChannel *targetChannel;
@property NSDictionary *actionChannels;

@property NSMutableDictionary *channels;

typedef void (^AATTChannelSyncManagerChannelInitializedBlock)(ANKChannel *channel, NSError *error);
typedef void (^AATTChannelSyncManagerChannelsInitializedBlock)(NSError *error);
typedef void (^AATTChannelSyncManagerSyncCompletionBlock)(NSError *error);
typedef void (^AATTChannelSyncManagerChannelRefreshCompletionBlock)(AATTChannelRefreshResultSet *resultSet);

/**
 Create an AATTChannelSyncManager. This initializer is convenient for use cases where you don't
 plan on creating an AATTMessageManager for use outside of this object.
 
 @param client the ANKClient used to make requests. This will be used to construct an AATTMessageManager.
 @param messageManagerConfiguration the AATTMessageManagerConfiguration to be used to construct the AATTMessageManager
 @param channelSpecSet the AATTChannelSpecSet describing the Channels to be used with AATTChannelSyncManager
 */
- (id)initWithClient:(ANKClient *)client messageManagerConfiguration:(AATTMessageManagerConfiguration *)messageManagerConfiguration channelSpecSet:(AATTChannelSpecSet *)channelSpecSet;

/**
 Create an AATTChannelSyncManager to be used with a Channel and a set of Action Channels.
 This initializer creates an AATTMessageManager and AATTActionMessageManager; it is convenient
 for use cases where you don't plan on creating these for use outside this object.
 
 @param client the ANKClient used to make requests. This will be used to construct an AATTMessageManager.
 @param messageManagerConfiguration the AATTMessageManagerConfiguration to be used to construct the AATTMessageManager
 @param targetWithActionChannelSpecSet the AATTTargetWithActionChannelsSpecSet describing the Channels
 to be used with AATTChannelSyncManager
 */
- (id)initWithClient:(ANKClient *)client messageManagerConfiguration:(AATTMessageManagerConfiguration *)messageManagerConfiguration targetWithActionChannelSpecSet:(AATTTargetWithActionChannelsSpecSet *)targetWithActionChannelSpecSet;

/**
 Create an AATTChannelSyncManager for a set of Channels.
 
 Note that this constructor is not for use with Action Channels.

 @param messageManager An instance of AATTMessageManager to be used for syncing the Channels.
 @param channelSpecSet The AATTChannelSpecSet describing the Channels to be used with AATTChannelSyncManager
 */
- (id)initWithMessageManager:(AATTMessageManager *)messageManager channelSpecSet:(AATTChannelSpecSet *)channelSpecSet;

/**
 Create an AATTChannelSyncManager to be used with a Channel and a set of Action Channels.
 
 @param actionMessageManager An instance of AATTActionMessageManager.
 @param channelSpecSet The AATTTargetWithActionChannelsSpecSet describing the Channels to be used with AATTChannelSyncManager
 */
- (id)initWithActionMessageManager:(AATTActionMessageManager *)actionMessageManager targetWithActionChannelsSpecSet:(AATTTargetWithActionChannelsSpecSet *)targetWithActionChannelsSpecSet;

#pragma mark - Initialize Channels

/**
 Initialize the Channels described by the spec(s) passed when initializing this class.
 
 This method must be called before any operations can be performed with AATTChannelSyncManager
 
 @param block the AATTChannelSyncManagerChannelsInitializedBlock
 */
- (void)initChannelsWithCompletionBlock:(AATTChannelSyncManagerChannelsInitializedBlock)block;

#pragma mark - Full Sync

/**
 Check the full sync status for the Channels associated with this manager and begin syncing if
 all Channels do not already have an AATTFullSyncState of AATTFullSyncStateComplete.
 
 @param startBlock a block that is executed when a full sync is started
 @param completionBlock a block that is executed when the full sync has completed
 */
- (void)checkFullSyncStatusWithStartBlock:(void (^)(void))startBlock completionBlock:(AATTChannelSyncManagerSyncCompletionBlock)completionBlock;

/**
 Check the full sync status for the Channels associated with this manager.
 
 If the parameter resumeSync is NO, then you should use the syncIncompleteBlock to handle a AATTChannelFullSyncStateStarted
 (e.g. show a dialog "would you like to resume syncing these channels?").
 
 @param resumeSync YES if sync should resume if previously started but not finished, NO otherwise
 @param syncStartBlock a block that is executed when a full sync is started
 @param completionBlock a block that is executed when the full sync has completed
 @param syncIncompleteBlock a block that will be executed if resumeSync is NO and
        a sync was previously started but not finished.
 */
- (void)checkFullSyncStatusAndResumeSyncIfPreviouslyStarted:(BOOL)resumeSync syncStartBlock:(void (^)(void))syncStartBlock completionBlock:(AATTChannelSyncManagerSyncCompletionBlock)completionBlock syncIncompleteBlock:(void (^)(void))syncIncompleteBlock;

/**
 Start a full sync on the Channels associated with this manager.
 
 @param completionBlock a AATTChannelSyncManagerSyncCompletionBlock
 */
- (void)startFullSyncWithCompletionBlock:(AATTChannelSyncManagerSyncCompletionBlock)completionBlock;

#pragma mark - Fetch Messages

/**
 Fetch the newest Messages in all Channels associated with this manager.
 
 @param block a AATTChannelSyncManagerChannelRefreshCompletionBlock
 */
- (void)fetchNewestMessagesWithCompletionBlock:(AATTChannelSyncManagerChannelRefreshCompletionBlock)block;

#pragma mark - Delete Messages

/*
 Delete an AATTMessagePlus and any Action Messages associated with it.
 
 If the provided AATTMessagePlus has files associated with it, they will
 not be deleted by this method.
 
 @param messagePlus the target AATTMessagePlus to be deleted.
 */
- (void)deleteMessagePlusAndAssociatedActionMessages:(AATTMessagePlus *)messagePlus;

/*
 Delete an AATTMessagePlus and any Action Messages associated with it.
 
 @param messagePlus the target AATTMessagePlus to be deleted.
 @param deleteAssociatedFiles YES if the target AATTMessagePlus' associated files should
 be deleted, false otherwise.
 */
- (void)deleteMessagePlusAndAssociatedActionMessages:(AATTMessagePlus *)messagePlus deleteAssociatedFiles:(BOOL)deleteAssociatedFiles;

/*
 Delete an AATTMessagePlus and any Action Messages associated with it.
 
 The completion block is used to indicate the completion of the target AATTMessagePlus
 deletion, i.e., the action messages are not guaranteed to be deleted before the
 block is executed.
 
 @param messagePlus the target AATTMessagePlus to be deleted.
 @param deleteAssociatedFiles YES if the target AATTMessagePlus' associated files should
        be deleted, false otherwise.
 @param block the completion block. Can be nil.
 */
- (void)deleteMessagePlusAndAssociatedActionMessages:(AATTMessagePlus *)messagePlus deleteAssociatedFiles:(BOOL)deleteAssociatedFiles completionBlock:(AATTMessageManagerDeletionCompletionBlock)block;

@end
