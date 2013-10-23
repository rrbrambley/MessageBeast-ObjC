//
//  ANKClient+PrivateChannel.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/23/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "ANKClient+PrivateChannel.h"

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

- (void)createAndSubscribeToPrivateChannelWithType:(NSString *)type block:(PrivateChannelCompletionBlock)block {
    ANKACL *writers = [[ANKACL alloc] init];
    writers.userIDs = [NSArray arrayWithObject:self.authenticatedUser.userID];
    writers.canAnyUser = NO;
    writers.isImmutable = YES;
    
    ANKACL *readers = [[ANKACL alloc] init];
    readers.isImmutable = NO;
    
    [self createChannelWithType:type readers:readers writers:writers completion:^(id responseObject, ANKAPIResponseMeta *meta, NSError *error) {
        if(error) {
            block(nil, error);
        } else {
            [self subscribeToChannel:responseObject completion:^(id responseObject, ANKAPIResponseMeta *meta, NSError *error) {
                block(responseObject, error);
            }];
        }
    }];
}

@end
