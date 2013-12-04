//
//  AATTMessageManager.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/30/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTActionMessageManager.h"
#import "AATTADNDatabase.h"
#import "AATTADNPersistence.h"
#import "AATTDisplayLocation.h"
#import "AATTDisplayLocationInstances.h"
#import "AATTGeolocation.h"
#import "AATTHashtagInstances.h"
#import "AATTMessageManager.h"
#import "AATTMessageManagerConfiguration.h"
#import "AATTMessagePlus.h"
#import "AATTMinMaxPair.h"
#import "AATTOrderedMessageBatch.h"
#import "ANKAnnotatableResource+AATTAnnotationHelper.h"
#import "ANKClient+AATTMessageManager.h"
#import "ANKClient+PrivateChannel.h"
#import "ANKChannel+AATTAnnotationHelper.h"
#import "ANKMessage+AATTAnnotationHelper.h"
#import "NSOrderedDictionary.h"

@interface AATTMessageManager ()
@property NSMutableDictionary *queryParametersByChannel;
@property NSMutableDictionary *minMaxPairs;
@property NSMutableDictionary *messagesByChannelID;
@property (nonatomic) ANKClient *client;
@property AATTMessageManagerConfiguration *configuration;
@property AATTADNDatabase *database;
@end

static NSUInteger const kSyncBatchSize = 100;

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

#pragma mark Getters

- (ANKClient *)client {
    return _client;
}

- (AATTChannelFullSyncState)fullSyncStateForChannelWithID:(NSString *)channelID {
    return [AATTADNPersistence fullSyncStateForChannelWithID:channelID];
}

- (AATTChannelFullSyncState)fullSyncStateForChannels:(NSArray *)channels {
    AATTChannelFullSyncState state = AATTChannelFullSyncStateComplete;
    for(ANKChannel *channel in channels) {
        AATTChannelFullSyncState thisChannelState = [self fullSyncStateForChannelWithID:channel.channelID];
        if(thisChannelState == AATTChannelFullSyncStateStarted) {
            return AATTChannelFullSyncStateStarted;
        } else if(thisChannelState == AATTChannelFullSyncStateNotStarted) {
            state = AATTChannelFullSyncStateNotStarted;
        }
    }
    return state;
}

- (NSArray *)loadedMessagesForChannelWithID:(NSString *)channelID {
    NSOrderedDictionary *messages = [self.messagesByChannelID objectForKey:channelID];
    if(messages.count == 0) {
        return nil;
    }
    return [messages allObjects];
}

#pragma mark Setters

- (void)setQueryParametersForChannelWithID:(NSString *)channelID parameters:(NSDictionary *)parameters {
    [self.queryParametersByChannel setObject:parameters forKey:channelID];
}

- (void)setFullSyncState:(AATTChannelFullSyncState)fullSyncState forChannelWithID:(NSString *)channelID {
    [AATTADNPersistence saveFullSyncState:fullSyncState channelID:channelID];
}

#pragma mark Load Messages

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
    return messagePlusses;
}

- (NSOrderedDictionary *)loadPersistedMessagesTemporarilyForChannelWithID:(NSString *)channelID displayLocation:(AATTDisplayLocation *)displayLocation locationPrecision:(AATTLocationPrecision)locationPrecision {
    AATTDisplayLocationInstances *instances = [self.database displayLocationInstancesInChannelWithID:channelID displayLocation:displayLocation locationPrecision:locationPrecision];
    return [self loadPersistedMessagesTemporarilyForChannelWithID:channelID messageIDs:instances.messageIDs.set];
}

- (NSOrderedDictionary *)loadPersistedMessagesTemporarilyForChannelWithID:(NSString *)channelID hashtagName:(NSString *)hashtagName {
    AATTHashtagInstances *hashtagInstances = [self.database hashtagInstancesInChannelWithID:channelID hashtagName:hashtagName];
    return [self loadPersistedMessagesTemporarilyForChannelWithID:channelID messageIDs:hashtagInstances.messageIDs.set];
}

