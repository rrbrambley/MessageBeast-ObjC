//
//  AATTDisplayLocationInstances.m
//  MessageBeast
//
//  Created by Rob Brambley on 11/2/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTDisplayLocation.h"
#import "AATTDisplayLocationInstances.h"

@implementation AATTDisplayLocationInstances

- (id)initWithDisplayLocation:(AATTDisplayLocation *)displayLocation {
    self = [super init];
    if(self) {
        self.displayLocation = displayLocation;
        self.name = displayLocation.name;
    }
    return self;
}

@end
