//
//  ANKAnnotatableResource+AATTAnnotationHelper.h
//  MessageBeast
//
//  Created by Rob Brambley on 12/2/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

@interface ANKAnnotatableResource (AATTAnnotationHelper)

/**
 Obtain the first ANKAnnotation of the specified type.
 
 @param type the type of Annotation
 @return the first ANKAnnotation found in this resource's
         array of Annotations that has the specified type value, or
         nil if no Annotation with the specified type is found.
 */
- (ANKAnnotation *)firstAnnotationOfType:(NSString *)type;

@end
