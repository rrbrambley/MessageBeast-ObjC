//
//  AATTDisplayLocationInstances.h
//  MessageBeast
//
//  Created by Rob Brambley on 11/2/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTBaseMessageInstances.h"

@class AATTDisplayLocation;

@interface AATTDisplayLocationInstances : AATTBaseMessageInstances

@property AATTDisplayLocation *displayLocation;

- (id)initWithDisplayLocation:(AATTDisplayLocation *)displayLocation;

@end
