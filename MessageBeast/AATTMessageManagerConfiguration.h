//
//  AATTMessageManagerConfiguration.h
//  MessageBeast
//
//  Created by Rob Brambley on 10/30/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AATTMessageManagerConfiguration : NSObject

@property BOOL isLocationLookupEnabled;
@property BOOL isHashtagExtractionEnabled;
@property NSMutableSet *annotationExtractions;

@property (nonatomic, copy) NSDate * (^dateAdapter)(ANKMessage *message);

/**
 Tell the AATTMessageManager to examine the annotations on all messages to see if
 annotations with the specified type exist. If so, a reference to the message will be
 persisted to the sqlite database for lookup at a later time. For example, if you
 want to be able to find all messages with OEmbeds at a later time, then
 you might call this method with the annotation type net.app.core.oembed.
 */
- (void)addAnnotationExtractionForAnnotationOfType:(NSString *)annotationType;

@end
