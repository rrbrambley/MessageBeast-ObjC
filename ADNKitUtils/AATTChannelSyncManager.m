//
//  AATTChannelSyncManager.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 12/23/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTActionMessageManager.h"
#import "AATTChannelSpec.h"
#import "AATTMessageManager.h"
#import "AATTChannelSyncManager.h"
#import "ANKClient+PrivateChannel.h"

@interface AATTChannelSyncManager ()
@property AATTMessageManager *messageManager;
@property AATTActionMessageManager *actionMessageManager;
@property AATTChannelSpec *targetChannelSpec;
@property NSArray *actionChannelTypes;
@end

@implementation AATTChannelSyncManager

- (id)initWithActionMessageManager:(AATTActionMessageManager *)actionMessageManager targetChannelSpec:(AATTChannelSpec *)channelSpec actionChannelActionTypes:(NSArray *)actionTypes {
    self = [super init];
    if(self) {
        self.actionMessageManager = actionMessageManager;
        self.messageManager = actionMessageManager.messageManager;
        self.targetChannelSpec = channelSpec;
        self.actionChannelTypes = actionTypes;
    }
    return self;
}

- (void)initChannelsWithCompletionBlock:(AATTChannelSyncManagerChannelsInitializedBlock)block {
    [self initChannelWithSpec:self.targetChannelSpec completionBlock:^{
        if(self.targetChannel) {
            [self initActionChannelAtIndex:0 actionChannels:[NSMutableDictionary dictionaryWithCapacity:self.actionChannelTypes.count] completionBlock:block];
        } else {
            //TODO
        }
    }];
}

#pragma mark - Private

- (void)initChannelWithSpec:(AATTChannelSpec *)channelSpec completionBlock:(void (^)(void))block {
    [self.messageManager.client getOrCreatePrivateChannelWithType:channelSpec.type completionBlock:^(ANKChannel *channel, NSError *error) {
        if(channel && !error) {
            self.targetChannel = channel;
            [self.messageManager setQueryParametersForChannelWithID:channel.channelID parameters:channelSpec.queryParameters];
        } else {
            NSLog(@"Couldn't get or create channel with type %@", channelSpec.type);
            block();
        }
        block();
    }];
}

- (void)initActionChannelAtIndex:(NSUInteger)index actionChannels:(NSMutableDictionary *)actionChannels completionBlock:(AATTChannelSyncManagerChannelsInitializedBlock)block {
    if(index >= self.actionChannelTypes.count) {
        self.actionChannels = actionChannels;
        block(nil);
        //TODO send notification?
    } else {
        NSString *actionType = [self.actionChannelTypes objectAtIndex:index];
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


@end