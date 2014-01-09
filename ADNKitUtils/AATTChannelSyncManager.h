//
//  AATTChannelSyncManager.h
//  ADNKitUtils
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

@property ANKChannel *targetChannel;
@property NSDictionary *actionChannels;

@property NSMutableDictionary *channels;

typedef void (^AATTChannelSyncManagerChannelInitializedBlock)(ANKChannel *channel, NSError *error);
typedef void (^AATTChannelSyncManagerChannelsInitializedBlock)(NSError *error);
typedef void (^AATTChannelSyncManagerSyncCompletionBlock)(NSError *error);
typedef void (^AATTChannelSyncManagerChannelRefreshCompletionBlock)(AATTChannelRefreshResultSet *resultSet);

- (id)initWithMessageManager:(AATTMessageManager *)messageManager channelSpecSet:(AATTChannelSpecSet *)channelSpecSet;

- (id)initWithActionMessageManager:(AATTActionMessageManager *)actionMessageManager targetWithActionChannelsSpecSet:(AATTTargetWithActionChannelsSpecSet *)targetWithActionChannelsSpecSet;

#pragma mark - Initialize Channels

- (void)initChannelsWithCompletionBlock:(AATTChannelSyncManagerChannelsInitializedBlock)block;

#pragma mark - Full Sync

- (void)checkFullSyncStatusWithStartBlock:(void (^)(void))startBlock completionBlock:(AATTChannelSyncManagerSyncCompletionBlock)completionBlock;

- (void)checkFullSyncStatusAndResumeSyncIfPreviouslyStarted:(BOOL)resumeSync syncStartBlock:(void (^)(void))syncStartBlock completionBlock:(AATTChannelSyncManagerSyncCompletionBlock)completionBlock syncIncompleteBlock:(void (^)(void))syncIncompleteBlock;

- (void)startFullSyncWithCompletionBlock:(AATTChannelSyncManagerSyncCompletionBlock)completionBlock;

#pragma mark - Fetch Messages

- (void)fetchNewestMessagesWithCompletionBlock:(AATTChannelSyncManagerChannelRefreshCompletionBlock)block;

@end
