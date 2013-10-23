//
//  ANKClient+PrivateChannel.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/23/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

/**
 A Category for creating and retrieving channels that are intended to be used
 privately, by a single user - based on how Ohai does it.
 
 see: https://github.com/appdotnet/object-metadata/blob/master/channel-types/net.app.ohai.journal.md
 */
@interface ANKClient (PrivateChannel)

typedef void (^PrivateChannelCompletionBlock)(id responseObject, NSError *error);

- (void)fetchPrivateChannelWithType:(NSString *)type block:(PrivateChannelCompletionBlock)block;
- (void)createAndSubscribeToPrivateChannelWithType:(NSString *)type block:(PrivateChannelCompletionBlock)block;

@end
