//
//  ANKClient+AATTMessageManager.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/31/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

@interface ANKClient (AATTMessageManager)

- (ANKJSONRequestOperation *)fetchMessagesInChannelWithID:(NSString *)channelID parameters:(NSDictionary *)parameters completion:(ANKClientCompletionBlock)completionHandler;

@end
