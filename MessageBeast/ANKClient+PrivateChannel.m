//
//  ANKClient+PrivateChannel.m
//  MessageBeast
//
//  Created by Rob Brambley on 10/23/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTADNPersistence.h"
#import "ANKAnnotatableResource+AATTAnnotationHelper.h"
#import "ANKClient+PrivateChannel.h"
#import "ANKClient+AATTMessageManager.h"
#import "ANKChannel+AATTAnnotationHelper.h"

@implementation ANKClient (PrivateChannel)

- (void)getOrCreatePrivateChannelWithType:(NSString *)type completionBlock:(PrivateChannelCompletionBlock)block {
    ANKChannel *channel = [AATTADNPersistence channelWithType:type];
    if(!channel) {
        [self fetchPrivateChannelWithType:type block:^(id responseObject, NSError *error) {
            if(!responseObject) {
                [self createAndSubscribeToPrivateChannelWithType:type block:block];
            } else {
                [AATTADNPersistence saveChannel:responseObject];
                block(responseObject, nil);
            }
        }];
    } else {
        block(channel, nil);
    }
}

- (void)fetchPrivateChannelWithType:(NSString *)type block:(PrivateChannelCompletionBlock)block {
    [self fetchCurrentUserSubscribedChannelsWithTypes:[NSArray arrayWithObject:type] completion:^(id responseObject, ANKAPIResponseMeta *meta, NSError *error) {
        if(error) {
            block(nil, error);
        } else {
            ANKChannel *theChannel = nil;
            
            NSArray *channels = responseObject;
            if(channels.count == 1) {
                theChannel = [channels objectAtIndex:0];
            } else if(channels.count > 1) {
                for(ANKChannel *channel in channels) {
                    if([channel.owner.userID isEqualToString:self.authenticatedUser.userID] &&
                       channel.writers.isImmutable &&
                       channel.writers.canCurrentUser &&
                       !channel.writers.canAnyUser &&
                       !channel.readers.isImmutable) {
                        if(!theChannel ||
                           channel.channelID.integerValue < theChannel.channelID.integerValue) {
                            theChannel = channel;
                        }
                    }
                }
            }
            if(theChannel) {
                [AATTADNPersistence saveChannel:theChannel];
            }
            block(theChannel, nil);
        }
    }];
}

- (void)fetchActionChannelWithType:(NSString *)actionType targetChannelID:(NSString *)targetChannelID completionBlock:(PrivateChannelCompletionBlock)block {
    NSDictionary *parameters = @{@"include_channel_annotations" : @"1"};
    [self fetchCurrentUserSubscribedChannelsWithTypes:@[kChannelTypeAction] parameters:parameters completion:^(id responseObject, ANKAPIResponseMeta *meta, NSError *error) {
        if(!error) {
            ANKChannel *theChannel = [self oldestActionChannelInArray:responseObject actionType:actionType targetChannelID:targetChannelID];
            if(theChannel) {
                [AATTADNPersistence saveActionChannel:theChannel actionType:actionType targetChannelID:targetChannelID];
            }
            block(theChannel, error);
        } else {
            block(responseObject, error);
        }
    }];
}

- (void)getOrCreateActionChannelWithType:(NSString *)actionType targetChannel:(ANKChannel *)targetChannel completionBlock:(PrivateChannelCompletionBlock)block {
    ANKChannel *actionChannel = [AATTADNPersistence channelWithActionType:actionType targetChannelID:targetChannel.channelID];
    if(!actionChannel) {
        [self fetchActionChannelWithType:actionType targetChannelID:targetChannel.channelID completionBlock:^(ANKChannel *channel, NSError *error) {
            if(error) {
                block(channel, error);
            } else if(!channel) {
                [self createAndSubscribeToActionChannelWithType:actionType targetChannelID:targetChannel.channelID completionBlock:block];
            } else {
                block(channel, error);
            }
        }];
    } else {
        block(actionChannel, nil);
    }
}

- (void)createAndSubscribeToActionChannelWithType:(NSString *)actionType targetChannelID:(NSString *)targetChannelID completionBlock:(PrivateChannelCompletionBlock)block {
    NSDictionary *metadataValue = @{ @"action_type" : actionType, @"channel_id" : targetChannelID };
    ANKAnnotation *metadataAnnotation = [ANKAnnotation annotationWithType:kChannelAnnotationActionMetadata value:metadataValue];
    [self createAndSubscribeToPrivateChannelWithType:kChannelTypeAction annotations:@[metadataAnnotation] block:^(ANKChannel *channel, NSError *error) {
        if(channel && !error) {
            [AATTADNPersistence saveActionChannel:channel actionType:actionType targetChannelID:targetChannelID];
        }
        block(channel, error);
    }];
}

- (void)createAndSubscribeToPrivateChannelWithType:(NSString *)type block:(PrivateChannelCompletionBlock)block {
    [self createAndSubscribeToPrivateChannelWithType:type annotations:nil block:block];
}

#pragma mark - Private

- (void)createAndSubscribeToPrivateChannelWithType:(NSString *)type annotations:(NSArray *)annotations block:(PrivateChannelCompletionBlock)block {
    ANKACL *writers = [[ANKACL alloc] init];
    writers.userIDs = @[self.authenticatedUser.userID];
    writers.canAnyUser = NO;
    writers.isImmutable = YES;
    
    ANKACL *readers = [[ANKACL alloc] init];
    readers.isImmutable = NO;
    
    ANKChannel *channel = [[ANKChannel alloc] init];
    channel.type = type;
    channel.readers = readers;
    channel.writers = writers;
    channel.annotations = annotations;
    
    [self createChannel:channel completion:^(id responseObject, ANKAPIResponseMeta *meta, NSError *error) {
        if(error) {
            block(nil, error);
        } else {
            [self subscribeToChannel:responseObject completion:^(id responseObject, ANKAPIResponseMeta *meta, NSError *error) {
                [AATTADNPersistence saveChannel:responseObject];
                block(responseObject, error);
            }];
        }
    }];
}

- (ANKChannel *)oldestActionChannelInArray:(NSArray *)channels actionType:(NSString *)actionType targetChannelID:(NSString *)targetChannelID {
    ANKChannel *oldest = nil;
    if(channels.count == 1) {
        ANKChannel *candidate = [channels objectAtIndex:0];
        if([self isMatchingActionChannel:candidate actionType:actionType targetChannelID:targetChannelID]) {
            oldest = candidate;
        }
    } else if(channels.count > 1) {
        for(ANKChannel *channel in channels) {
            if([self isMatchingActionChannel:channel actionType:actionType targetChannelID:targetChannelID]) {
                if([channel.owner.userID isEqualToString:self.authenticatedUser.userID] &&
                   channel.writers.isImmutable &&
                   channel.writers.canCurrentUser &&
                   !channel.writers.canAnyUser &&
                   !channel.readers.isImmutable) {
                    if(!oldest ||
                       channel.channelID.integerValue < oldest.channelID.integerValue) {
                        oldest = channel;
                    }
                }
            }
        }
    }
    return oldest;
}

- (BOOL)isMatchingActionChannel:(ANKChannel *)actionChannel actionType:(NSString *)actionType targetChannelID:(NSString *)targetChannelID {
    NSString *theActionType = [actionChannel actionChannelType];
    NSString *theTargetChannelID = [actionChannel targetChannelID];
    if([theActionType isEqualToString:actionType] && [theTargetChannelID isEqualToString:targetChannelID]) {
        return YES;
    }
    return NO;
}

@end
