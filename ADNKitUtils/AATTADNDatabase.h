//
//  AATTADNDatabase.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/30/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AATTMessagePlus, AATTOrderedMessageBatch;

@interface AATTADNDatabase : NSObject

+ (AATTADNDatabase *)sharedInstance;

- (void)insertOrReplaceMessage:(AATTMessagePlus *)message;

- (AATTOrderedMessageBatch *)messagesInChannelWithId:(NSString *)channelId limit:(NSInteger)limit;
- (AATTOrderedMessageBatch *)messagesInChannelWithId:(NSString *)channelId beforeDate:(NSDate *)beforeDate limit:(NSInteger)limit;

@end
