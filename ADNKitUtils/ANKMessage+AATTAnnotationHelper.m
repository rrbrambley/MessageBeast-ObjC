//
//  ANKMessage+AATTAnnotationHelper.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/31/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <ANKValueTransformations.h>

#import "ANKAnnotatableResource+AATTAnnotationHelper.h"
#import "ANKMessage+AATTAnnotationHelper.h"

@implementation ANKMessage (AATTAnnotationHelper)

static NSString *const kMessageAnnotationTargetMessage = @"com.alwaysallthetime.action.target_message";

- (NSDate *)ohaiDisplayDate {
    ANKAnnotation *annotation = [self firstAnnotationOfType:@"net.app.ohai.displaydate"];
    if(annotation) {
        return [[ANKValueTransformations transformations] NSDateFromNSString:[[annotation value] objectForKey:@"date"]];
    }
    return nil;
}

- (NSString *)targetMessageId {
    ANKAnnotation *targetMessage = [self firstAnnotationOfType:kMessageAnnotationTargetMessage];
    return [targetMessage.value objectForKey:@"id"];
}

@end
