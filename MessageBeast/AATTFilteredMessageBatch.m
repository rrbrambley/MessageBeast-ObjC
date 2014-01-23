//
//  AATTFilteredMessageBatch.m
//  MessageBeast
//
//  Created by Rob Brambley on 1/9/14.
//  Copyright (c) 2014 Always All The Time. All rights reserved.
//

#import "AATTFilteredMessageBatch.h"

@implementation AATTFilteredMessageBatch

+ (instancetype)filteredMessageBatchWithOrderedMessageBatch:(AATTOrderedMessageBatch *)batch messageFilter:(AATTMessageFilter)messageFilter {
    NSOrderedDictionary *excludedMessages = messageFilter(batch.messagePlusses);
    
    NSMutableOrderedDictionary *results = [NSMutableOrderedDictionary orderedDictionaryWithOrderedDictionary:batch.messagePlusses];
    for(NSString *messageID in [excludedMessages allKeys]) {
        [results removeEntryWithKey:messageID];
    }
    return [[AATTFilteredMessageBatch alloc] initWithOrderedMessageBatch:batch excludedMessages:excludedMessages];
}

- (id)initWithOrderedMessageBatch:(AATTOrderedMessageBatch *)batch excludedMessages:(NSOrderedDictionary *)excludedMessages {
    self = [super initWithOrderedMessagePlusses:batch.messagePlusses minMaxPair:batch.minMaxPair];
    if(self) {
        self.excludedMessages = excludedMessages;
    }
    return self;
}

@end
