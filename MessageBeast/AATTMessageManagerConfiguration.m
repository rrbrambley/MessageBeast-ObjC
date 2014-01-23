//
//  AATTMessageManagerConfiguration.m
//  MessageBeast
//
//  Created by Rob Brambley on 10/30/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTMessageManagerConfiguration.h"

@implementation AATTMessageManagerConfiguration

- (void)addAnnotationExtractionForAnnotationOfType:(NSString *)annotationType {
    if(!self.annotationExtractions) {
        self.annotationExtractions = [NSMutableSet set];
    }
    [self.annotationExtractions addObject:annotationType];
}

@end
