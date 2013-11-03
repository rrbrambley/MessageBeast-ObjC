//
//  AATTDisplayLocation.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/31/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTDisplayLocation.h"
#import "AATTGeolocation.h"

@implementation AATTDisplayLocation

+ (AATTDisplayLocation *)displayLocationFromCheckinAnnotation:(ANKAnnotation *)checkinAnnotation {
    NSString *name = [[checkinAnnotation value] objectForKey:@"name"];
    NSString *factualID = [[checkinAnnotation value] objectForKey:@"factual_id"];
    NSNumber *latitude = [[checkinAnnotation value] objectForKey:@"latitude"];
    NSNumber *longitude = [[checkinAnnotation value] objectForKey:@"longitude"];
    AATTDisplayLocation *loc = [[AATTDisplayLocation alloc] initWithName:name latitude:[latitude doubleValue] longitude:[longitude doubleValue]];
    loc.factualID = factualID;
    return loc;
}

+ (AATTDisplayLocation *)displayLocationFromOhaiLocationAnnotation:(ANKAnnotation *)ohaiLocationAnnotation {
    NSString *name = [[ohaiLocationAnnotation value] objectForKey:@"name"];
    NSNumber *latitude = [[ohaiLocationAnnotation value] objectForKey:@"latitude"];
    NSNumber *longitude = [[ohaiLocationAnnotation value] objectForKey:@"longitude"];
    
    if(!name) {
        if((latitude && longitude)) {
            name = [NSString stringWithFormat:@"%f, %f", [latitude doubleValue], [longitude doubleValue]];
        } else {
            //do not support nameless,geolocation-less locations. that's dumb.
            return nil;
        }
    }

    return [[AATTDisplayLocation alloc] initWithName:name latitude:[latitude doubleValue] longitude:[longitude doubleValue]];
}

+ (AATTDisplayLocation *)displayLocationFromGeolocation:(AATTGeolocation *)geolocation {
    NSString *name = geolocation.subLocality ? [NSString stringWithFormat:@"%@, %@", geolocation.subLocality, geolocation.locality] : geolocation.locality;
    AATTDisplayLocation *l = [[AATTDisplayLocation alloc] initWithName:name latitude:geolocation.latitude longitude:geolocation.longitude];
    l.shortName = geolocation.subLocality;
    return l;
}

- (id)initWithName:(NSString *)name latitude:(double)latitude longitude:(double)longitude {
    self = [super init];
    if(self) {
        self.name = name;
        self.latitude = latitude;
        self.longitude = longitude;
    }
    return self;
}

@end
