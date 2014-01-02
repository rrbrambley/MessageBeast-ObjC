//
//  AATTTargetWithActionChannelsSpecSet.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 1/1/14.
//  Copyright (c) 2014 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AATTChannelSpec;

@interface AATTTargetWithActionChannelsSpecSet : NSObject

@property (readonly) NSArray *actionChannelActionTypes;
@property (readonly) AATTChannelSpec *targetChannelSpec;
@property (readonly) NSUInteger actionChannelCount;

- (id)initWithTargetChannelSpec:(AATTChannelSpec *)targetChannelSpec actionChannelActionTypes:(NSArray *)actionChannelActionTypes;

- (NSString *)actionChannelActionTypeAtIndex:(NSUInteger)index;

@end
