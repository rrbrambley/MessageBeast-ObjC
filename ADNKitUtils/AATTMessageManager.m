//
//  AATTMessageManager.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/30/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTADNDatabase.h"
#import "AATTDisplayLocation.h"
#import "AATTGeolocation.h"
#import "AATTMessageManager.h"
#import "AATTMessageManagerConfiguration.h"
#import "AATTMessagePlus.h"
#import "AATTMinMaxPair.h"
#import "AATTOrderedMessageBatch.h"
#import "ANKClient+AATTMessageManager.h"
#import "ANKMessage+AATTAnnotationHelper.h"
#import "NSOrderedDictionary.h"

@interface AATTMessageManager ()
@property NSMutableDictionary *queryParametersByChannel;
@property NSMutableDictionary *minMaxPairs;
@property NSMutableDictionary *messagesByChannelID;
@property ANKClient *client;
@property AATTMessageManagerConfiguration *configuration;
@property AATTADNDatabase *database;
@end

static CLGeocoder *geocoder;

@implementation AATTMessageManager

- (id)initWithANKClient:(ANKClient *)client configuration:(AATTMessageManagerConfiguration *)configuration {
    self = [super init];
    if(self) {
        self.client = client;
        self.configuration = configuration;
        self.queryParametersByChannel = [NSMutableDictionary dictionaryWithCapacity:1];
        self.minMaxPairs = [NSMutableDictionary dictionaryWithCapacity:1];
        self.messagesByChannelID = [NSMutableDictionary dictionaryWithCapacity:1];
        self.database = [AATTADNDatabase sharedInstance];
    }
    return self;
}

- (void)setQueryParametersForChannelWithID:(NSString *)channelID parameters:(NSDictionary *)parameters {
    [self.queryParametersByChannel setObject:parameters forKey:channelID];
}

- (NSOrderedDictionary *)loadPersistedMesssageForChannelWithID:(NSString *)channelID limit:(NSInteger)limit {
    NSDate *beforeDate = nil;
    AATTMinMaxPair *minMaxPair = [self minMaxPairForChannelID:channelID];
    if(minMaxPair.minID) {
        NSMutableOrderedDictionary *messages = [self.messagesByChannelID objectForKey:channelID];
        AATTMessagePlus *messagePlus = [messages objectForKey:minMaxPair.minID];
        beforeDate = messagePlus.displayDate;
    }
    
    AATTOrderedMessageBatch *orderedMessageBatch = [self.database messagesInChannelWithID:channelID beforeDate:beforeDate limit:limit];
    NSOrderedDictionary *messagePlusses = orderedMessageBatch.messagePlusses;
    AATTMinMaxPair *dbMinMaxPair = orderedMessageBatch.minMaxPair;
    minMaxPair = [minMaxPair combineWith:dbMinMaxPair];
    
    NSMutableOrderedDictionary *channelMessages = [messagePlusses objectForKey:channelID];
    if(channelMessages) {
        [channelMessages addEntriesFromOrderedDictionary:messagePlusses];
    } else {
        [self.messagesByChannelID setObject:messagePlusses forKey:channelID];
    }
    
    [self.minMaxPairs setObject:minMaxPair forKey:channelID];
    
    if(self.configuration.isLocationLookupEnabled) {
        [self lookupLocationForMessagePlusses:[messagePlusses allObjects] persistIfEnabled:NO];
    }
    if(self.configuration.isOEmbedLookupEnabled) {
        //TODO
    }
    
    return messagePlusses;
}

- (void)fetchMessagesInChannelWithID:(NSString *)channelID withResponseBlock:(AATTMessageManagerResponseBlock)block {
    AATTMinMaxPair *minMaxPair = [self minMaxPairForChannelID:channelID];
    [self fetchMessagesInChannelWithID:channelID sinceID:minMaxPair.maxID beforeID:minMaxPair.minID withResponseBlock:block];
}

- (void)fetchNewestMessagesInChannelWithID:(NSString *)channelID withResponseBlock:(AATTMessageManagerResponseBlock)block {
    AATTMinMaxPair *minMaxPair = [self minMaxPairForChannelID:channelID];
    [self fetchMessagesInChannelWithID:channelID sinceID:minMaxPair.maxID beforeID:nil withResponseBlock:block];
}

- (void)fetchMoreMessagesInChannelWithID:(NSString *)channelID withResponseBlock:(AATTMessageManagerResponseBlock)block {
    AATTMinMaxPair *minMaxPair = [self minMaxPairForChannelID:channelID];
    [self fetchMessagesInChannelWithID:channelID sinceID:nil beforeID:minMaxPair.minID withResponseBlock:block];
}

