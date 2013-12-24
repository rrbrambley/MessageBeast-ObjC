//
//  AATTChannelSyncManager.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 12/23/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AATTChannelSpec;

@interface AATTChannelSyncManager : NSObject

@property ANKChannel *targetChannel;
@property NSDictionary *actionChannels;

typedef void (^AATTChannelSyncManagerChannelsInitializedBlock)(NSError *error);

typedef void (^AATTChannelSyncManagerSyncCompletionBlock)(NSError *error);

- (id)initWithActionMessageManager:(AATTActionMessageManager *)actionMessageManager targetChannelSpec:(AATTChannelSpec *)channelSpec actionChannelActionTypes:(NSArray *)actionTypes;

#pragma mark - Full Sync

- (void)checkFullSyncStatusWithStartBlock:(void (^)(void))startBlock completionBlock:(AATTChannelSyncManagerSyncCompletionBlock)completionBlock;

- (void)checkFullSyncStatusAndResumeSyncIfPreviouslyStarted:(BOOL)resumeSync syncStartBlock:(void (^)(void))syncStartBlock completionBlock:(AATTChannelSyncManagerSyncCompletionBlock)completionBlock syncIncompleteBlock:(void (^)(void))syncIncompleteBlock;

- (void)startFullSyncWithCompletionBlock:(AATTChannelSyncManagerSyncCompletionBlock)completionBlock;

#pragma mark - Initialize Channels

- (void)initChannelsWithCompletionBlock:(AATTChannelSyncManagerChannelsInitializedBlock)block;

@end
