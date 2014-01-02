//
//  AATTChannelRefreshResult.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 1/1/14.
//  Copyright (c) 2014 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AATTChannelRefreshResult : NSObject

@property (readonly) BOOL blockedDueToUnsentMessages;
@property (readonly) BOOL success;
@property (readonly) ANKChannel *channel;
@property (readonly) NSArray *messagePlusses;
@property (readonly) BOOL appended;
@property (readonly) NSError *error;

- (id)initWithChannel:(ANKChannel *)channel messagePlusses:(NSArray *)messagePlusses appended:(BOOL)appended;
- (id)initWithChannel:(ANKChannel *)channel error:(NSError *)error;
- (id)initWithChannel:(ANKChannel *)channel;

@end
