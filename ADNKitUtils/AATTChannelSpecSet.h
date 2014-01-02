//
//  AATTChannelSpecSet.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 1/1/14.
//  Copyright (c) 2014 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AATTChannelSpec;

@interface AATTChannelSpecSet : NSObject

@property NSArray *channelSpecs;
@property (nonatomic) NSUInteger count;

- (id)initWithChannelSpecs:(NSArray *)channelSpecs;

- (AATTChannelSpec *)channelSpecAtIndex:(NSUInteger)index;

@end