- (NSOrderedDictionary *)loadPersistedMessagesTemporarilyForChannelWithID:(NSString *)channelID messageIDs:(NSSet *)messageIDs {
    AATTOrderedMessageBatch *messageBatch = [self.database messagesInChannelWithID:channelID messageIDs:messageIDs];
    NSOrderedDictionary *messagePlusses = messageBatch.messagePlusses;
    
    if(self.configuration.isLocationLookupEnabled) {
        [self lookupLocationForMessagePlusses:messagePlusses.allObjects persistIfEnabled:NO];
    }
    
    return messagePlusses;
}

#pragma mark Fetch Messages

- (void)fetchAndPersistAllMessagesInChannels:(NSArray *)channels completionBlock:(AATTMessageManagerMultiChannelSyncBlock)block {
    int i = 0;
    while(i < channels.count && [self fullSyncStateForChannelWithID:[channels objectAtIndex:i]] == AATTChannelFullSyncStateComplete) {
        i++;
    }
    if(i == channels.count) {
        block(YES, nil);
    } else {
        [self fetchAndPersistAllMessagesInChannels:channels currentChannelIndex:i completionBlock:block];
    }
}

- (void)fetchAndPersistAllMessagesInChannels:(NSArray *)channels currentChannelIndex:(NSInteger)currentChannelIndex completionBlock:(AATTMessageManagerMultiChannelSyncBlock)block {
    
    AATTMessageManagerCompletionBlock currentChannelSyncBlock = ^(NSArray *messagePlusses, BOOL appended, ANKAPIResponseMeta *meta, NSError *error) {
        if(error) {
            block(NO, error);
        } else {
            NSInteger i = currentChannelIndex + 1;
            while(i < channels.count && [self fullSyncStateForChannelWithID:[channels objectAtIndex:i]] == AATTChannelFullSyncStateComplete) {
                i++;
            }
            if(i == channels.count) {
                block(YES, nil);
            } else {
                [self fetchAndPersistAllMessagesInChannels:channels currentChannelIndex:i completionBlock:block];
            }
        }
    };
    
    ANKChannel *nextChannel = [channels objectAtIndex:currentChannelIndex];
    NSString *type = nextChannel.type;
    if([kChannelTypeAction isEqualToString:type]) {
        NSString *targetChannelID = [nextChannel targetChannelID];
        AATTActionMessageManager *actionMessageManager = [AATTActionMessageManager sharedInstanceWithMessageManager:self];
        [actionMessageManager fetchAndPersistAllMessagesInActionChannelWithID:nextChannel.channelID targetChannelId:targetChannelID completionBlock:currentChannelSyncBlock];
    } else {
        [self fetchAndPersistAllMessagesInChannelWithID:nextChannel.channelID batchSyncBlock:nil completionBlock:currentChannelSyncBlock];
    }
}

- (void)fetchAndPersistAllMessagesInChannelWithID:(NSString *)channelID batchSyncBlock:(AATTMessageManagerBatchSyncBlock)batchSyncBlock completionBlock:(AATTMessageManagerCompletionBlock)block {
    if(!self.configuration.isDatabaseInsertionEnabled) {
        [NSException raise:@"Illegal state" format:@"fetchAndPersistAllMessagesInChannelWithID:completionBlock: can only be executed if the AATTMessageManagerConfiguration.isDatabaseInsertionEnabled property is set to YES"];
    } else {
        NSMutableArray *messages = [[NSMutableArray alloc] initWithCapacity:kSyncBatchSize];
        [self setFullSyncState:AATTChannelFullSyncStateStarted forChannelWithID:channelID];
        [self fetchAllMessagesInChannelWithID:channelID messagePlusses:messages sinceID:nil beforeID:nil batchSyncBlock:batchSyncBlock block:block];
    }
}

- (void)fetchMessagesInChannelWithID:(NSString *)channelID completionBlock:(AATTMessageManagerCompletionBlock)block {
    AATTMinMaxPair *minMaxPair = [self minMaxPairForChannelID:channelID];
    [self fetchMessagesInChannelWithID:channelID sinceID:minMaxPair.maxID beforeID:minMaxPair.minID completionBlock:block];
}

