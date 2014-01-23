//
//  AATTHashtagInstances.m
//  MessageBeast
//
//  Created by Rob Brambley on 11/3/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTHashtagInstances.h"

@implementation AATTHashtagInstances

- (id)initWithName:(NSString *)name {
    self = [super init];
    if(self) {
        self.name = name;
    }
    return self;
}

@end
