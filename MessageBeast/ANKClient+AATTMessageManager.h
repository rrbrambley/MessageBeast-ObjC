//
//  ANKClient+AATTMessageManager.h
//  MessageBeast
//
//  Created by Rob Brambley on 10/31/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

@interface ANKClient (AATTMessageManager)

/**
 Fetch a Message with the specified parameters.
 */
- (ANKJSONRequestOperation *)fetchMessageWithID:(NSString *)messageID inChannelWithID:(NSString *)channelID parameters:(NSDictionary *)parameters completion:(ANKClientCompletionBlock)completionHandler;

/**
 Fetch Messages in a Channel with the provided parameters.
 */
- (ANKJSONRequestOperation *)fetchMessagesInChannelWithID:(NSString *)channelID parameters:(NSDictionary *)parameters completion:(ANKClientCompletionBlock)completionHandler;

/**
 Fetch the current user's subscribed Channels, filtering to those which have one of the specified Channel types.
 */
- (ANKJSONRequestOperation *)fetchCurrentUserSubscribedChannelsWithTypes:(NSArray *)types parameters:(NSDictionary *)additionalParameters completion:(ANKClientCompletionBlock)completionHandler;

/**
 Create a Message in a Channel with the provided parameters.
 */
- (ANKJSONRequestOperation *)createMessage:(ANKMessage *)message inChannelWithID:(NSString *)channelID parameters:(NSDictionary *)parameters completion:(ANKClientCompletionBlock)completionHandler;
@end
