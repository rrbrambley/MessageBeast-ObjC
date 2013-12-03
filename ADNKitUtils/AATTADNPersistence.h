//
//  AATTADNPersistence.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 12/3/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AATTADNPersistence : NSObject

+ (void)saveChannel:(ANKChannel *)channel;
+ (ANKChannel *)channelWithType:(NSString *)channelType;

+ (void)saveActionChannel:(ANKChannel *)channel actionType:(NSString *)actionType targetChannelID:(NSString *)targetChannelID;
+ (ANKChannel *)channelWithActionType:(NSString *)actionType targetChannelID:(NSString *)targetChannelID;

@end
