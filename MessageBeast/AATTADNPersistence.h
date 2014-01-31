//
//  AATTADNPersistence.h
//  MessageBeast
//
//  Created by Rob Brambley on 12/3/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AATTMessageManager.h"

@interface AATTADNPersistence : NSObject

+ (void)saveChannel:(ANKChannel *)channel;
+ (void)deleteChannel:(ANKChannel *)channel;
+ (ANKChannel *)channelWithType:(NSString *)channelType;

+ (void)saveActionChannel:(ANKChannel *)channel actionType:(NSString *)actionType targetChannelID:(NSString *)targetChannelID;

+ (ANKChannel *)channelWithActionType:(NSString *)actionType targetChannelID:(NSString *)targetChannelID;

+ (void)saveFullSyncState:(AATTChannelFullSyncState)fullSyncState channelID:(NSString *)channelID;
+ (AATTChannelFullSyncState)fullSyncStateForChannelWithID:(NSString *)channelID;

@end
