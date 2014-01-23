//
//  ANKChannel+AATTAnnotationHelper.h
//  MessageBeast
//
//  Created by Rob Brambley on 12/2/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

static NSString *const kChannelAnnotationActionMetadata = @"com.alwaysallthetime.action.metadata";

@interface ANKChannel (AATTAnnotationHelper)

- (NSString *)targetChannelID;
- (NSString *)actionChannelType;

@end
