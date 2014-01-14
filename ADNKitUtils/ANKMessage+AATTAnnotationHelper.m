//
//  ANKMessage+AATTAnnotationHelper.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/31/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

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

- (NSString *)targetMessageID {
    ANKAnnotation *targetMessage = [self firstAnnotationOfType:kMessageAnnotationTargetMessage];
    return [targetMessage.value objectForKey:@"id"];
}

- (void)addDisplayDateAnnotationWithDate:(NSDate *)date {
    NSDictionary *value = @{@"date" : [[self dateFormatter] stringFromDate:date]};
    ANKAnnotation *annotation = [ANKAnnotation annotationWithType:@"net.app.ohai.displaydate" value:value];
    NSMutableArray *annotations = [NSMutableArray arrayWithArray:self.annotations];
    [annotations addObject:annotation];
    self.annotations = annotations;
}

- (void)addTargetMessageAnnotationWithTargetMessageID:(NSString *)targetMessageID {
    NSDictionary *value = @{@"id" : targetMessageID};
    ANKAnnotation *annotation = [ANKAnnotation annotationWithType:@"com.alwaysallthetime.action.target_message" value:value];
    NSMutableArray *annotations = [NSMutableArray arrayWithArray:self.annotations];
    [annotations addObject:annotation];
    self.annotations = annotations;
}

- (void)appendToAttachments:(ANKFile *)file {
    //if there's an existing attachments annotation (file list), append to it
    NSArray *annotations = self.annotations;
    NSInteger index = -1;
    for(NSUInteger i = 0; i < annotations.count; i++) {
        ANKAnnotation *annotation = [annotations objectAtIndex:i];
        if([kANKCoreAnnotationEmbeddedMedia isEqualToString:annotation.type]) {
            index = i;
            break;
        }
    }
    NSDictionary *fileDictionary = @{@"file_token" : file.fileToken, @"format" : @"metadata", @"file_id" : file.fileID};
    
    if(index != -1) {
        ANKAnnotation *attachmentsAnnotation = [annotations objectAtIndex:index];
        
        //append the new file to the file list
        NSMutableArray *newFileArray = [NSMutableArray arrayWithArray:[attachmentsAnnotation.value objectForKey:@"+net.app.core.file_list"]];
        [newFileArray addObject:fileDictionary];

        //create a new 'value' for the annotation, containing the new file list
        NSMutableDictionary *newValue = [NSMutableDictionary dictionaryWithDictionary:attachmentsAnnotation.value];
        [newValue setObject:newFileArray forKey:@"+net.app.core.file_list"];
        attachmentsAnnotation.value = newValue;
    } else {
        NSMutableArray *newAnnotations = [NSMutableArray arrayWithArray:self.annotations];
        
        NSMutableDictionary *value = [NSMutableDictionary dictionaryWithCapacity:1];
        [value setObject:@[fileDictionary] forKey:@"+net.app.core.file_list"];
        
        ANKAnnotation *attachments = [ANKAnnotation annotationWithType:kANKCoreAnnotationAttachments value:value];
        [newAnnotations addObject:attachments];
        self.annotations = newAnnotations;
    }
}

@end