#pragma mark - Private stuff.

- (void)fetchMessagesInChannelWithID:(NSString *)channelID sinceID:(NSString *)sinceID beforeID:(NSString *)beforeID withResponseBlock:(AATTMessageManagerResponseBlock)block {
    NSMutableDictionary *parameters = [[self.queryParametersByChannel objectForKey:channelID] mutableCopy];
    if(sinceID) {
        [parameters setObject:sinceID forKey:@"since_id"];
    } else {
        [parameters removeObjectForKey:@"since_id"];
    }
    
    if(beforeID) {
        [parameters setObject:beforeID forKey:@"before_id"];
    } else {
        [parameters removeObjectForKey:@"before_id"];
    }
    
    [self fetchMessagesWithQueryParameters:parameters inChannelWithId:channelID withResponseBlock:block];
}

- (void)fetchMessagesWithQueryParameters:(NSDictionary *)parameters inChannelWithId:(NSString *)channelID withResponseBlock:(AATTMessageManagerResponseBlock)block {
    [self.client fetchMessagesInChannelWithID:channelID parameters:parameters completion:^(id responseObject, ANKAPIResponseMeta *meta, NSError *error) {
        BOOL appended = YES;
        NSString *beforeID = [parameters objectForKey:@"before_id"];
        NSString *sinceID = [parameters objectForKey:@"since_id"];
        
        AATTMinMaxPair *minMaxPair = [self minMaxPairForChannelID:channelID];
        if(beforeID && !sinceID) {
            NSString *newMinID = meta.minID;
            if(newMinID) {
                minMaxPair.minID = newMinID;
            }
        } else if(!beforeID && sinceID) {
            appended = NO;
            NSString *newMaxID = meta.maxID;
            if(newMaxID) {
                minMaxPair.maxID = newMaxID;
            }
        } else if(!beforeID && !sinceID) {
            minMaxPair.minID = meta.minID;
            minMaxPair.maxID = meta.maxID;
        }
        
        NSArray *responseMessages = responseObject;
        NSMutableOrderedDictionary *channelMessagePlusses = [self.messagesByChannelID objectForKey:channelID];
        if(!channelMessagePlusses) {
            channelMessagePlusses = [NSMutableOrderedDictionary orderedDictionaryWithCapacity:[responseMessages count]];
            [self.messagesByChannelID setObject:channelMessagePlusses forKey:channelID];
        }
        
        NSMutableArray *newestMessages = [NSMutableArray arrayWithCapacity:[responseMessages count]];
        NSMutableOrderedDictionary *newChannelMessages = [NSMutableOrderedDictionary orderedDictionaryWithCapacity:([channelMessagePlusses count] + [responseMessages count])];
        
        if(appended) {
            [newChannelMessages addEntriesFromOrderedDictionary:channelMessagePlusses];
        }
        for(ANKMessage *m in responseMessages) {
            AATTMessagePlus *messagePlus = [[AATTMessagePlus alloc] initWithMessage:m];
            [newestMessages addObject:messagePlus];
            [self adjustDateAndInsertMessagePlus:messagePlus];
            
            [newChannelMessages setObject:messagePlus forKey:m.messageID];
        }
        if(!appended) {
            [newChannelMessages addEntriesFromOrderedDictionary:channelMessagePlusses];
        }
        
        [self.messagesByChannelID setObject:newChannelMessages forKey:channelID];
        
        if(self.configuration.isLocationLookupEnabled) {
            [self lookupLocationForMessagePlusses:newestMessages persistIfEnabled:YES];
        }
        if(self.configuration.isOEmbedLookupEnabled) {
            //TODO
        }
        
        if(block) {
            block(newestMessages, appended, meta, error);
        }
    }];
}

- (AATTMinMaxPair *)minMaxPairForChannelID:(NSString *)channelID {
    AATTMinMaxPair *pair = [self.minMaxPairs objectForKey:channelID];
    if(!pair) {
        pair = [[AATTMinMaxPair alloc] init];
        [self.minMaxPairs setObject:pair forKey:channelID];
    }
    return pair;
}

- (void)adjustDateAndInsertMessagePlus:(AATTMessagePlus *)messagePlus {
    NSDate *adjustedDate = [self adjustedDateForMessage:messagePlus.message];
    messagePlus.displayDate = adjustedDate;
    
    if(self.configuration.isDatabaseInsertionEnabled) {
        [self.database insertOrReplaceMessage:messagePlus];
    }
}

