//
//  AATTAnnotationInstances.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 1/13/14.
//  Copyright (c) 2014 Always All The Time. All rights reserved.
//

#import "AATTAnnotationInstances.h"

@implementation AATTAnnotationInstances

- (id)initWithAnnotationType:(NSString *)type {
    self = [super init];
    if(self) {
        self.name = type;
        self.type = type;
    }
    return self;
}

@end