- (void)fetchNewestMessagesInChannelWithID:(NSString *)channelID completionBlock:(AATTMessageManagerCompletionBlock)block {
    AATTMinMaxPair *minMaxPair = [self minMaxPairForChannelID:channelID];
    [self fetchMessagesInChannelWithID:channelID sinceID:minMaxPair.maxID beforeID:nil completionBlock:block];
}

- (void)fetchMoreMessagesInChannelWithID:(NSString *)channelID completionBlock:(AATTMessageManagerCompletionBlock)block {
    AATTMinMaxPair *minMaxPair = [self minMaxPairForChannelID:channelID];
    [self fetchMessagesInChannelWithID:channelID sinceID:nil beforeID:minMaxPair.minID completionBlock:block];
}

- (void)refreshMessagePlus:(AATTMessagePlus *)messagePlus completionBlock:(AATTMessageManagerRefreshCompletionBlock)block {
    NSString *channelID = messagePlus.message.channelID;
    NSMutableDictionary *parameters = [self.queryParametersByChannel objectForKey:channelID];
    [self.client fetchMessageWithID:messagePlus.message.messageID inChannelWithID:channelID parameters:parameters completion:^(id responseObject, ANKAPIResponseMeta *meta, NSError *error) {
        if(!error) {
            AATTMessagePlus *messagePlus = [[AATTMessagePlus alloc] initWithMessage:responseObject];
            [self adjustDateAndInsertMessagePlus:messagePlus];
            
            NSMutableOrderedDictionary *channelMessages = [self.messagesByChannelID objectForKey:messagePlus.message.channelID];
            if(channelMessages) { //could be nil if the channel messages weren't loaded first, etc.
                [channelMessages setObject:messagePlus forKey:messagePlus.message.messageID];
            }
            block(messagePlus, meta, error);
        }
    }];
}

#pragma mark - Delete Messages

- (void)deleteMessage:(AATTMessagePlus *)messagePlus completionBlock:(AATTMessageManagerDeletionCompletionBlock)block {
    [self.client deleteMessage:messagePlus.message completion:^(id responseObject, ANKAPIResponseMeta *meta, NSError *error) {
       
        if(!error) {
            NSMutableOrderedDictionary *channelMessages = [self.messagesByChannelID objectForKey:messagePlus.message.channelID];
            if(channelMessages) {
                [channelMessages removeEntryWithObject:messagePlus pairedWithKey:messagePlus.message.messageID];
            }
            [self.database deleteMessagePlus:messagePlus];
            block(meta, error);
        } else {
            block(meta, error);
        }
    }];
}

#pragma mark - Private Stuff

///
/// this is only meant to be used with fetchAndPersistAllMessagesInChannelWithID
///
- (void)fetchAllMessagesInChannelWithID:(NSString *)channelID messagePlusses:(NSMutableArray *)messages sinceID:(NSString *)sinceID beforeID:(NSString *)beforeID batchSyncBlock:(AATTMessageManagerBatchSyncBlock)batchSyncBlock block:(AATTMessageManagerCompletionBlock)block {
    NSMutableDictionary *parameters = [[self.queryParametersByChannel objectForKey:channelID] mutableCopy];
    if(sinceID) {
        [parameters setObject:sinceID forKey:@"since_id"];
    }
    if(beforeID) {
        [parameters setObject:beforeID forKey:@"before_id"];
    }
    [parameters setObject:[NSNumber numberWithUnsignedInteger:kSyncBatchSize] forKey:@"count"];
    
    BOOL keepInMemory = messages.count == 0;
    
    [self fetchMessagesWithQueryParameters:parameters inChannelWithId:channelID keepInMemory:keepInMemory completionBlock:^(NSArray *messagePlusses, BOOL appended, ANKAPIResponseMeta *meta, NSError *error) {
        if(!error) {
            if(messages.count == 0) {
                [messages addObjectsFromArray:messagePlusses];
            }
            if(messagePlusses.count > 0) {
                AATTMessagePlus *p1 = [messagePlusses objectAtIndex:0];
                AATTMessagePlus *p2 = [messagePlusses lastObject];
                NSLog(@"synced messages %@ through %@", p1.message.messageID, p2.message.messageID);
            }
            if(batchSyncBlock != nil) {
                batchSyncBlock(messagePlusses, meta, error);
            }
            
            if(meta.moreDataAvailable) {
                //never rely on MinMaxPair for min id here because
                //when keepInMemory = false, the MinMaxPair will not change
                //(and this would keep requesting the same batch over and over).
                AATTMessagePlus *minMessage = [messagePlusses lastObject];
                [self fetchAllMessagesInChannelWithID:channelID messagePlusses:messages sinceID:nil beforeID:minMessage.message.messageID batchSyncBlock:(AATTMessageManagerBatchSyncBlock)batchSyncBlock block:block];
            } else {
                NSLog(@"Setting full sync state to COMPLETE for channel %@", channelID);
                [self setFullSyncState:AATTChannelFullSyncStateComplete forChannelWithID:channelID];
                block(messages, YES, meta, error);
            }
        } else {
            block(messages, YES, meta, error);
        }
    }];
}

