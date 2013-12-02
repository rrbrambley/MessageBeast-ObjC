//
//  ANKChannel+AATTAnnotationHelper.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 12/2/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "ANKAnnotatableResource+AATTAnnotationHelper.h"
#import "ANKChannel+AATTAnnotationHelper.h"

@implementation ANKChannel (AATTAnnotationHelper)

static NSString *const kChannelAnnotationActionMetadata = @"com.alwaysallthetime.action.metadata";

- (NSString *)targetChannelId {
    ANKAnnotation *a = [self firstAnnotationOfType:kChannelAnnotationActionMetadata];
    return [a.value objectForKey:@"channel_id"];
}

- (NSString *)actionChannelType {
    ANKAnnotation *a = [self firstAnnotationOfType:kChannelAnnotationActionMetadata];
    return [a.value objectForKey:@"action_type"];
}

@end
