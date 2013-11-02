//
//  ANKMessage+AATTAnnotationHelper.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/31/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <ANKValueTransformations.h>

#import "ANKMessage+AATTAnnotationHelper.h"

@implementation ANKMessage (AATTAnnotationHelper)

- (NSDate *)ohaiDisplayDate {
    NSArray *annotations = [self annotationsWithType:@"net.app.ohai.displaydate"];
    if([annotations count] > 0) {
        ANKAnnotation *annotation = [annotations objectAtIndex:0];
        return [[ANKValueTransformations transformations] NSDateFromNSString:[[annotation value] objectForKey:@"date"]];
    }
    return nil;
}

- (ANKAnnotation *)firstAnnotationOfType:(NSString *)type {
    NSArray *annotations = [self annotationsWithType:type];
    if(annotations.count > 0) {
        return [annotations objectAtIndex:0];
    }
    return nil;
}

@end
