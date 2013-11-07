//
//  AATTDisplayLocation.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/31/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AATTGeolocation;

typedef NS_ENUM(NSUInteger, AATTDisplayLocationType) {
    AATTDisplayLocationTypeUnknown = 0,
    AATTDisplayLocationTypeCheckin = 1,
    AATTDisplayLocationTypeOhai = 2,
    AATTDisplayLocationTypeGeolocation = 3
};

@interface AATTDisplayLocation : NSObject

@property NSString *name;
@property NSString *shortName;
@property NSString *factualID;
@property double latitude;
@property double longitude;
@property AATTDisplayLocationType type;

+ (AATTDisplayLocation *)displayLocationFromCheckinAnnotation:(ANKAnnotation *)checkinAnnotation;
+ (AATTDisplayLocation *)displayLocationFromOhaiLocationAnnotation:(ANKAnnotation *)ohaiLocationAnnotation;
+ (AATTDisplayLocation *)displayLocationFromGeolocation:(AATTGeolocation *)geolocation;

- (id)initWithName:(NSString *)name latitude:(double)latitude longitude:(double)longitude;

@end
