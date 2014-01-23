//
//  ANKChannel+AATTAnnotationHelper.h
//  MessageBeast
//
//  Created by Rob Brambley on 12/2/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

static NSString *const kChannelAnnotationActionMetadata = @"com.alwaysallthetime.action.metadata";

@interface ANKChannel (AATTAnnotationHelper)

/**
 Obtain the target Channel id from this Channel's com.alwaysallthetime.action.metadata
 Annotation. This Annotation is required for Action Channels.
 
 @return the value for the channel_id key in this Channel's com.alwaysallthetime.action.metadata
 Annotation, or nil if the Annotation does not exist.
 */
- (NSString *)targetChannelID;

/**
 Obtain the action type from this Channel's com.alwaysallthetime.action.metadata
 Annotation. This Annotation is required for Action Channels.
 
 @return the value for the action_type key in this Channel's com.alwaysallthetime.action.metadata
 Annotation, or nil if the Annotation does not exist.
 */
- (NSString *)actionChannelType;

@end
