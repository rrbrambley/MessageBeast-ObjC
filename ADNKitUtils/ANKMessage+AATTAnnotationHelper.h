//
//  ANKMessage+AATTAnnotationHelper.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/31/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

static NSString *const kMessageAnnotationTargetMessage = @"com.alwaysallthetime.action.target_message";

@interface ANKMessage (AATTAnnotationHelper)

- (NSDate *)ohaiDisplayDate;
- (NSString *)targetMessageId;

- (void)addDisplayDateAnnotationWithDate:(NSDate *)date;

@end
