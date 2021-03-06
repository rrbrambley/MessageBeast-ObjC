//
//  AATTChannelSyncManager.m
//  MessageBeast
//
//  Created by Rob Brambley on 12/23/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTActionMessageManager.h"
#import "AATTActionMessageSpec.h"
#import "AATTChannelSpec.h"
#import "AATTChannelSpecSet.h"
#import "AATTChannelSyncManager.h"
#import "AATTChannelRefreshResult.h"
#import "AATTChannelRefreshResultSet.h"
#import "AATTMessageManager.h"
#import "AATTMessagePlus.h"
#import "AATTOrderedMessageBatch.h"
#import "AATTTargetWithActionChannelsSpecSet.h"
#import "ANKClient+PrivateChannel.h"

@interface AATTChannelSyncManager ()
@property AATTChannelSpecSet *channelSpecSet;
@property AATTTargetWithActionChannelsSpecSet *targetWithActionChannelsSpecSet;
@end

@implementation AATTChannelSyncManager

- (id)initWithClient:(ANKClient *)client messageManagerConfiguration:(AATTMessageManagerConfiguration *)messageManagerConfiguration channelSpecSet:(AATTChannelSpecSet *)channelSpecSet {
    self = [super init];
    if(self) {
        self.messageManager = [[AATTMessageManager alloc] initWithANKClient:client configuration:messageManagerConfiguration];
        self.channelSpecSet = channelSpecSet;
    }
    return self;
}

