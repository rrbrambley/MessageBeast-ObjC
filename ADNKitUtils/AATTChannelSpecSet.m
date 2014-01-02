//
//  AATTChannelSpecSet.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 1/1/14.
//  Copyright (c) 2014 Always All The Time. All rights reserved.
//

#import "AATTChannelSpecSet.h"

@implementation AATTChannelSpecSet

- (id)initWithChannelSpecs:(NSArray *)channelSpecs {
    self = [super init];
    if(self) {
        self.channelSpecs = channelSpecs;
    }
    return self;
}

- (NSUInteger)count {
    return self.channelSpecs.count;
}

- (AATTChannelSpec *)channelSpecAtIndex:(NSUInteger)index {
    return [self.channelSpecs objectAtIndex:index];
}

@end
