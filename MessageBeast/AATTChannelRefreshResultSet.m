//
//  AATTChannelRefreshResultSet.m
//  MessageBeast
//
//  Created by Rob Brambley on 1/1/14.
//  Copyright (c) 2014 Always All The Time. All rights reserved.
//

#import "AATTChannelRefreshResult.h"
#import "AATTChannelRefreshResultSet.h"

@interface AATTChannelRefreshResultSet ()
@property NSMutableDictionary *results;
@end

@implementation AATTChannelRefreshResultSet

- (id)init {
    self = [super init];
    if(self) {
        self.results = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)addRefreshResult:(AATTChannelRefreshResult *)refreshResult {
    ANKChannel *channel = refreshResult.channel;
    [self.results setObject:refreshResult forKey:channel.channelID];
}

- (AATTChannelRefreshResult *)channelRefreshResultForChannelWithID:(NSString *)channelID {
    return [self.results objectForKey:channelID];
}

@end
