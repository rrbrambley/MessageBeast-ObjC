//
//  AATTTargetWithActionChannelsSpecSet.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 1/1/14.
//  Copyright (c) 2014 Always All The Time. All rights reserved.
//

#import "AATTTargetWithActionChannelsSpecSet.h"

@implementation AATTTargetWithActionChannelsSpecSet

- (id)initWithTargetChannelSpec:(AATTChannelSpec *)targetChannelSpec actionChannelActionTypes:(NSArray *)actionChannelActionTypes {
    self = [super init];
    if(self) {
        _targetChannelSpec = targetChannelSpec;
        _actionChannelActionTypes = actionChannelActionTypes;
    }
    return self;
}

- (NSString *)actionChannelActionTypeAtIndex:(NSUInteger)index {
    return [self.actionChannelActionTypes objectAtIndex:index];
}

- (NSUInteger)actionChannelCount {
    return self.actionChannelActionTypes.count;
}

@end
