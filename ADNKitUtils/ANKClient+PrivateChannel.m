//
//  ANKClient+PrivateChannel.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/23/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "ANKAnnotatableResource+AATTAnnotationHelper.h"
#import "ANKClient+PrivateChannel.h"
#import "ANKClient+AATTMessageManager.h"
#import "ANKChannel+AATTAnnotationHelper.h"

@implementation ANKClient (PrivateChannel)

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
            block(theChannel, nil);
        }
    }];
}

- (void)fetchActionChannelWithType:(NSString *)actionType targetChannelID:(NSString *)targetChannelID completionBlock:(PrivateChannelCompletionBlock)block {
    NSDictionary *parameters = @{@"include_channel_annotations" : @"1"};
    [self fetchCurrentUserSubscribedChannelsWithTypes:@[kChannelTypeAction] parameters:parameters completion:^(id responseObject, ANKAPIResponseMeta *meta, NSError *error) {
        if(!error) {
            ANKChannel *theChannel = [self newestActionChannelInArray:responseObject actionType:actionType targetChannelID:targetChannelID];
            block(theChannel, error);
        } else {
            block(responseObject, error);
        }
    }];
}

- (void)fetchOrCreateActionChannelWithType:(NSString *)actionType targetChannel:(ANKChannel *)targetChannel completionBlock:(PrivateChannelCompletionBlock)block {
    [self fetchActionChannelWithType:actionType targetChannelID:targetChannel.channelID completionBlock:^(id responseObject, NSError *error) {
        if(error) {
            block(responseObject, error);
        } else if(!responseObject) {
            [self createAndSubscribeToActionChannelWithType:actionType targetChannelID:targetChannel.channelID completionBlock:block];
        } else {
            block(responseObject, error);
        }
    }];
}

- (void)createAndSubscribeToActionChannelWithType:(NSString *)actionType targetChannelID:(NSString *)targetChannelID completionBlock:(PrivateChannelCompletionBlock)block {
    NSDictionary *metadataValue = @{ @"action_type" : actionType, @"channel_id" : targetChannelID };
    ANKAnnotation *metadataAnnotation = [ANKAnnotation annotationWithType:kChannelAnnotationActionMetadata value:metadataValue];
    [self createAndSubscribeToPrivateChannelWithType:kChannelTypeAction annotations:@[metadataAnnotation] block:block];
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
                block(responseObject, error);
            }];
        }
    }];
}

- (ANKChannel *)newestActionChannelInArray:(NSArray *)channels actionType:(NSString *)actionType targetChannelID:(NSString *)targetChannelID {
    ANKChannel *newest = nil;
    if(channels.count == 1) {
        ANKChannel *candidate = [channels objectAtIndex:0];
        if([self isMatchingActionChannel:candidate actionType:actionType targetChannelID:targetChannelID]) {
            newest = candidate;
        }
    } else if(channels.count > 1) {
        for(ANKChannel *channel in channels) {
            if([self isMatchingActionChannel:channel actionType:actionType targetChannelID:targetChannelID]) {
                if([channel.owner.userID isEqualToString:self.authenticatedUser.userID] &&
                   channel.writers.isImmutable &&
                   channel.writers.canCurrentUser &&
                   !channel.writers.canAnyUser &&
                   !channel.readers.isImmutable) {
                    if(!newest ||
                       channel.channelID.integerValue < newest.channelID.integerValue) {
                        newest = channel;
                    }
                }
            }
        }
    }
    return newest;
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
