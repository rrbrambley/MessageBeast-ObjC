//
//  ANKClient+PrivateChannel.h
//  MessageBeast
//
//  Created by Rob Brambley on 10/23/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

/**
 A Category for creating and retrieving Channels that are intended to be used
 privately, by a single user - based on how Ohai does it.
 (see: https://github.com/appdotnet/object-metadata/blob/master/channel-types/net.app.ohai.journal.md)
 
 Additionally, this can be used to create new, or retrieve existing Action Channels to be used
 with the AATTActionMessageManager.
 
 Often, you won't need to interface with this class directly, but instead you can rely on
 channel initialization methods in the AATTChannelSyncManager and AATTActionMessageManager.
 */

static NSString *const kChannelTypeAction = @"com.alwaysallthetime.action";

@interface ANKClient (PrivateChannel)

typedef void (^PrivateChannelCompletionBlock)(ANKChannel *channel, NSError *error);

/**
 Get the existing private Channel of the provided type, or create and return a new one if one has not already been created.

 In the event that the user has more than one Channel of the specified type, the algorithm
 used to return the Channel is the same as that which is described in the Ohai Channel documentation.

 @param type the Channel type
 @param block the completion block
 */
- (void)getOrCreatePrivateChannelWithType:(NSString *)type completionBlock:(PrivateChannelCompletionBlock)block;

/**
 Get the existing Action Channel of the specified action type for specified target Channel.
 If one doesn't already exist, then create a new one and return it. Rather than calling this
 method directly, you will probably want to use the AATTActionMessageManager's 
 initActionChannelWithType:targetChannel:completionBlock: method.
 
 In the event that the user has more than one Channel of the specified type, the algorithm
 used to return the Channel is the same as that which is described in the Ohai Channel documentation.
 
 @param actionType the action_type value to be included in the com.alwaysallthetime.action.metadata annotation
 @param targetChannel the target Channel for the Action Channel
 @param block the completion block
 */
- (void)getOrCreateActionChannelWithType:(NSString *)actionType targetChannel:(ANKChannel *)targetChannel completionBlock:(PrivateChannelCompletionBlock)block;

@end
