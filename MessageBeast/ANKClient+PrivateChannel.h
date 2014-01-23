//
//  ANKClient+PrivateChannel.h
//  MessageBeast
//
//  Created by Rob Brambley on 10/23/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

/**
 A Category for creating and retrieving channels that are intended to be used
 privately, by a single user - based on how Ohai does it.
 
 see: https://github.com/appdotnet/object-metadata/blob/master/channel-types/net.app.ohai.journal.md
 */

static NSString *const kChannelTypeAction = @"com.alwaysallthetime.action";

@interface ANKClient (PrivateChannel)

typedef void (^PrivateChannelCompletionBlock)(ANKChannel *channel, NSError *error);

- (void)getOrCreatePrivateChannelWithType:(NSString *)type completionBlock:(PrivateChannelCompletionBlock)block;
- (void)getOrCreateActionChannelWithType:(NSString *)actionType targetChannel:(ANKChannel *)targetChannel completionBlock:(PrivateChannelCompletionBlock)block;

- (void)fetchPrivateChannelWithType:(NSString *)type block:(PrivateChannelCompletionBlock)block;
- (void)fetchActionChannelWithType:(NSString *)actionType targetChannelID:(NSString *)targetChannelID completionBlock:(PrivateChannelCompletionBlock)block;
- (void)createAndSubscribeToPrivateChannelWithType:(NSString *)type block:(PrivateChannelCompletionBlock)block;

@end
