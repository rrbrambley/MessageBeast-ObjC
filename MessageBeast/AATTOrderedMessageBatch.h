//
//  AATTOrderedMessageBatch.h
//  MessageBeast
//
//  Created by Rob Brambley on 10/31/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "AATTMinMaxPair.h"
#import "NSOrderedDictionary.h"

@interface AATTOrderedMessageBatch : NSObject

@property NSOrderedDictionary *messagePlusses;
@property AATTMinMaxPair *minMaxPair;

- (id)initWithOrderedMessagePlusses:(NSOrderedDictionary *)messagePlusses minMaxPair:(AATTMinMaxPair *)minMaxPair;

@end
