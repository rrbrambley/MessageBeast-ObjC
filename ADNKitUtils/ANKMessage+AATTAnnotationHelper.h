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
- (NSString *)targetMessageID;

- (void)addDisplayDateAnnotationWithDate:(NSDate *)date;
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

@end
