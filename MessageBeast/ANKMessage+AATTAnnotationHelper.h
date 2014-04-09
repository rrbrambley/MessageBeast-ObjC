//
//  ANKMessage+AATTAnnotationHelper.h
//  MessageBeast
//
//  Created by Rob Brambley on 10/31/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

static NSString *const kMessageAnnotationTargetMessage = @"com.alwaysallthetime.action.target_message";

@interface ANKMessage (AATTAnnotationHelper)

/**
 Get the date value from this Message's net.app.ohai.displaydate Annotation.
 
 @return the date value from this Message's net.app.ohai.displaydate Annotation,
         or nil if no such Annotation exists.
 */
- (NSDate *)ohaiDisplayDate;

/**
 Get the id value from this Message's com.alwaysallthetime.action.target_message Annotation.
 This Annotation is required for Action Messages.
 
 @return the id value from this Message's com.alwaysallthetime.action.target_message Annotation
         or nil if no such Annotation exists.
 */
- (NSString *)targetMessageID;

/**
 Add a net.app.ohai.displaydate Annotation to this Message whose date value is the
 provided date.
 
 @param date the NSDate to encode in the date value of the new Annotation
 */
- (void)addDisplayDateAnnotationWithDate:(NSDate *)date;

/**
 Add a com.alwaysallthetime.action.target_message Annotation to this Message whose
 id value is the provided target Message id. This annotation is requried for all
 Action Messages.
 
 @param the id value to set in the new Annotation
 */
- (void)addTargetMessageAnnotationWithTargetMessageID:(NSString *)targetMessageID;

/*
 Add the file to the first-found attachments annotation, or create
 a new one if none exist.
 
 This looks the replacement value +net.app.core.file_list. A
 complete file list (i.e. net.app.core.file_list without the +) is
 ineligible (annotations are immutable).
 
 @param file the file to add to a file list in an attachments annotation.
 */
- (void)appendToAttachments:(ANKFile *)file;

/**
 Add a net.app.core.checkin annotation to this Message's annotations,
 using the provided factual ID.
 
 @param the factual ID associated with an ANKPlace
 */
- (void)addCheckinAnnotationWithFactualID:(NSString *)factualID;

@end