- (id)initWithClient:(ANKClient *)client messageManagerConfiguration:(AATTMessageManagerConfiguration *)messageManagerConfiguration targetWithActionChannelSpecSet:(AATTTargetWithActionChannelsSpecSet *)targetWithActionChannelSpecSet {
    self = [super init];
    if(self) {
        self.messageManager = [[AATTMessageManager alloc] initWithANKClient:client configuration:messageManagerConfiguration];
        self.actionMessageManager = [AATTActionMessageManager sharedInstanceWithMessageManager:self.messageManager];
        self.targetWithActionChannelsSpecSet = targetWithActionChannelSpecSet;
    }
    return self;
}

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
        [self initChannelAtIndex:0 completionBlock:block];
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
        BOOL canFetch = [self.messageManager fetchNewestMessagesInChannelWithID:self.targetChannel.channelID completionBlock:^(NSArray *messagePlusses, ANKAPIResponseMeta *meta, NSError *error) {
            if(!error) {
                AATTChannelRefreshResult *refreshResult = [[AATTChannelRefreshResult alloc] initWithChannel:self.targetChannel messagePlusses:messagePlusses];
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
        [self fetchNewestMessagesForChannelAtIndex:0 refreshCompletionBlock:block refreshResultSet:[[AATTChannelRefreshResultSet alloc] init]];
    }
}

#pragma mark - Delete Messages

- (void)deleteMessagePlusAndAssociatedActionMessages:(AATTMessagePlus *)messagePlus {
    [self deleteMessagePlusAndAssociatedActionMessages:messagePlus deleteAssociatedFiles:NO];
}

- (void)deleteMessagePlusAndAssociatedActionMessages:(AATTMessagePlus *)messagePlus deleteAssociatedFiles:(BOOL)deleteAssociatedFiles {
    [self deleteMessagePlusAndAssociatedActionMessages:messagePlus deleteAssociatedFiles:NO completionBlock:nil];
}

- (void)deleteMessagePlusAndAssociatedActionMessages:(AATTMessagePlus *)messagePlus deleteAssociatedFiles:(BOOL)deleteAssociatedFiles completionBlock:(AATTMessageManagerDeletionCompletionBlock)block {
    AATTADNDatabase *db = [AATTADNDatabase sharedInstance];
    NSArray *actionMessageSpecs = [db actionMessageSpecsForTargetMessagesWithIDs:@[messagePlus.message.messageID]];
    
    if(actionMessageSpecs.count) {
        NSMutableSet *actionMessageIDs = [NSMutableSet setWithCapacity:actionMessageSpecs.count];
        for(AATTActionMessageSpec *spec in actionMessageSpecs) {
            [actionMessageIDs addObject:spec.actionMessageID];
        }
        
        AATTOrderedMessageBatch *actionMessageBatch = [db messagesWithIDs:actionMessageIDs];
        M13OrderedDictionary *actionMessages = actionMessageBatch.messagePlusses;
        for(AATTMessagePlus *mp in [actionMessages allObjects]) {
            [self.messageManager deleteMessage:mp completionBlock:nil];
        }
    }
    [self.messageManager deleteMessage:messagePlus deleteAssociatedFiles:deleteAssociatedFiles completionBlock:block];
}

#pragma mark - Private

- (void)fetchNewestMessagesForChannelAtIndex:(NSUInteger)index refreshCompletionBlock:(AATTChannelSyncManagerChannelRefreshCompletionBlock)refreshCompletionBlock refreshResultSet:(AATTChannelRefreshResultSet *)refreshResultSet {
    if(index >= self.channelSpecSet.count) {
        refreshCompletionBlock(refreshResultSet);
    } else {
        ANKChannel *channel = [self.channels objectForKey:[self.channelSpecSet channelSpecAtIndex:index]];
        BOOL canFetch = [self.messageManager fetchNewestMessagesInChannelWithID:channel.channelID completionBlock:^(NSArray *messagePlusses, ANKAPIResponseMeta *meta, NSError *error) {
            if(!error) {
                AATTChannelRefreshResult *refreshResult = [[AATTChannelRefreshResult alloc] initWithChannel:channel messagePlusses:messagePlusses];
                [refreshResultSet addRefreshResult:refreshResult];
                [self fetchNewestMessagesForChannelAtIndex:(index+1) refreshCompletionBlock:refreshCompletionBlock refreshResultSet:refreshResultSet];
            } else {
                AATTChannelRefreshResult *refreshResult = [[AATTChannelRefreshResult alloc] initWithChannel:channel error:error];
                [refreshResultSet addRefreshResult:refreshResult];
                [self fetchNewestMessagesForChannelAtIndex:(index+1) refreshCompletionBlock:refreshCompletionBlock refreshResultSet:refreshResultSet];
            }
        }];
        
        if(!canFetch) {
            [refreshResultSet addRefreshResult:[[AATTChannelRefreshResult alloc] init]];
            [self fetchNewestMessagesForChannelAtIndex:(index+1) refreshCompletionBlock:refreshCompletionBlock refreshResultSet:refreshResultSet];
        }
    }
}

- (void)fetchNewestActionChannelMessagesForChannelAtIndex:(NSUInteger)index refreshCompletionBlock:(AATTChannelSyncManagerChannelRefreshCompletionBlock)refreshCompletionBlock refreshResultSet:(AATTChannelRefreshResultSet *)refreshResultSet {
    if(index >= self.targetWithActionChannelsSpecSet.actionChannelCount) {
        refreshCompletionBlock(refreshResultSet);
    } else {
        ANKChannel *actionChannel = [self.actionChannels objectForKey:[self.targetWithActionChannelsSpecSet actionChannelActionTypeAtIndex:index]];
        BOOL canFetch = [self.actionMessageManager fetchNewestMessagesInActionChannelWithID:actionChannel.channelID completionBlock:^(NSArray *messagePlusses, ANKAPIResponseMeta *meta, NSError *error) {
            if(!error) {
                AATTChannelRefreshResult *refreshResult = [[AATTChannelRefreshResult alloc] initWithChannel:actionChannel messagePlusses:messagePlusses];
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

- (void)initChannelAtIndex:(NSUInteger)index completionBlock:(AATTChannelSyncManagerChannelsInitializedBlock)block {
    if(index >= self.channelSpecSet.count) {
        block(nil);
    } else {
        AATTChannelSpec *spec = [self.channelSpecSet channelSpecAtIndex:index];
        [self initChannelWithSpec:spec completionBlock:^(ANKChannel *channel, NSError *error) {
            if(!error) {
                [self.channels setObject:channel forKey:channel.channelID];
                [self initChannelAtIndex:(index+1) completionBlock:block];
            } else {
                block(error);
            }
        }];
    }
}

- (void)initActionChannelAtIndex:(NSUInteger)index actionChannels:(NSMutableDictionary *)actionChannels completionBlock:(AATTChannelSyncManagerChannelsInitializedBlock)block {
    if(index >= self.targetWithActionChannelsSpecSet.actionChannelCount) {
        self.actionChannels = actionChannels;
        block(nil);
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