//
//  AATTChannelSyncManager.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 12/23/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTActionMessageManager.h"
#import "AATTChannelSpec.h"
#import "AATTChannelSpecSet.h"
#import "AATTChannelSyncManager.h"
#import "AATTChannelRefreshResult.h"
#import "AATTChannelRefreshResultSet.h"
#import "AATTMessageManager.h"
#import "AATTTargetWithActionChannelsSpecSet.h"
#import "ANKClient+PrivateChannel.h"

@interface AATTChannelSyncManager ()

@property AATTMessageManager *messageManager;
@property AATTChannelSpecSet *channelSpecSet;

@property AATTActionMessageManager *actionMessageManager;
@property AATTTargetWithActionChannelsSpecSet *targetWithActionChannelsSpecSet;

@end

@implementation AATTChannelSyncManager

- (id)initWithMessageManager:(AATTMessageManager *)messageManager channelSpecSet:(AATTChannelSpecSet *)channelSpecSet {
    self = [super init];
    if(self) {
        self.messageManager = messageManager;
        self.channelSpecSet = channelSpecSet;
    }
    return self;
}

- (id)initWithActionMessageManager:(AATTActionMessageManager *)actionMessageManager targetWithActionChannelsSpecSet:(AATTTargetWithActionChannelsSpecSet *)targetWithActionChannelsSpecSet {
    self = [super init];
    if(self) {
        self.actionMessageManager = actionMessageManager;
        self.messageManager = actionMessageManager.messageManager;
        self.targetWithActionChannelsSpecSet = targetWithActionChannelsSpecSet;
    }
    return self;
}

#pragma mark - Initialize Channels

- (void)initChannelsWithCompletionBlock:(AATTChannelSyncManagerChannelsInitializedBlock)block {
    if(self.targetWithActionChannelsSpecSet) {
        NSMutableDictionary *actionChannels = [NSMutableDictionary dictionaryWithCapacity:self.targetWithActionChannelsSpecSet.actionChannelCount];
        [self initChannelWithSpec:self.targetWithActionChannelsSpecSet.targetChannelSpec completionBlock:^(ANKChannel *channel, NSError *error) {
            if(channel) {
                self.targetChannel = channel;
                [self initActionChannelAtIndex:0 actionChannels:actionChannels completionBlock:block];
            } else {
                block(error);
            }
        }];
    } else {
        self.channels = [NSMutableDictionary dictionaryWithCapacity:self.channelSpecSet.count];
        //TODO
    }
}

#pragma mark - Full Sync

- (void)checkFullSyncStatusWithStartBlock:(void (^)(void))startBlock completionBlock:(AATTChannelSyncManagerSyncCompletionBlock)completionBlock {
    [self checkFullSyncStatusAndResumeSyncIfPreviouslyStarted:YES syncStartBlock:startBlock completionBlock:completionBlock syncIncompleteBlock:nil];
}

- (void)checkFullSyncStatusAndResumeSyncIfPreviouslyStarted:(BOOL)resumeSync syncStartBlock:(void (^)(void))syncStartBlock completionBlock:(AATTChannelSyncManagerSyncCompletionBlock)completionBlock syncIncompleteBlock:(void (^)(void))syncIncompleteBlock {
    AATTChannelFullSyncState state = [self.messageManager fullSyncStateForChannels:[self channelsArray]];
    if(state == AATTChannelFullSyncStateComplete) {
        completionBlock(nil);
    } else if(state == AATTChannelFullSyncStateNotStarted) {
        [self startFullSyncWithCompletionBlock:completionBlock];
        syncStartBlock();
    } else {
        if(resumeSync) {
            [self startFullSyncWithCompletionBlock:completionBlock];
            syncStartBlock();
        } else if(syncIncompleteBlock) {
            syncIncompleteBlock();
        }
    }
}

- (void)startFullSyncWithCompletionBlock:(AATTChannelSyncManagerSyncCompletionBlock)completionBlock {
    [self.messageManager fetchAndPersistAllMessagesInChannels:[self channelsArray] completionBlock:^(BOOL success, NSError *error) {
        if(error) {
            NSLog(@"Could not finish sync; %@", error.description);
        }
        completionBlock(nil);
    }];
}

#pragma mark - Fetch Messages

- (void)fetchNewestMessagesWithCompletionBlock:(AATTChannelSyncManagerChannelRefreshCompletionBlock)block {
    if(self.targetWithActionChannelsSpecSet) {
        AATTChannelRefreshResultSet *resultSet = [[AATTChannelRefreshResultSet alloc] init];
        BOOL canFetch = [self.messageManager fetchNewestMessagesInChannelWithID:self.targetChannel.channelID completionBlock:^(NSArray *messagePlusses, BOOL appended, ANKAPIResponseMeta *meta, NSError *error) {
            if(!error) {
                AATTChannelRefreshResult *refreshResult = [[AATTChannelRefreshResult alloc] initWithChannel:self.targetChannel messagePlusses:messagePlusses appended:appended];
                [resultSet addRefreshResult:refreshResult];
                [self fetchNewestActionChannelMessagesForChannelAtIndex:0 refreshCompletionBlock:block refreshResultSet:resultSet];
            } else {
                AATTChannelRefreshResult *refreshResult = [[AATTChannelRefreshResult alloc] initWithChannel:self.targetChannel error:error];
                [resultSet addRefreshResult:refreshResult];
                [self fetchNewestActionChannelMessagesForChannelAtIndex:0 refreshCompletionBlock:block refreshResultSet:resultSet];
            }
        }];
        
        if(!canFetch) {
            [resultSet addRefreshResult:[[AATTChannelRefreshResult alloc] initWithChannel:self.targetChannel]];
            [self fetchNewestActionChannelMessagesForChannelAtIndex:0 refreshCompletionBlock:block refreshResultSet:resultSet];
        }
    } else {
        //TODO
    }
}

