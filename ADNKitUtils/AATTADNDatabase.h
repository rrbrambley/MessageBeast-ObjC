//
//  AATTADNDatabase.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/30/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AATTDisplayLocation, AATTDisplayLocationInstances, AATTGeolocation, AATTHashtagInstances, AATTMessagePlus, AATTOrderedMessageBatch, NSOrderedDictionary;

typedef NS_ENUM(NSUInteger, AATTLocationPrecision) {
    AATTLocationPrecisionOneHundredMeters = 0, //actually 111 m
    AATTLocationPrecisionOneThousandMeters = 1, //actually 1.11 km
    AATTLocationPrecisionTenThousandMeters = 2 //actually 11.1 km
};

@interface AATTADNDatabase : NSObject

+ (AATTADNDatabase *)sharedInstance;

- (void)insertOrReplaceMessage:(AATTMessagePlus *)messagePlus;
- (void)insertOrReplaceDisplayLocationInstance:(AATTMessagePlus *)messagePlus;
- (void)insertOrReplaceGeolocation:(AATTGeolocation *)geolocation;
- (void)insertOrReplaceHashtagInstances:(AATTMessagePlus *)messagePlus;
- (void)insertOrReplaceOEmbedInstances:(AATTMessagePlus *)messagePlus;

- (AATTOrderedMessageBatch *)messagesInChannelWithID:(NSString *)channelID limit:(NSUInteger)limit;
- (AATTOrderedMessageBatch *)messagesInChannelWithID:(NSString *)channelID beforeDate:(NSDate *)beforeDate limit:(NSUInteger)limit;

- (NSArray *)displayLocationInstancesInChannelWithID:(NSString *)channelID;
- (AATTDisplayLocationInstances *)displayLocationInstancesInChannelWithID:(NSString *)channelID displayLocation:(AATTDisplayLocation *)displayLocation;
- (AATTDisplayLocationInstances *)displayLocationInstancesInChannelWithID:(NSString *)channelID displayLocation:(AATTDisplayLocation *)displayLocation locationPrecision:(AATTLocationPrecision)locationPrecision;

- (NSOrderedDictionary *)hashtagInstancesInChannelWithID:(NSString *)channelID;
- (NSOrderedDictionary *)hashtagInstancesInChannelWithID:(NSString *)channelID sinceDate:(NSDate *)sinceDate;
- (NSOrderedDictionary *)hashtagInstancesInChannelWithID:(NSString *)channelID beforeDate:(NSDate *)beforeDate sinceDate:(NSDate *)sinceDate;
- (AATTHashtagInstances *)hashtagInstancesInChannelWithID:(NSString *)channelID hashtagName:(NSString *)hashtagName;

- (AATTGeolocation *)geolocationForLatitude:(double)latitude longitude:(double)longitude;

@end
