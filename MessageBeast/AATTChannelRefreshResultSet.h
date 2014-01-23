//
//  AATTChannelRefreshResultSet.h
//  MessageBeast
//
//  Created by Rob Brambley on 1/1/14.
//  Copyright (c) 2014 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AATTChannelRefreshResult;

@interface AATTChannelRefreshResultSet : NSObject

- (void)addRefreshResult:(AATTChannelRefreshResult *)refreshResult;
- (AATTChannelRefreshResult *)channelRefreshResultForChannelWithID:(NSString *)channelID;

@end
