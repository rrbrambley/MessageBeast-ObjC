//
//  AATTMessageManager.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/30/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTMessageManager.h"
#import "AATTMessagePlus.h"
#import "ANKClient+AATTMessageManager.h"

@interface MinMaxPair : NSObject
@property NSString *minID;
@property NSString *maxID;
@end
@implementation MinMaxPair
@end

@interface AATTMessageManager ()
@property NSMutableDictionary *queryParametersByChannel;
@property NSMutableDictionary *minMaxPairs;
@property NSMutableDictionary *messages;
@property ANKClient *client;
@property AATTMessageManagerConfiguration *configuration;
@end

@implementation AATTMessageManager

- (id)initWithANKClient:(ANKClient *)client configuration:(AATTMessageManagerConfiguration *)configuration {
    self = [super init];
    if(self) {
        self.client = client;
        self.configuration = configuration;
        self.queryParametersByChannel = [NSMutableDictionary dictionaryWithCapacity:1];
        self.minMaxPairs = [NSMutableDictionary dictionaryWithCapacity:1];
        self.messages = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    return self;
}

- (void)setQueryParametersForChannelWithID:(NSString *)channelID parameters:(NSDictionary *)parameters {
    [self.queryParametersByChannel setObject:parameters forKey:channelID];
}

- (void)fetchMessagesInChannelWithID:(NSString *)channelID withResponseBlock:(AATTMessageManagerResponseBlock)block {
    MinMaxPair *minMaxPair = [self minMaxPairForChannelID:channelID];
    [self fetchMessagesInChannelWithID:channelID sinceID:minMaxPair.maxID beforeID:minMaxPair.minID withResponseBlock:block];
}

- (void)fetchNewestMessagesInChannelWithID:(NSString *)channelID withResponseBlock:(AATTMessageManagerResponseBlock)block {
    MinMaxPair *minMaxPair = [self minMaxPairForChannelID:channelID];
    [self fetchMessagesInChannelWithID:channelID sinceID:minMaxPair.maxID beforeID:nil withResponseBlock:block];
}

- (void)fetchMoreMessagesInChannelWithID:(NSString *)channelID withResponseBlock:(AATTMessageManagerResponseBlock)block {
    MinMaxPair *minMaxPair = [self minMaxPairForChannelID:channelID];
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
        
        MinMaxPair *minMaxPair = [self minMaxPairForChannelID:channelID];
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
        NSMutableArray *channelMessagePlusses = [self.messages objectForKey:channelID];
        if(!channelMessagePlusses) {
            channelMessagePlusses = [NSMutableArray arrayWithCapacity:[responseMessages count]];
            [self.messages setObject:channelMessagePlusses forKey:channelID];
        }
        
        NSMutableArray *newestMessages = [NSMutableArray arrayWithCapacity:[responseMessages count]];
        NSMutableArray *newChannelMessages = [NSMutableArray arrayWithCapacity:([channelMessagePlusses count] + [responseMessages count])];
        
        if(appended) {
            [newChannelMessages addObjectsFromArray:channelMessagePlusses];
        }
        for(ANKMessage *m in responseMessages) {
            AATTMessagePlus *messagePlus = [[AATTMessagePlus alloc] initWithMessage:m];
            [newestMessages addObject:messagePlus];
            [self adjustDateAndInsertMessagePlus:messagePlus];
        }
        if(!appended) {
            [newChannelMessages addObjectsFromArray:channelMessagePlusses];
        }
        
        [self.messages setObject:newChannelMessages forKey:channelID];
        
        if(self.configuration.isLocationLookupEnabled) {
            //TODO
        }
        if(self.configuration.isOEmbedLookupEnabled) {
            //TODO
        }
        
        if(block) {
            block(newestMessages, appended, meta, error);
        }
    }];
}

- (MinMaxPair *)minMaxPairForChannelID:(NSString *)channelID {
    MinMaxPair *pair = [self.minMaxPairs objectForKey:channelID];
    if(!pair) {
        pair = [[MinMaxPair alloc] init];
        [self.minMaxPairs setObject:pair forKey:channelID];
    }
    return pair;
}

- (void)adjustDateAndInsertMessagePlus:(AATTMessagePlus *)messagePlus {
    NSDate *adjustedDate = [self adjustedDateForMessage:messagePlus.message];
    messagePlus.displayDate = adjustedDate;
    
    if(self.configuration.isDatabaseInsertionEnabled) {
        //TODO
    }
}

- (NSDate *)adjustedDateForMessage:(ANKMessage *)message {
    return self.configuration.dateAdapter ? self.configuration.dateAdapter(message) : message.createdAt;
}

@end
