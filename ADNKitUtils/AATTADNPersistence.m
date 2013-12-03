//
//  AATTADNPersistence.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 12/3/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTADNPersistence.h"
#import "NSObject+AATTPersistence.h"

@implementation AATTADNPersistence

+ (void)saveChannel:(ANKChannel *)channel {
    [self saveCodingObject:channel forKey:[NSString stringWithFormat:@"channel_%@", channel.type]];
}

+ (ANKChannel *)channelWithType:(NSString *)channelType {
    return (ANKChannel *)[self codingObjectForKey:[NSString stringWithFormat:@"channel_%@", channelType]];
}

+ (void)saveActionChannel:(ANKChannel *)channel actionType:(NSString *)actionType targetChannelID:(NSString *)targetChannelID {
    [self saveCodingObject:channel forKey:[NSString stringWithFormat:@"actionChannel_%@_%@", actionType, targetChannelID]];
}

+ (ANKChannel *)channelWithActionType:(NSString *)actionType targetChannelID:(NSString *)targetChannelID {
    return (ANKChannel *)[self codingObjectForKey:[NSString stringWithFormat:@"actionChannel_%@_%@", actionType, targetChannelID]];
}

@end