- (void)fetchMessagesInChannelWithID:(NSString *)channelID sinceID:(NSString *)sinceID beforeID:(NSString *)beforeID completionBlock:(AATTMessageManagerCompletionBlock)block {
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
    
    [self fetchMessagesWithQueryParameters:parameters inChannelWithId:channelID keepInMemory:YES completionBlock:block];
}

- (void)fetchMessagesWithQueryParameters:(NSDictionary *)parameters inChannelWithId:(NSString *)channelID keepInMemory:(BOOL)keepInMemory completionBlock:(AATTMessageManagerCompletionBlock)block {
    [self.client fetchMessagesInChannelWithID:channelID parameters:parameters completion:^(id responseObject, ANKAPIResponseMeta *meta, NSError *error) {
        BOOL appended = YES;
        NSString *beforeID = [parameters objectForKey:@"before_id"];
        NSString *sinceID = [parameters objectForKey:@"since_id"];
        
        AATTMinMaxPair *minMaxPair = [self minMaxPairForChannelID:channelID];
        if(beforeID && !sinceID && keepInMemory) {
            NSString *newMinID = meta.minID;
            if(newMinID) {
                minMaxPair.minID = newMinID;
            }
        } else if(!beforeID && sinceID) {
            appended = NO;
            if(keepInMemory) {
                NSString *newMaxID = meta.maxID;
                if(newMaxID) {
                    minMaxPair.maxID = newMaxID;
                }
            }
        } else if(!beforeID && !sinceID && keepInMemory) {
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
        
        if(keepInMemory) {
            [self.messagesByChannelID setObject:newChannelMessages forKey:channelID];
        }
        
        if(self.configuration.isLocationLookupEnabled) {
            [self lookupLocationForMessagePlusses:newestMessages persistIfEnabled:YES];
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
        [self.database insertOrReplaceHashtagInstances:messagePlus];
        [self.database insertOrReplaceOEmbedInstances:messagePlus];
    }
}

- (NSDate *)adjustedDateForMessage:(ANKMessage *)message {
    return self.configuration.dateAdapter ? self.configuration.dateAdapter(message) : message.createdAt;
}

#pragma mark Location Lookup

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
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    CLLocation *location = [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
    [geocoder reverseGeocodeLocation:location completionHandler:^(NSArray *placemarks, NSError *error) {
        if(!error) {
            AATTGeolocation *geolocation = [self geolocationForPlacemarks:placemarks latitude:latitude longitude:longitude];
            if(geolocation) {
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

- (AATTGeolocation *)geolocationForPlacemarks:(NSArray *)placemarks latitude:(double)latitude longitude:(double)longitude {
    NSString *subLocality = nil;
    NSString *locality = nil;
    for(CLPlacemark *placemark in placemarks) {
        if(!subLocality) {
            subLocality = placemark.subLocality;
        }
        if(subLocality || !locality) {
            locality = placemark.locality;
        }
        if(subLocality && locality) {
            break;
        }
    }
    if(subLocality || locality) {
        return [[AATTGeolocation alloc] initWithLocality:locality subLocality:subLocality latitude:latitude longitude:longitude];
    }
    return nil;
}

@end
