//
//  AATTMessagePlus.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/30/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTMessagePlus.h"

@implementation AATTMessagePlus

- (id)initWithMessage:(ANKMessage *)message {
    self = [super init];
    if(self) {
        self.message = message;
    }
    return self;
}
@end
