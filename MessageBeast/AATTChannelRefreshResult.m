//
//  AATTChannelRefreshResult.m
//  MessageBeast
//
//  Created by Rob Brambley on 1/1/14.
//  Copyright (c) 2014 Always All The Time. All rights reserved.
//

#import "AATTChannelRefreshResult.h"

@implementation AATTChannelRefreshResult

- (id)initWithChannel:(ANKChannel *)channel messagePlusses:(NSArray *)messagePlusses appended:(BOOL)appended {
    self = [super init];
    if(self) {
        _channel = channel;
        _messagePlusses = messagePlusses;
        _appended = appended;
        _success = YES;
    }
    return self;
}

- (id)initWithChannel:(ANKChannel *)channel error:(NSError *)error {
    self = [super init];
    if(self) {
        _channel = channel;
        _error = error;
        _success = NO;
    }
    return self;
}

- (id)initWithChannel:(ANKChannel *)channel {
    self = [super init];
    if(self) {
        _channel = channel;
        _success = NO;
    }
    return self;
}

- (BOOL)blockedDueToUnsentMessages {
    return !self.success && !self.error;
}

@end
