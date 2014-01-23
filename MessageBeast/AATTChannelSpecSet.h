//
//  AATTChannelSpecSet.h
//  MessageBeast
//
//  Created by Rob Brambley on 1/1/14.
//  Copyright (c) 2014 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AATTChannelSpec;

@interface AATTChannelSpecSet : NSObject

@property NSArray *channelSpecs;
@property (readonly) NSUInteger count;

- (id)initWithChannelSpecs:(NSArray *)channelSpecs;

- (AATTChannelSpec *)channelSpecAtIndex:(NSUInteger)index;

@end
