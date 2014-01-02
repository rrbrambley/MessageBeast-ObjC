//
//  AATTChannelSyncManager.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 12/23/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AATTChannelRefreshResultSet, AATTChannelSpec, AATTTargetWithActionChannelsSpecSet;

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

#pragma mark - Full Sync

- (void)checkFullSyncStatusWithStartBlock:(void (^)(void))startBlock completionBlock:(AATTChannelSyncManagerSyncCompletionBlock)completionBlock;

- (void)checkFullSyncStatusAndResumeSyncIfPreviouslyStarted:(BOOL)resumeSync syncStartBlock:(void (^)(void))syncStartBlock completionBlock:(AATTChannelSyncManagerSyncCompletionBlock)completionBlock syncIncompleteBlock:(void (^)(void))syncIncompleteBlock;

- (void)startFullSyncWithCompletionBlock:(AATTChannelSyncManagerSyncCompletionBlock)completionBlock;

#pragma mark - Initialize Channels

- (void)initChannelsWithCompletionBlock:(AATTChannelSyncManagerChannelsInitializedBlock)block;

#pragma mark - Fetch Messages

- (void)fetchNewestMessagesWithCompletionBlock:(AATTChannelSyncManagerChannelRefreshCompletionBlock)block;

@end
