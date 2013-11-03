//
//  AATTDisplayLocation.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/31/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AATTGeolocation;

@interface AATTDisplayLocation : NSObject

@property NSString *name;
@property NSString *factualID;
@property double latitude;
@property double longitude;

+ (AATTDisplayLocation *)displayLocationFromCheckinAnnotation:(ANKAnnotation *)checkinAnnotation;
+ (AATTDisplayLocation *)displayLocationFromOhaiLocationAnnotation:(ANKAnnotation *)ohaiLocationAnnotation;
+ (AATTDisplayLocation *)displayLocationFromGeolocation:(AATTGeolocation *)geolocation;

- (id)initWithName:(NSString *)name latitude:(double)latitude longitude:(double)longitude;

@end
