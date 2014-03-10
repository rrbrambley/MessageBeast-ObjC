//
//  AATTFilteredMessageBatch.h
//  MessageBeast
//
//  Created by Rob Brambley on 1/9/14.
//  Copyright (c) 2014 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "AATTMessageManager.h"
#import "AATTOrderedMessageBatch.h"

/**
 An ordered message batch that has had a filter applied.
 
 The messages that were filtered out of the messagePlusses dictionary
 are stored in the excludedMessages dictionary.
 */
@interface AATTFilteredMessageBatch : AATTOrderedMessageBatch

/**
 The dictionary of excluded messages that were filtered out of the messagePlusses dictionary.
 */
@property M13OrderedDictionary *excludedMessages;

/**
 Apply a message filter to an AATTOrderedMessageBatch and return an AATTFilteredMessageBatch.
 
 @param batch the AATTOrderedMessageBatch to filter
 @param messageFilter the AATTMessageFilter to apply to the batch
 */
+ (instancetype)filteredMessageBatchWithOrderedMessageBatch:(AATTOrderedMessageBatch *)batch messageFilter:(AATTMessageFilter)messageFilter;

@end
