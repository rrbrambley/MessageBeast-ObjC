//
//  ANKClient+AATTMessageManager.m
//  MessageBeast
//
//  Created by Rob Brambley on 10/31/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <AFHTTPClient.h>
#import <ANKClient+ANKRequestsAPI.h>

@implementation ANKClient (AATTMessageManager)

- (ANKJSONRequestOperation *)fetchMessageWithID:(NSString *)messageID inChannelWithID:(NSString *)channelID parameters:(NSDictionary *)parameters completion:(ANKClientCompletionBlock)completionHandler {
	return [self enqueueGETPath:[NSString stringWithFormat:@"channels/%@/messages/%@", channelID, messageID]
					 parameters:parameters
						success:[self successHandlerForResourceClass:[ANKMessage class] clientHandler:completionHandler]
						failure:[self failureHandlerForClientHandler:completionHandler]];
}

- (ANKJSONRequestOperation *)fetchMessagesInChannelWithID:(NSString *)channelID parameters:(NSDictionary *)parameters completion:(ANKClientCompletionBlock)completionHandler {
	return [self enqueueGETPath:[NSString stringWithFormat:@"channels/%@/messages", channelID]
					 parameters:parameters
						success:[self successHandlerForCollectionOfResourceClass:[ANKMessage class] clientHandler:completionHandler]
						failure:[self failureHandlerForClientHandler:completionHandler]];
}

- (ANKJSONRequestOperation *)fetchMessagesWithIDs:(NSArray *)messageIDs parameters:(NSDictionary *)parameters completion:(ANKClientCompletionBlock)completionHandler {
    
    NSMutableDictionary *newParams = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [newParams setObject:[messageIDs componentsJoinedByString:@","] forKey:@"ids"];
    
	return [self enqueueGETPath:@"channels/messages"
					 parameters:newParams
						success:[self successHandlerForCollectionOfResourceClass:[ANKMessage class] clientHandler:completionHandler]
						failure:[self failureHandlerForClientHandler:completionHandler]];
}

- (ANKJSONRequestOperation *)fetchCurrentUserSubscribedChannelsWithTypes:(NSArray *)types parameters:(NSDictionary *)additionalParameters completion:(ANKClientCompletionBlock)completionHandler {
	if (!types) {
		types = @[];
	}
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithDictionary:additionalParameters];
    [parameters setObject:[types componentsJoinedByString:@","] forKey:@"channel_types"];
       
	return [self enqueueGETPath:@"channels"
					 parameters:parameters
						success:[self successHandlerForCollectionOfResourceClass:[ANKChannel class] clientHandler:completionHandler]
						failure:[self failureHandlerForClientHandler:completionHandler]];
}

- (ANKJSONRequestOperation *)createMessage:(ANKMessage *)message inChannelWithID:(NSString *)channelID parameters:(NSDictionary *)parameters completion:(ANKClientCompletionBlock)completionHandler {
    
    NSMutableURLRequest *request = [self requestWithMethod:@"POST" path:[NSString stringWithFormat:@"channels/%@/messages", channelID] parameters:[message JSONDictionary]];
    
    NSString *encodedParameters = AFQueryStringFromParametersWithEncoding(parameters, self.stringEncoding);
    NSString *URLString = [request.URL absoluteString];
    request.URL = [NSURL URLWithString:[URLString stringByAppendingFormat:[URLString rangeOfString:@"?"].location == NSNotFound ? @"?%@" : @"&%@", encodedParameters]];
    
    AFNetworkingSuccessBlock successBlock= [self successHandlerForResourceClass:[ANKMessage class] clientHandler:completionHandler];
    ANKJSONRequestOperation *operation = (ANKJSONRequestOperation *)[self HTTPRequestOperationWithRequest:request success:successBlock failure:[self failureHandlerForClientHandler:completionHandler]];
    [self enqueueHTTPRequestOperation:operation];
    operation.successCallbackQueue = self.successCallbackQueue;
    operation.failureCallbackQueue = self.failureCallbackQueue;

    return operation;
}

@end
