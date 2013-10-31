//
//  AATTMessagePlus.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/30/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

@class AATTDisplayLocation;

@interface AATTMessagePlus : NSObject

@property ANKMessage *message;
@property NSDate *displayDate;
@property AATTDisplayLocation *displayLocation;

- (id)initWithMessage:(ANKMessage *)message;

@end
