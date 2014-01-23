//
//  AATTAnnotationInstances.h
//  MessageBeast
//
//  Created by Rob Brambley on 1/13/14.
//  Copyright (c) 2014 Always All The Time. All rights reserved.
//

#import "AATTBaseMessageInstances.h"

@interface AATTAnnotationInstances : AATTBaseMessageInstances

@property NSString *type;

- (id)initWithAnnotationType:(NSString *)type;

@end
