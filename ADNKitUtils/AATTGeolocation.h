//
//  AATTGeolocation.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 11/2/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AATTGeolocation : NSObject

@property NSString *name;
@property double latitude;
@property double longitude;

- (id)initWithName:(NSString *)name latitude:(double)latitude longitude:(double)longitude;

@end
