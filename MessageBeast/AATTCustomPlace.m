//
//  AATTCustomPlace.m
//  MessageBeast
//
//  Created by Rob Brambley on 3/3/14.
//  Copyright (c) 2014 Always All The Time. All rights reserved.
//

#import "AATTCustomPlace.h"

@implementation AATTCustomPlace

- (id)initWithID:(NSString *)ID place:(ANKPlace *)place {
    self = [super init];
    if(self) {
        self.ID = ID;
     
        self.name = place.name;
        self.address = place.address;
        self.addressExtended = place.addressExtended;
        self.locality = place.locality;
        self.region = place.region;
        self.adminRegion = place.adminRegion;
        self.postTown = place.postTown;
        self.poBox = place.poBox;
        self.postcode = place.postcode;
        self.countryCode = place.countryCode;
        self.latitude = place.latitude;
        self.longitude = place.longitude;
        self.isOpen = place.isOpen;
        self.telephone = place.telephone;
        self.fax = place.fax;
        self.website = place.website;
        self.categories = place.categories;
    }
    return self;
}

@end
