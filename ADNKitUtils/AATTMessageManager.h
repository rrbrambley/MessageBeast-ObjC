//
//  AATTMessageManager.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/30/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

@class AATTMessageManagerConfiguration, NSOrderedDictionary;

@interface AATTMessageManager : NSObject

typedef void (^AATTMessageManagerResponseBlock)(NSArray *messagePlusses, BOOL appended, ANKAPIResponseMeta *meta, NSError *error);

- (id)initWithANKClient:(ANKClient *)client configuration:(AATTMessageManagerConfiguration *)configuration;

- (void)setQueryParametersForChannelWithID:(NSString *)channelID parameters:(NSDictionary *)parameters;

- (NSOrderedDictionary *)loadPersistedMesssageForChannelWithID:(NSString *)channelID limit:(NSInteger)limit;

- (void)fetchMessagesInChannelWithID:(NSString *)channelID withResponseBlock:(AATTMessageManagerResponseBlock)block;
- (void)fetchNewestMessagesInChannelWithID:(NSString *)channelID withResponseBlock:(AATTMessageManagerResponseBlock)block;
- (void)fetchMoreMessagesInChannelWithID:(NSString *)channelID withResponseBlock:(AATTMessageManagerResponseBlock)block;

@end
