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

- (id)initWithActionMessageManager:(AATTActionMessageManager *)actionMessageManager targetChannelSpec:(AATTChannelSpec *)channelSpec actionChannelActionTypes:(NSArray *)actionTypes;

- (void)initChannelsWithCompletionBlock:(AATTChannelSyncManagerChannelsInitializedBlock)block;

@end
