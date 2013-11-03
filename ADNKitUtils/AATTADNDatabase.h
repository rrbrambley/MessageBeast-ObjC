//
//  AATTADNDatabase.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/30/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AATTDisplayLocation, AATTDisplayLocationInstances, AATTGeolocation, AATTMessagePlus, AATTOrderedMessageBatch;

@interface AATTADNDatabase : NSObject

+ (AATTADNDatabase *)sharedInstance;

- (void)insertOrReplaceMessage:(AATTMessagePlus *)messagePlus;
- (void)insertOrReplaceDisplayLocationInstance:(AATTMessagePlus *)messagePlus;
- (void)insertOrReplaceGeolocation:(AATTGeolocation *)geolocation;

- (AATTOrderedMessageBatch *)messagesInChannelWithID:(NSString *)channelID limit:(NSUInteger)limit;
- (AATTOrderedMessageBatch *)messagesInChannelWithID:(NSString *)channelID beforeDate:(NSDate *)beforeDate limit:(NSUInteger)limit;

- (NSArray *)displayLocationInstancesInChannelWithID:(NSString *)channelID;
- (AATTGeolocation *)geolocationForLatitude:(double)latitude longitude:(double)longitude;

@end
