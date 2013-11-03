//
//  AATTGeolocation.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 11/2/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTGeolocation.h"

@implementation AATTGeolocation

- (id)initWithName:(NSString *)name latitude:(double)latitude longitude:(double)longitude {
    self = [super init];
    if(self) {
        self.name = name;
        self.latitude = latitude;
        self.longitude = longitude;
    }
    return self;
}

@end
