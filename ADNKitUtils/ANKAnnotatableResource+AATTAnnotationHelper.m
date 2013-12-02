//
//  ANKAnnotatableResource+AATTAnnotationHelper.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 12/2/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "ANKAnnotatableResource+AATTAnnotationHelper.h"

@implementation ANKAnnotatableResource (AATTAnnotationHelper)

- (ANKAnnotation *)firstAnnotationOfType:(NSString *)type {
    NSArray *annotations = [self annotationsWithType:type];
    if(annotations.count > 0) {
        return [annotations objectAtIndex:0];
    }
    return nil;
}

@end