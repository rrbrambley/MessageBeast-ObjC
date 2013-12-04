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

- (NSDateFormatter *)dateFormatter {
	static NSDateFormatter *sharedDateFormatter = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedDateFormatter = [[NSDateFormatter alloc] init];
		sharedDateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
        sharedDateFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
	});
	return sharedDateFormatter;
}

- (NSDate *)ohaiDisplayDate {
    ANKAnnotation *annotation = [self firstAnnotationOfType:@"net.app.ohai.displaydate"];
    if(annotation) {
        NSString *dateString = [[annotation value] objectForKey:@"date"];
        return [[self dateFormatter] dateFromString:dateString];
    }
    return nil;
}

- (NSString *)targetMessageId {
    ANKAnnotation *targetMessage = [self firstAnnotationOfType:kMessageAnnotationTargetMessage];
    return [targetMessage.value objectForKey:@"id"];
}

@end
