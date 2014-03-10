//
//  AATTOrderedMessageBatch.m
//  MessageBeast
//
//  Created by Rob Brambley on 10/31/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTOrderedMessageBatch.h"

@implementation AATTOrderedMessageBatch

- (id)initWithOrderedMessagePlusses:(M13OrderedDictionary *)messagePlusses minMaxPair:(AATTMinMaxPair *)minMaxPair {
    self = [super init];
    if(self) {
        self.messagePlusses = messagePlusses;
        self.minMaxPair = minMaxPair;
    }
    return self;
}
@end
