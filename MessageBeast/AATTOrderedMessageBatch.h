//
//  AATTOrderedMessageBatch.h
//  MessageBeast
//
//  Created by Rob Brambley on 10/31/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "AATTMinMaxPair.h"
#import "M13OrderedDictionary.h"

@interface AATTOrderedMessageBatch : NSObject

/**
 An Ordered Dictionary of @{NSDate : AATTMessagePlus} in
 reverse chronological order.
 */
@property M13OrderedDictionary *messagePlusses;

/**
 The min and max IDs and dates in this batch.
 */
@property AATTMinMaxPair *minMaxPair;

- (id)initWithOrderedMessagePlusses:(M13OrderedDictionary *)messagePlusses minMaxPair:(AATTMinMaxPair *)minMaxPair;

@end
