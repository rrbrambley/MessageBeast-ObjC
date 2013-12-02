//
//  ANKMessage+AATTAnnotationHelper.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/31/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

@interface ANKMessage (AATTAnnotationHelper)

- (NSDate *)ohaiDisplayDate;
- (ANKAnnotation *)firstAnnotationOfType:(NSString *)type;
- (NSString *)targetMessageId;

@end