#pragma mark - Private

- (void)fetchNewestActionChannelMessagesForChannelAtIndex:(NSUInteger)index refreshCompletionBlock:(AATTChannelSyncManagerChannelRefreshCompletionBlock)refreshCompletionBlock refreshResultSet:(AATTChannelRefreshResultSet *)refreshResultSet {
    if(index >= self.targetWithActionChannelsSpecSet.actionChannelCount) {
        refreshCompletionBlock(refreshResultSet);
    } else {
        ANKChannel *actionChannel = [self.actionChannels objectForKey:[self.targetWithActionChannelsSpecSet actionChannelActionTypeAtIndex:index]];
        BOOL canFetch = [self.actionMessageManager fetchNewestMessagesInActionChannelWithID:actionChannel.channelID targetChannelID:self.targetChannel.channelID completionBlock:^(NSArray *messagePlusses, BOOL appended, ANKAPIResponseMeta *meta, NSError *error) {
            if(!error) {
                AATTChannelRefreshResult *refreshResult = [[AATTChannelRefreshResult alloc] initWithChannel:actionChannel messagePlusses:messagePlusses appended:appended];
                [refreshResultSet addRefreshResult:refreshResult];
                [self fetchNewestActionChannelMessagesForChannelAtIndex:(index+1) refreshCompletionBlock:refreshCompletionBlock refreshResultSet:refreshResultSet];
            } else {
                AATTChannelRefreshResult *refreshResult = [[AATTChannelRefreshResult alloc] initWithChannel:actionChannel error:error];
                [refreshResultSet addRefreshResult:refreshResult];
                [self fetchNewestActionChannelMessagesForChannelAtIndex:(index+1) refreshCompletionBlock:refreshCompletionBlock refreshResultSet:refreshResultSet];
            }
        }];
        
        if(!canFetch) {
            [refreshResultSet addRefreshResult:[[AATTChannelRefreshResult alloc] initWithChannel:actionChannel]];
            [self fetchNewestActionChannelMessagesForChannelAtIndex:(index+1) refreshCompletionBlock:refreshCompletionBlock refreshResultSet:refreshResultSet];
        }
    }
}

- (void)initChannelWithSpec:(AATTChannelSpec *)channelSpec completionBlock:(AATTChannelSyncManagerChannelInitializedBlock)block {
    [self.messageManager.client getOrCreatePrivateChannelWithType:channelSpec.type completionBlock:^(ANKChannel *channel, NSError *error) {
        if(channel && !error) {
            self.targetChannel = channel;
            [self.messageManager setQueryParametersForChannelWithID:channel.channelID parameters:channelSpec.queryParameters];
        } else {
            NSLog(@"Couldn't get or create channel with type %@", channelSpec.type);
        }
        block(channel, error);
    }];
}

- (void)initActionChannelAtIndex:(NSUInteger)index actionChannels:(NSMutableDictionary *)actionChannels completionBlock:(AATTChannelSyncManagerChannelsInitializedBlock)block {
    if(index >= self.targetWithActionChannelsSpecSet.actionChannelCount) {
        self.actionChannels = actionChannels;
        block(nil);
        //TODO send notification?
    } else {
        NSString *actionType = [self.targetWithActionChannelsSpecSet actionChannelActionTypeAtIndex:index];
        [self initActionChannelWithActionType:actionType forTargetChannel:self.targetChannel actionChannels:actionChannels completionBlock:^(NSError *error) {
            if([actionChannels objectForKey:actionType]) {
                [self initActionChannelAtIndex:(index+1) actionChannels:actionChannels completionBlock:block];
            } else {
                block(error);
            }
        }];
    }
}

- (void)initActionChannelWithActionType:(NSString *)actionType forTargetChannel:(ANKChannel *)targetChannel actionChannels:(NSMutableDictionary *)actionChannels completionBlock:(void (^)(NSError *error))block {
    [self.actionMessageManager initActionChannelWithType:actionType targetChannel:targetChannel completionBlock:^(ANKChannel *actionChannel, NSError *error) {
        if(actionChannel) {
            [actionChannels setObject:actionChannel forKey:actionType];
        } else {
            NSLog(@"Could not init action channel with action type %@", actionType);
        }
        block(error);
    }];
}

- (NSArray *)channelsArray {
    NSMutableArray *channels = [NSMutableArray arrayWithCapacity:(self.targetChannel ? 1 : 0) + self.actionChannels.count];
    if(self.targetChannel) {
        [channels addObject:self.targetChannel];
    }
    [channels addObjectsFromArray:[self.actionChannels allValues]];
    return channels;
}

@end