- (NSDate *)adjustedDateForMessage:(ANKMessage *)message {
    return self.configuration.dateAdapter ? self.configuration.dateAdapter(message) : message.createdAt;
}

- (void)lookupLocationForMessagePlusses:(NSArray *)messagePlusses persistIfEnabled:(BOOL)persistIfEnabled {
    for(AATTMessagePlus *messagePlus in messagePlusses) {
        ANKMessage *message = messagePlus.message;
        
        ANKAnnotation *checkin = [message firstAnnotationOfType:kANKCoreAnnotationCheckin];
        if(checkin) {
            messagePlus.displayLocation = [AATTDisplayLocation displayLocationFromCheckinAnnotation:checkin];
            if(persistIfEnabled && self.configuration.isDatabaseInsertionEnabled) {
                [self.database insertOrReplaceDisplayLocationInstance:messagePlus];
            }
            continue;
        }
        
        ANKAnnotation *ohai = [message firstAnnotationOfType:@"net.app.ohai.location"];
        if(ohai) {
            messagePlus.displayLocation = [AATTDisplayLocation displayLocationFromOhaiLocationAnnotation:ohai];
            if(persistIfEnabled && self.configuration.isDatabaseInsertionEnabled) {
                [self.database insertOrReplaceDisplayLocationInstance:messagePlus];
            }
            continue;
        }
        
        ANKAnnotation *geolocation = [message firstAnnotationOfType:kANKCoreAnnotationGeolocation];
        if(geolocation) {
            NSNumber *latitude = [[geolocation value] objectForKey:@"latitude"];
            NSNumber *longitude = [[geolocation value] objectForKey:@"longitude"];
            AATTGeolocation *geolocation = [self.database geolocationForLatitude:[latitude doubleValue] longitude:[longitude doubleValue]];
            if(geolocation) {
                messagePlus.displayLocation = [AATTDisplayLocation displayLocationFromGeolocation:geolocation];
                
                //this might seem odd based on the fact that we just pulled the geolocation
                //from the database, but the point is to save the instance of this geolocation's
                //use - we might obtain a geolocation with this message's lat/long, but that
                //doesn't mean that this message + geolocation combo has been saved.
                //(this database lookup is merely an optimization to avoid having to fire off
                // the async task in reverseGeocode:latitude:longitude:persistIfEnabled)
                if(persistIfEnabled && self.configuration.isDatabaseInsertionEnabled) {
                    [self.database insertOrReplaceDisplayLocationInstance:messagePlus];
                }
                continue;
            } else {
                [self reverseGeocode:messagePlus latitude:[latitude doubleValue] longitude:[longitude doubleValue] persistIfEnabled:persistIfEnabled];
            }
        }
    }
}

- (void)reverseGeocode:(AATTMessagePlus *)messagePlus latitude:(double)latitude longitude:(double)longitude persistIfEnabled:(BOOL)persistIfEnabled {
    if(!geocoder) {
        geocoder = [[CLGeocoder alloc] init];
    }
    CLLocation *location = [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
    [geocoder reverseGeocodeLocation:location completionHandler:^(NSArray *placemarks, NSError *error) {
        if(!error) {
            NSString *loc = [self addressStringForPlacemarks:placemarks];
            if(loc) {
                AATTGeolocation *geolocation = [[AATTGeolocation alloc] initWithName:loc latitude:latitude longitude:longitude];
                messagePlus.displayLocation = [AATTDisplayLocation displayLocationFromGeolocation:geolocation];
                
                if(persistIfEnabled && self.configuration.isDatabaseInsertionEnabled) {
                    [self.database insertOrReplaceGeolocation:geolocation];
                    [self.database insertOrReplaceDisplayLocationInstance:messagePlus];
                }
            }
            //
            //TODO
            // call back for UI?
        } else {
            NSLog(@"%@", error.description);
        }
    }];
}

- (NSString *)addressStringForPlacemarks:(NSArray *)placemarks {
    NSString *locality = nil;
    for(CLPlacemark *placemark in placemarks) {
        NSString *subLocality = placemark.subLocality;
        if(subLocality || !locality) {
            locality = placemark.locality;
        }
        
        if(subLocality && locality) {
            return [NSString stringWithFormat:@"%@, %@", subLocality, locality];
        }
    }
    return locality;
}

@end
