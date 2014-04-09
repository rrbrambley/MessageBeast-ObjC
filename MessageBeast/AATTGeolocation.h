//
//  AATTGeolocation.h
//  MessageBeast
//
//  Created by Rob Brambley on 11/2/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AATTGeolocation : NSObject

@property NSString *locality;
@property NSString *subLocality;
@property double latitude;
@property double longitude;

- (id)initWithLocality:(NSString *)locality subLocality:(NSString *)subLocality latitude:(double)latitude longitude:(double)longitude;

- (id)initWithPlacemarks:(NSArray *)placemarks latitude:(double)latitude longitude:(double)longitude;
@end
