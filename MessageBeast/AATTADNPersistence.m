//
//  AATTADNPersistence.m
//  MessageBeast
//
//  Created by Rob Brambley on 12/3/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTADNPersistence.h"
#import "ANKChannel+AATTAnnotationHelper.h"
#import "NSObject+AATTPersistence.h"

@implementation AATTADNPersistence

+ (void)saveChannel:(ANKChannel *)channel {
    [self saveCodingObject:channel forKey:[NSString stringWithFormat:@"channel_%@", channel.type]];
}

+ (ANKChannel *)channelWithType:(NSString *)channelType {
    return (ANKChannel *)[self codingObjectForKey:[NSString stringWithFormat:@"channel_%@", channelType]];
}

+ (void)deleteChannel:(ANKChannel *)channel {
    NSString *actionType = [channel actionChannelType];
    NSString *targetChannelID = [channel targetChannelID];
    
    NSString *key = nil;
    if(actionType && targetChannelID) {
        key = [NSString stringWithFormat:@"actionChannel_%@_%@", actionType, targetChannelID];
    } else {
        key = [NSString stringWithFormat:@"channel_%@", channel.type];
    }
    [self deleteCodingObjectForKey:key];
}

+ (void)saveActionChannel:(ANKChannel *)channel actionType:(NSString *)actionType targetChannelID:(NSString *)targetChannelID {
    [self saveCodingObject:channel forKey:[NSString stringWithFormat:@"actionChannel_%@_%@", actionType, targetChannelID]];
}

+ (ANKChannel *)channelWithActionType:(NSString *)actionType targetChannelID:(NSString *)targetChannelID {
    return (ANKChannel *)[self codingObjectForKey:[NSString stringWithFormat:@"actionChannel_%@_%@", actionType, targetChannelID]];
}

+ (void)saveFullSyncState:(AATTChannelFullSyncState)fullSyncState channelID:(NSString *)channelID {
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    if(standardUserDefaults) {
        [standardUserDefaults setInteger:fullSyncState forKey:[NSString stringWithFormat:@"syncState_%@", channelID]];
        [standardUserDefaults synchronize];
    }
}

+ (AATTChannelFullSyncState)fullSyncStateForChannelWithID:(NSString *)channelID {
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    if(standardUserDefaults) {
        return [standardUserDefaults integerForKey:[NSString stringWithFormat:@"syncState_%@", channelID]];
    }
    return AATTChannelFullSyncStateComplete;
}

@end
