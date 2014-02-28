//
//  AATTMessageManager.m
//  MessageBeast
//
//  Created by Rob Brambley on 10/30/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>

#import "AATTActionMessageManager.h"
#import "AATTADNDatabase.h"
#import "AATTADNPersistence.h"
#import "AATTAnnotationInstances.h"
#import "AATTDisplayLocation.h"
#import "AATTDisplayLocationInstances.h"
#import "AATTADNFileManager.h"
#import "AATTFilteredMessageBatch.h"
#import "AATTGeolocation.h"
#import "AATTHashtagInstances.h"
#import "AATTMessageManager.h"
#import "AATTMessageManagerConfiguration.h"
#import "AATTMessagePlus.h"
#import "AATTMinMaxPair.h"
#import "AATTOrderedMessageBatch.h"
#import "AATTPendingMessageDeletion.h"
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
@property NSMutableDictionary *unsentMessagesByChannelID;
@property NSMutableDictionary *messageIDsNeedingPendingFiles;
@property (nonatomic) ANKClient *client;
@property AATTMessageManagerConfiguration *configuration;
@property AATTADNDatabase *database;
@property AATTADNFileManager *fileManager;
@end

static NSUInteger const kSyncBatchSize = 100;

NSString *const AATTMessageManagerDidSendUnsentMessagesNotification = @"AATTMessageManagerDidSendUnsentMessagesNotification";

NSString *const AATTMessageManagerDidFailToSendUnsentMessagesNotification = @"AATTMessageManagerDidFailToSendUnsentMessagesNotification";

@implementation AATTMessageManager

- (id)initWithANKClient:(ANKClient *)client configuration:(AATTMessageManagerConfiguration *)configuration {
    self = [super init];
    if(self) {
        self.client = client;
        self.configuration = configuration;
        self.queryParametersByChannel = [NSMutableDictionary dictionaryWithCapacity:1];
        self.minMaxPairs = [NSMutableDictionary dictionaryWithCapacity:1];
        self.messagesByChannelID = [NSMutableDictionary dictionaryWithCapacity:1];
        self.unsentMessagesByChannelID = [NSMutableDictionary dictionaryWithCapacity:1];
        self.messageIDsNeedingPendingFiles = [NSMutableDictionary dictionary];
        self.database = [AATTADNDatabase sharedInstance];
        self.fileManager = [[AATTADNFileManager alloc] initWithClient:client];
    }
    return self;
}

#pragma mark - Getters

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

#pragma mark - Setters

- (void)setQueryParametersForChannelWithID:(NSString *)channelID parameters:(NSDictionary *)parameters {
    [self.queryParametersByChannel setObject:parameters forKey:channelID];
}

- (void)setFullSyncState:(AATTChannelFullSyncState)fullSyncState forChannelWithID:(NSString *)channelID {
    [AATTADNPersistence saveFullSyncState:fullSyncState channelID:channelID];
}

#pragma mark - Load Messages

- (NSOrderedDictionary *)loadPersistedMesssageForChannelWithID:(NSString *)channelID limit:(NSUInteger)limit {
    AATTOrderedMessageBatch *batch = [self loadPersistedMessageBatchForChannelWithID:channelID limit:limit performLookups:YES];
    return batch.messagePlusses;
}

- (AATTFilteredMessageBatch *)loadPersistedMesssageForChannelWithID:(NSString *)channelID limit:(NSInteger)limit messageFilter:(AATTMessageFilter)messageFilter {
    AATTOrderedMessageBatch *batch = [self loadPersistedMessageBatchForChannelWithID:channelID limit:limit performLookups:NO];
    AATTFilteredMessageBatch *filteredBatch = [AATTFilteredMessageBatch filteredMessageBatchWithOrderedMessageBatch:batch messageFilter:messageFilter];
    NSOrderedDictionary *excludedMessages = filteredBatch.excludedMessages;
    
    //remove the excluded messages from the main channel message dictionary.
    NSMutableOrderedDictionary *channelMessages = [self.messagesByChannelID objectForKey:channelID];
    [self removeExcludedMessages:excludedMessages fromDictionary:channelMessages];
    
    //do this after we have successfully filtered out stuff,
    //as to not perform lookups on things we didn't keep.
    [self performLookupsOnMessagePlusses:filteredBatch.messagePlusses.allObjects persist:NO];
    
    return filteredBatch;
}

#pragma mark - Get Persisted Messages

- (NSOrderedDictionary *)persistedMessagesForChannelWithID:(NSString *)channelID displayLocation:(AATTDisplayLocation *)displayLocation locationPrecision:(AATTLocationPrecision)locationPrecision {
    AATTDisplayLocationInstances *instances = [self.database displayLocationInstancesInChannelWithID:channelID displayLocation:displayLocation locationPrecision:locationPrecision];
    return [self persistedMessagesWithMessageIDs:instances.messageIDs.set];
}

- (NSOrderedDictionary *)persistedMessagesForChannelWithID:(NSString *)channelID hashtagName:(NSString *)hashtagName {
    AATTHashtagInstances *hashtagInstances = [self.database hashtagInstancesInChannelWithID:channelID hashtagName:hashtagName];
    return [self persistedMessagesWithMessageIDs:hashtagInstances.messageIDs.set];
}

- (AATTMessagePlus *)persistedMessageWithID:(NSString *)messageID {
    AATTMessagePlus *messagePlus = [self.database messagePlusForMessageID:messageID];
    if(messagePlus) {
        [self performLookupsOnMessagePlusses:@[messagePlus] persist:NO];
    }
    return messagePlus;
}

- (NSOrderedDictionary *)persistedMessagesWithMessageIDs:(NSSet *)messageIDs {
    AATTOrderedMessageBatch *messageBatch = [self.database messagesWithIDs:messageIDs];
    NSOrderedDictionary *messagePlusses = messageBatch.messagePlusses;
    [self performLookupsOnMessagePlusses:messagePlusses.allObjects persist:NO];
    return messagePlusses;
}

- (NSOrderedDictionary *)persistedMessagesForChannelWithID:(NSString *)channelID annotationType:(NSString *)annotationType {
    AATTAnnotationInstances *annotationInstances = [self.database annotationInstancesOfType:annotationType inChannelWithID:channelID];
    return [self persistedMessagesWithMessageIDs:annotationInstances.messageIDs.set];
}

#pragma mark - Search

- (AATTOrderedMessageBatch *)searchMessagesWithQuery:(NSString *)query inChannelWithID:(NSString *)channelID {
    AATTOrderedMessageBatch *batch = [self.database messagesInChannelWithID:channelID searchQuery:query];
    [self performLookupsOnMessagePlusses:batch.messagePlusses.allObjects persist:NO];
    return batch;
}

- (AATTOrderedMessageBatch *)searchMessagesWithDisplayLocationQuery:(NSString *)displayLocationQuery inChannelWithID:(NSString *)channelID {
    AATTOrderedMessageBatch *batch = [self.database messagesInChannelWithID:channelID displayLocationSearchQuery:displayLocationQuery];
    [self performLookupsOnMessagePlusses:batch.messagePlusses.allObjects persist:NO];
    return batch;
}

#pragma mark - Fetch Messages

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
    
    AATTMessageManagerCompletionBlock currentChannelSyncBlock = ^(NSArray *messagePlusses, ANKAPIResponseMeta *meta, NSError *error) {
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
        AATTActionMessageManager *actionMessageManager = [AATTActionMessageManager sharedInstanceWithMessageManager:self];
        [actionMessageManager fetchAndPersistAllMessagesInActionChannelWithID:nextChannel.channelID completionBlock:currentChannelSyncBlock];
    } else {
        [self fetchAndPersistAllMessagesInChannelWithID:nextChannel.channelID batchSyncBlock:nil completionBlock:currentChannelSyncBlock];
    }
}

- (void)fetchAndPersistAllMessagesInChannelWithID:(NSString *)channelID batchSyncBlock:(AATTMessageManagerBatchSyncBlock)batchSyncBlock completionBlock:(AATTMessageManagerCompletionBlock)block {
    NSMutableArray *messages = [[NSMutableArray alloc] initWithCapacity:kSyncBatchSize];
    [self setFullSyncState:AATTChannelFullSyncStateStarted forChannelWithID:channelID];
    [self fetchAllMessagesInChannelWithID:channelID messagePlusses:messages sinceID:nil beforeID:nil batchSyncBlock:batchSyncBlock block:block];
}

- (BOOL)fetchMessagesInChannelWithID:(NSString *)channelID completionBlock:(AATTMessageManagerCompletionBlock)block {
    AATTMinMaxPair *minMaxPair = [self minMaxPairForChannelID:channelID];
    return [self fetchMessagesInChannelWithID:channelID sinceID:minMaxPair.maxID beforeID:minMaxPair.minID messageFilter:nil completionBlock:block filterBlock:nil];
}

- (BOOL)fetchMessagesInChannelWithID:(NSString *)channelID messageFilter:(AATTMessageFilter)messageFilter completionBlock:(AATTMessageManagerCompletionWithFilterBlock)block {
    AATTMinMaxPair *minMaxPair = [self minMaxPairForChannelID:channelID];
    return [self fetchMessagesInChannelWithID:channelID sinceID:minMaxPair.maxID beforeID:minMaxPair.minID messageFilter:messageFilter completionBlock:nil filterBlock:block];
}

- (BOOL)fetchNewestMessagesInChannelWithID:(NSString *)channelID completionBlock:(AATTMessageManagerCompletionBlock)block {
    AATTMinMaxPair *minMaxPair = [self minMaxPairForChannelID:channelID];
    return [self fetchMessagesInChannelWithID:channelID sinceID:minMaxPair.maxID beforeID:nil messageFilter:nil completionBlock:block filterBlock:nil];
}

- (BOOL)fetchNewestMessagesInChannelWithID:(NSString *)channelID messageFilter:(AATTMessageFilter)messageFilter completionBlock:(AATTMessageManagerCompletionWithFilterBlock)block {
    AATTMinMaxPair *minMaxPair = [self minMaxPairForChannelID:channelID];
    return [self fetchMessagesInChannelWithID:channelID sinceID:minMaxPair.maxID beforeID:nil messageFilter:messageFilter completionBlock:nil filterBlock:nil];
}

- (BOOL)fetchMoreMessagesInChannelWithID:(NSString *)channelID completionBlock:(AATTMessageManagerCompletionBlock)block {
    AATTMinMaxPair *minMaxPair = [self minMaxPairForChannelID:channelID];
    return [self fetchMessagesInChannelWithID:channelID sinceID:nil beforeID:minMaxPair.minID messageFilter:nil completionBlock:block filterBlock:nil];
}

- (BOOL)fetchMoreMessagesInChannelWithID:(NSString *)channelID messageFilter:(AATTMessageFilter)messageFilter completionBlock:(AATTMessageManagerCompletionWithFilterBlock)block {
    AATTMinMaxPair *minMaxPair = [self minMaxPairForChannelID:channelID];
    return [self fetchMessagesInChannelWithID:channelID sinceID:nil beforeID:minMaxPair.minID messageFilter:messageFilter completionBlock:nil filterBlock:block];
}

- (void)refreshMessagePlus:(AATTMessagePlus *)messagePlus completionBlock:(AATTMessageManagerRefreshCompletionBlock)block {
    NSString *channelID = messagePlus.message.channelID;
    NSMutableDictionary *parameters = [self.queryParametersByChannel objectForKey:channelID];
    [self.client fetchMessageWithID:messagePlus.message.messageID inChannelWithID:channelID parameters:parameters completion:^(id responseObject, ANKAPIResponseMeta *meta, NSError *error) {
        if(!error) {
            AATTMessagePlus *messagePlus = [[AATTMessagePlus alloc] initWithMessage:responseObject];
            [self adjustDateForMessagePlus:messagePlus];
            
            NSMutableOrderedDictionary *channelMessages = [self.messagesByChannelID objectForKey:messagePlus.message.channelID];
            if(channelMessages) { //could be nil if the channel messages weren't loaded first, etc.
                [channelMessages setObject:messagePlus forKey:messagePlus.displayDate];
            }
            
            [self insertMessagePlus:messagePlus];
            [self performLookupsOnMessagePlusses:@[messagePlus] persist:YES];

            block(messagePlus, meta, error);
        }
    }];
}

#pragma mark - Delete Messages

- (void)deleteMessage:(AATTMessagePlus *)messagePlus completionBlock:(AATTMessageManagerDeletionCompletionBlock)block {
    [self deleteMessage:messagePlus deleteAssociatedFiles:NO completionBlock:block];
}

- (void)deleteMessage:(AATTMessagePlus *)messagePlus deleteAssociatedFiles:(BOOL)deleteAssociatedFiles completionBlock:(AATTMessageManagerDeletionCompletionBlock)block {
    if(messagePlus.isUnsent) {
        ANKMessage *message = messagePlus.message;
        NSString *channelID = message.channelID;
        
        [self.database deleteMessagePlus:messagePlus];
        
        NSMutableOrderedDictionary *unsentChannelMessages = [self existingOrNewUnsentMessagesDictionaryforChannelWithID:channelID];
        if([unsentChannelMessages objectForKey:messagePlus.displayDate]) {
            [unsentChannelMessages removeEntryWithKey:messagePlus.displayDate];
        }
        [self deleteFromChannelMapAndUpdateMinMaxPairForMessagePlus:messagePlus];
        
        block(nil, nil);
    } else {
        void (^finishDelete)(void) = ^void(void) {
            [self.database deleteMessagePlus:messagePlus];
            [self deleteFromChannelMapAndUpdateMinMaxPairForMessagePlus:messagePlus];
        };
        
        void (^deleteMessage)(void) = ^void(void) {
            [self.client deleteMessage:messagePlus.message completion:^(id responseObject, ANKAPIResponseMeta *meta, NSError *error) {
                if(!error) {
                    finishDelete();
                    [self.database deletePendingMessageDeletionForMessageWithID:messagePlus.message.messageID];
                    block(meta, error);
                } else {
                    finishDelete();
                    [self.database insertOrReplacePendingDeletionForMessagePlus:messagePlus];
                    block(meta, error);
                }
            }];
        };
        
        if(deleteAssociatedFiles) {
            NSArray *OEmbedAnnotations = [messagePlus.message annotationsWithType:kANKCoreAnnotationEmbeddedMedia];
            [self deleteOEmbedAtIndex:0 OEmbedAnnoations:OEmbedAnnotations completionBlock:^{
                NSArray *attachmentAnnotations = [messagePlus.message annotationsWithType:kANKCoreAnnotationAttachments];
                [self deleteAttachmentsListAtIndex:0 attachmentsAnnotations:attachmentAnnotations completionBlock:deleteMessage];
            }];
        } else {
            deleteMessage();
        }
    }
}

#pragma mark - Create Messages

- (void)createMessageInChannelWithID:(NSString *)channelID message:(ANKMessage *)message completionBlock:(AATTMessageManagerCompletionBlock)block {
    
    [self.client createMessage:message inChannelWithID:channelID completion:^(id responseObject, ANKAPIResponseMeta *meta, NSError *error) {
        if(error) {
            block(responseObject, meta, error);
        } else {
            [self fetchNewestMessagesInChannelWithID:channelID completionBlock:block];
        }
    }];
}

- (AATTMessagePlus *)createUnsentMessageAndAttemptSendInChannelWithID:(NSString *)channelID message:(ANKMessage *)message {
    return [self createUnsentMessageAndAttemptSendInChannelWithID:channelID message:message pendingFileAttachments:[NSArray array]];
}

- (AATTMessagePlus *)createUnsentMessageAndAttemptSendInChannelWithID:(NSString *)channelID message:(ANKMessage *)message pendingFileAttachments:(NSArray *)pendingFileAttachments {
    
    //An unsent message id is always set to the max id + 1.
    //
    //This will work because we will never allow message retrieval to happen
    //until unsent messages are sent to the server and they get their "real"
    //message id. After they reach the server, we will delete them from existence
    //on the client and retrieve them from the server.
    //
    NSOrderedDictionary *channelMessages = [self existingOrNewMessagesDictionaryforChannelWithID:channelID];
    if(channelMessages.count == 0) {
        //we do this so that the max id is known.
        [self loadPersistedMesssageForChannelWithID:channelID limit:1];
    }
    
    NSInteger maxID = [self.database maxMessageID];
    NSInteger newMessageID = maxID + 1;
    NSString *newMessageIDString = [NSString stringWithFormat:@"%ld", (long)newMessageID];
    
    AATTMessagePlus *unsentMessagePlus = [AATTMessagePlus unsentMessagePlusForChannelWithID:channelID messageID:newMessageIDString message:message pendingFileAttachments:pendingFileAttachments];
    [self.database insertOrReplaceMessage:unsentMessagePlus];
    
    //TODO: handle display location
    
    NSMutableOrderedDictionary *unsentChannelMessages = [self existingOrNewUnsentMessagesDictionaryforChannelWithID:channelID];
    [unsentChannelMessages setObject:unsentMessagePlus forKey:unsentMessagePlus.displayDate];
    
    NSMutableOrderedDictionary *newChannelMessages = [NSMutableOrderedDictionary orderedDictionaryWithCapacity:channelMessages.count + 1];
    [newChannelMessages setObject:unsentMessagePlus forKey:unsentMessagePlus.displayDate];
    [newChannelMessages addEntriesFromOrderedDictionary:channelMessages];
    [self.messagesByChannelID setObject:newChannelMessages forKey:channelID];
    
    //update the MinMaxPair
    //we can assume the new id is the max (that's how we generated it)
    //but we have to check to see if the time is min or max
    AATTMinMaxPair *minMaxPair = [self minMaxPairForChannelID:channelID];
    [minMaxPair expandDateIfMinOrMaxForDate:unsentMessagePlus.displayDate];
    minMaxPair.maxID = newMessageIDString;
    
    [self sendUnsentMessagesInChannelWithID:channelID];
    
    return unsentMessagePlus;
}

#pragma mark - Send Unsent

- (void)sendAllUnsentForChannelWithID:(NSString *)channelID {
    [self sendPendingDeletionsInChannelWithID:channelID completionBlock:^(ANKAPIResponseMeta *meta, NSError *error) {
        [self sendUnsentMessagesInChannelWithID:channelID];
    }];
}

- (BOOL)sendUnsentMessagesInChannelWithID:(NSString *)channelID {
    NSMutableOrderedDictionary *unsentMessages = [self existingOrNewUnsentMessagesDictionaryforChannelWithID:channelID];
    if(unsentMessages.count > 0) {
        NSMutableOrderedDictionary *channelMessages = [self existingOrNewMessagesDictionaryforChannelWithID:channelID];
        if(channelMessages.count == 0) {
            [self loadPersistedMesssageForChannelWithID:channelID limit:(unsentMessages.count + 1)];
        }
        NSMutableArray *sentMessageIDs = [NSMutableArray arrayWithCapacity:unsentMessages.count];
        [self sendUnsentMessages:unsentMessages sentMessageIDs:sentMessageIDs];
        return YES;
    }
    return NO;
}

- (void)sendUnsentMessages:(NSMutableOrderedDictionary *)unsentMessages sentMessageIDs:(NSMutableArray *)sentMessageIDs {
    AATTMessagePlus *messagePlus = unsentMessages.objectEnumerator.nextObject;
    if(messagePlus.pendingFileAttachments.count > 0) {
        NSString *pendingFileID = messagePlus.pendingFileAttachments.allKeys.objectEnumerator.nextObject;
        NSMutableSet *messagesNeedingPendingFile = [self existingOrNewMessageIDsNeedingPendingFileSetForFileWithID:pendingFileID];
        [messagesNeedingPendingFile addObject:messagePlus.message.messageID];
        [self uploadPendingFileAttachmentWithPendingFileID:pendingFileID forMessageInChannelWithID:messagePlus.message.channelID];
        return;
    } else {
        ANKMessage *message = messagePlus.message.copy;
        
        //we had them set for display locally, but we should
        //let the server generate the "real" entities.
        message.entities = nil;
        
        [self.client createMessage:message inChannelWithID:message.channelID parameters:[self.queryParametersByChannel objectForKey:message.channelID] completion:^(id responseObject, ANKAPIResponseMeta *meta, NSError *error) {
            if(!error) {
                [unsentMessages removeEntryWithKey:messagePlus.displayDate];
                [sentMessageIDs addObject:message.messageID];
                
                [self.database deleteMessagePlus:messagePlus];
                
                [self deleteFromChannelMapAndUpdateMinMaxPairForMessagePlus:messagePlus];
                
                if(unsentMessages.count > 0) {
                    [self sendUnsentMessages:unsentMessages sentMessageIDs:sentMessageIDs];
                } else {
                    NSDictionary *userInfo = @{@"channelID" : message.channelID, @"messageIDs" : sentMessageIDs};
                    [[NSNotificationCenter defaultCenter] postNotificationName:AATTMessageManagerDidSendUnsentMessagesNotification object:self userInfo:userInfo];
                }
            } else {
                NSLog(@"Failed to send unsent message; %@", error.localizedDescription);
                [messagePlus incrementSendAttemptsCount];
                [self.database insertOrReplaceMessage:messagePlus];
                
                NSDictionary *userInfo = @{@"channelID" : message.channelID,
                                           @"messageID" : messagePlus.message.messageID,
                                           @"sendAttemptsCount" : [NSNumber numberWithInteger:messagePlus.sendAttemptsCount]};
                
                [[NSNotificationCenter defaultCenter] postNotificationName:AATTMessageManagerDidFailToSendUnsentMessagesNotification object:self userInfo:userInfo];
            }
        }];
    }
}

- (void)sendPendingDeletionsInChannelWithID:(NSString *)channelID completionBlock:(AATTMessageManagerDeletionCompletionBlock)block {
    NSDictionary *deletions = [self.database pendingMessageDeletionsInChannelWithID:channelID];
    if(deletions.count > 0) {
        NSArray *pendingMessageDeletions = [deletions allValues];
        [self sendPendingDeletionAtIndex:0 inPendingDeletionsArray:pendingMessageDeletions completionBlock:block lastMeta:nil];
    } else if(block) {
        block(nil, nil);
    }
}

#pragma mark - Private Stuff

- (void)sendPendingDeletionAtIndex:(NSUInteger)index inPendingDeletionsArray:(NSArray *)pendingDeletions completionBlock:(AATTMessageManagerDeletionCompletionBlock)block lastMeta:(ANKAPIResponseMeta *)meta {
    if(index >= pendingDeletions.count) {
        if(block) {
            block(meta, nil);
        }
    } else {
        AATTPendingMessageDeletion *pendingMessageDeletion = [pendingDeletions objectAtIndex:index];
        [self.client deleteMessageWithID:pendingMessageDeletion.messageID inChannelWithID:pendingMessageDeletion.channelID completion:^(id responseObject, ANKAPIResponseMeta *meta, NSError *error) {
            if(!error) {
                [self.database deletePendingMessageDeletionForMessageWithID:pendingMessageDeletion.messageID];
                [self sendPendingDeletionAtIndex:(index+1) inPendingDeletionsArray:pendingDeletions completionBlock:block lastMeta:meta];
            } else {
                NSLog(@"Deleting of pending deletion failed; %@", error.localizedDescription);
                if(block) {
                    block(meta, error);
                }
            }
        }];
    }
}

- (NSMutableOrderedDictionary *)existingOrNewMessagesDictionaryforChannelWithID:(NSString *)channelID {
    NSMutableOrderedDictionary *channelMessages = [self.messagesByChannelID objectForKey:channelID];
    if(!channelMessages) {
        channelMessages = [NSMutableOrderedDictionary orderedDictionary];
        [self.messagesByChannelID setObject:channelMessages forKey:channelID];
    }
    return channelMessages;
}

- (NSMutableOrderedDictionary *)existingOrNewUnsentMessagesDictionaryforChannelWithID:(NSString *)channelID {
    NSMutableOrderedDictionary *channelMessages = [self.unsentMessagesByChannelID objectForKey:channelID];
    if(!channelMessages) {
        channelMessages = [self.database unsentMessagesInChannelWithID:channelID].mutableCopy;
        [self.unsentMessagesByChannelID setObject:channelMessages forKey:channelID];
    }
    return channelMessages;
}

- (NSMutableSet *)existingOrNewMessageIDsNeedingPendingFileSetForFileWithID:(NSString *)pendingFileID {
    NSMutableSet *messagesNeedingPendingFile = [self.messageIDsNeedingPendingFiles objectForKey:pendingFileID];
    if(!messagesNeedingPendingFile) {
        messagesNeedingPendingFile = [NSMutableSet setWithSet:[self.database messageIDsDependentOnPendingFileWithID:pendingFileID]];
        [self.messageIDsNeedingPendingFiles setObject:messagesNeedingPendingFile forKey:pendingFileID];
    }
    return messagesNeedingPendingFile;
}

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
    
    [self fetchMessagesWithQueryParameters:parameters inChannelWithId:channelID keepInMemory:keepInMemory messageFilter:nil completionBlock:^(NSArray *messagePlusses, ANKAPIResponseMeta *meta, NSError *error) {
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
                block(messages, meta, error);
            }
        } else {
            block(messages, meta, error);
        }
    } filterBlock:nil];
}

- (BOOL)fetchMessagesInChannelWithID:(NSString *)channelID sinceID:(NSString *)sinceID beforeID:(NSString *)beforeID messageFilter:(AATTMessageFilter)messageFilter completionBlock:(AATTMessageManagerCompletionBlock)block filterBlock:(AATTMessageManagerCompletionWithFilterBlock)filterBlock {
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
    
    return [self fetchMessagesWithQueryParameters:parameters inChannelWithId:channelID keepInMemory:YES messageFilter:messageFilter completionBlock:block filterBlock:filterBlock];
}

- (void)deleteOEmbedAtIndex:(NSUInteger)index OEmbedAnnoations:(NSArray *)OEmbedAnnotations completionBlock:(void (^)(void))block {
    if(index >= OEmbedAnnotations.count) {
        block();
    } else {
        ANKAnnotation *OEmbed = [OEmbedAnnotations objectAtIndex:index];
        NSString *fileID = [OEmbed.value objectForKey:@"file_id"];
        if(fileID) {
            [self.client deleteFileWithID:fileID completion:^(id responseObject, ANKAPIResponseMeta *meta, NSError *error) {
                if(!error) {
                    [self deleteOEmbedAtIndex:index+1 OEmbedAnnoations:OEmbedAnnotations completionBlock:block];
                } else {
                    NSLog(@"error deleting file from OEmbed; %@", error);
                    if(meta.statusCode != ANKHTTPStatusForbidden) {
                        [self.database insertOrReplacePendingFileDeletion:fileID];
                    }
                    [self deleteOEmbedAtIndex:index+1 OEmbedAnnoations:OEmbedAnnotations completionBlock:block];
                }
            }];
        } else {
            [self deleteOEmbedAtIndex:index+1 OEmbedAnnoations:OEmbedAnnotations completionBlock:block];
        }
    }
}

- (void)deleteAttachmentsListAtIndex:(NSUInteger)index attachmentsAnnotations:(NSArray *)attachmentsAnnotations completionBlock:(void (^)(void))block {
    if(index >= attachmentsAnnotations.count) {
        block();
    } else {
        ANKAnnotation *attachment = [attachmentsAnnotations objectAtIndex:index];
        NSArray *fileList = [attachment.value objectForKey:@"net.app.core.file_list"];
        [self deleteFromAttachmentsAnnotationFileAtIndex:0 fileList:fileList completionBlock:^{
            [self deleteAttachmentsListAtIndex:index+1 attachmentsAnnotations:attachmentsAnnotations completionBlock:block];
        }];
    }
}

- (void)deleteFromAttachmentsAnnotationFileAtIndex:(NSUInteger)index fileList:(NSArray *)fileList completionBlock:(void (^)(void))block {
    if(index >= fileList.count) {
        block();
    } else {
        NSDictionary *file = [fileList objectAtIndex:index];
        NSString *fileID = [file objectForKey:@"file_id"];
        [self.client deleteFileWithID:fileID completion:^(id responseObject, ANKAPIResponseMeta *meta, NSError *error) {
            if(!error) {
                [self deleteFromAttachmentsAnnotationFileAtIndex:index+1 fileList:fileList completionBlock:block];
            } else {
                NSLog(@"error deleting file from attachments list; %@", error);
                if(meta.statusCode != ANKHTTPStatusForbidden) {
                    [self.database insertOrReplacePendingFileDeletion:fileID];
                }
                [self deleteFromAttachmentsAnnotationFileAtIndex:index+1 fileList:fileList completionBlock:block];
            }
        }];
    }
}

- (void)deleteFromChannelMapAndUpdateMinMaxPairForMessagePlus:(AATTMessagePlus *)messagePlus {
    NSString *channelID = messagePlus.message.channelID;
    NSMutableOrderedDictionary *channelMessages = [self existingOrNewMessagesDictionaryforChannelWithID:channelID];
    
    if([channelMessages objectForKey:messagePlus.displayDate]) {
        //
        //modify the MinMaxPair if the removed message was at the min or max date/id.
        //we know the channel messages are ordered by date, but the ids are not necessarily ordered.
        //
        AATTMinMaxPair *minMaxPair = [self minMaxPairForChannelID:channelID];
        NSString *deletedMessageID = messagePlus.message.messageID;
        BOOL adjustMax = [deletedMessageID isEqualToString:minMaxPair.maxID];
        BOOL adjustMin = [deletedMessageID isEqualToString:minMaxPair.minID];
        NSNumber *maxIDAsNumber = minMaxPair.maxIDAsNumber;
        NSNumber *minIDAsNumber = minMaxPair.minIDAsNumber;
        NSNumber *newMaxID = nil;
        NSNumber *newMinID = nil;
        NSTimeInterval deletedDate = messagePlus.displayDate.timeIntervalSince1970;
        
        //we have to iterate because ids are not in order in map,
        //but we need need to find new min/max id. we will set the new
        //dates while doing so as well
        
        NSDate *lastDate = nil;
        NSDate *secondToLastDate = nil;
        
        for(NSDate *nextDate in channelMessages.allKeys) {
            
            //so this is the second date, and the first date was the one that was removed
            //the new max date is the second key.
            if(lastDate && !secondToLastDate && lastDate.timeIntervalSince1970 == deletedDate) {
                minMaxPair.maxDate = nextDate;
            }
            
            AATTMessagePlus *nextMessagePlus = [channelMessages objectForKey:nextDate];
            NSInteger nextID = nextMessagePlus.message.messageID.integerValue;
            if(adjustMax && maxIDAsNumber.integerValue > nextID && (!newMaxID || nextID > newMaxID.integerValue)) {
                newMaxID = [NSNumber numberWithInteger:nextID];
            }
            if(adjustMin && minIDAsNumber.integerValue < nextID && (!newMinID || nextID < newMinID.integerValue)) {
                newMinID = [NSNumber numberWithInteger:nextID];
            }
            secondToLastDate = lastDate;
            lastDate = nextDate;
        }
        
        //the last date was the removed one, so the new min date is the second to last date.
        if(deletedDate == lastDate.timeIntervalSince1970) {
            minMaxPair.minDate = secondToLastDate;
        }
        if(newMaxID) {
            minMaxPair.maxID = newMaxID.stringValue;
        }
        if(newMinID) {
            minMaxPair.minID = newMinID.stringValue;
        }
        
        //handle the edge case where there is only one item in the map, about to get removed
        if(channelMessages.count == 1) {
            minMaxPair.minID = nil;
            minMaxPair.maxID = nil;
            minMaxPair.minDate = nil;
            minMaxPair.maxDate = nil;
        }
        
        [channelMessages removeEntryWithKey:messagePlus.displayDate];
    }
}

- (BOOL)fetchMessagesWithQueryParameters:(NSDictionary *)parameters inChannelWithId:(NSString *)channelID keepInMemory:(BOOL)keepInMemory messageFilter:(AATTMessageFilter)filter completionBlock:(AATTMessageManagerCompletionBlock)block filterBlock:(AATTMessageManagerCompletionWithFilterBlock)filterBlock {
    NSMutableOrderedDictionary *unsentMessages = [self existingOrNewUnsentMessagesDictionaryforChannelWithID:channelID];
    if(unsentMessages.count > 0) {
        return NO;
    }
    if([self.database pendingMessageDeletionsInChannelWithID:channelID].count > 0) {
        return NO;
    }
    
    [self.client fetchMessagesInChannelWithID:channelID parameters:parameters completion:^(id responseObject, ANKAPIResponseMeta *meta, NSError *error) {
        NSOrderedDictionary *excludedResults = nil;
        
        NSArray *responseMessages = responseObject;
        NSMutableOrderedDictionary *channelMessagePlusses = [self existingOrNewMessagesDictionaryforChannelWithID:channelID];
        NSMutableOrderedDictionary *newestMessagesDictionary = [[NSMutableOrderedDictionary alloc] initWithCapacity:responseMessages.count];
        NSMutableOrderedDictionary *newChannelMessages = [NSMutableOrderedDictionary orderedDictionaryWithCapacity:([channelMessagePlusses count] + [responseMessages count])];
        
        [newChannelMessages addEntriesFromOrderedDictionary:channelMessagePlusses];
        
        for(ANKMessage *m in responseMessages) {
            AATTMessagePlus *messagePlus = [[AATTMessagePlus alloc] initWithMessage:m];
            [self adjustDateForMessagePlus:messagePlus];
            [newestMessagesDictionary setObject:messagePlus forKey:messagePlus.displayDate];
            [newChannelMessages setObject:messagePlus forKey:messagePlus.displayDate];
        }
        
        //SORT!
        [newChannelMessages sortEntrysByKeysUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            return [obj2 compare:obj1];
        }];
        
        if(filter) {
            excludedResults = filter(newestMessagesDictionary);
            [self removeExcludedMessages:excludedResults fromDictionary:newestMessagesDictionary];
        }
        
        NSDate *minDate = nil;
        NSDate *maxDate = nil;
        
        for(AATTMessagePlus *messagePlus in [newestMessagesDictionary allObjects]) {
            [self insertMessagePlus:messagePlus];
            
            NSTimeInterval time = messagePlus.displayDate.timeIntervalSince1970;
            if(!minDate || time < minDate.timeIntervalSince1970) {
                minDate = messagePlus.displayDate;
            }
            if(!maxDate || time > maxDate.timeIntervalSince1970) {
                maxDate = messagePlus.displayDate;
            }
        }
        
        if(keepInMemory) {
            [self.messagesByChannelID setObject:newChannelMessages forKey:channelID];
            
            AATTMinMaxPair *minMaxPair = [self minMaxPairForChannelID:channelID];
            AATTMinMaxPair *batchMinMaxPair = [[AATTMinMaxPair alloc] initWithMinID:meta.minID maxID:meta.maxID minDate:minDate maxDate:maxDate];
            [minMaxPair updateByCombiningWithMinMaxPair:batchMinMaxPair];
        }
        
        NSArray *newestMessages = [NSArray arrayWithArray:[newestMessagesDictionary allObjects]];
        [self performLookupsOnMessagePlusses:newestMessages persist:YES];

        if(filterBlock) {
            filterBlock(newestMessages, excludedResults, meta, error);
        } else if(block) {
            block(newestMessages, meta, error);
        }
    }];
    
    return YES;
}

- (AATTOrderedMessageBatch *)loadPersistedMessageBatchForChannelWithID:(NSString *)channelID limit:(NSUInteger)limit performLookups:(BOOL)performLookups {
    NSDate *beforeDate = nil;
    AATTMinMaxPair *minMaxPair = [self minMaxPairForChannelID:channelID];
    if(minMaxPair.minDate) {
        beforeDate = minMaxPair.minDate;
    }
    
    AATTOrderedMessageBatch *orderedMessageBatch = [self.database messagesInChannelWithID:channelID beforeDate:beforeDate limit:limit];
    NSOrderedDictionary *messagePlusses = orderedMessageBatch.messagePlusses;
    AATTMinMaxPair *dbMinMaxPair = orderedMessageBatch.minMaxPair;
    [minMaxPair updateByCombiningWithMinMaxPair:dbMinMaxPair];
    
    NSMutableOrderedDictionary *channelMessages = [messagePlusses objectForKey:channelID];
    if(channelMessages) {
        [channelMessages addEntriesFromOrderedDictionary:messagePlusses];
    } else {
        [self.messagesByChannelID setObject:messagePlusses forKey:channelID];
    }
    
    if(performLookups) {
        [self performLookupsOnMessagePlusses:[messagePlusses allObjects] persist:NO];
    }
    return orderedMessageBatch;
}

- (void)removeExcludedMessages:(NSOrderedDictionary *)excludedMessages fromDictionary:(NSMutableOrderedDictionary *)dictionary {
    for(id entryKey in [excludedMessages allKeys]) {
        [dictionary removeEntryWithKey:entryKey];
    }
}

- (AATTMinMaxPair *)minMaxPairForChannelID:(NSString *)channelID {
    AATTMinMaxPair *pair = [self.minMaxPairs objectForKey:channelID];
    if(!pair) {
        pair = [[AATTMinMaxPair alloc] init];
        [self.minMaxPairs setObject:pair forKey:channelID];
    }
    return pair;
}

- (void)adjustDateForMessagePlus:(AATTMessagePlus *)messagePlus {
    NSDate *adjustedDate = [self adjustedDateForMessage:messagePlus.message];
    messagePlus.displayDate = adjustedDate;
}

- (void)insertMessagePlus:(AATTMessagePlus *)messagePlus {
    [self.database insertOrReplaceMessage:messagePlus];
    
    if(self.configuration.isHashtagExtractionEnabled) {
        [self.database insertOrReplaceHashtagInstances:messagePlus];
    }
    
    if(self.configuration.annotationExtractions.count > 0) {
        for(NSString *annotationType in self.configuration.annotationExtractions) {
            [self.database insertOrReplaceAnnotationInstancesOfType:annotationType forTargetMessagePlus:messagePlus];
        }
    }
}

- (NSDate *)adjustedDateForMessage:(ANKMessage *)message {
    return self.configuration.dateAdapter ? self.configuration.dateAdapter(message) : message.createdAt;
}

/**
 Upload pending file attachments for an AATTMessagePlus. Upon success, replace its pending attachments
 with annotations so that it can be sent to the server. Additionally, any message that is
 dependent on the pending files will be candidates to be sent upon file upload. All candidates
 that are left with 0 pending file attachments will be sent via sendUnsentMessagesInChannelWithID:
 */
- (void)uploadPendingFileAttachmentWithPendingFileID:(NSString *)pendingFileID forMessageInChannelWithID:(NSString *)channelID {
    [self.fileManager uploadPendingFileWithID:pendingFileID completionBlock:^(ANKFile *file, ANKAPIResponseMeta *meta, NSError *error) {
        if(error || !file) {
            return;
        }
        NSSet *messageIDs = [self existingOrNewMessageIDsNeedingPendingFileSetForFileWithID:pendingFileID];
        AATTOrderedMessageBatch *orderedMessageBatch = [self.database messagesWithIDs:messageIDs];
        NSOrderedDictionary *messagesNeedingFile = orderedMessageBatch.messagePlusses;
        
        //always add the provided channel ID so that we can finish the
        //sending of the unsent message in that channel.
        NSMutableSet *channelIDsWithMessagesToSend = [NSMutableSet set];
        [channelIDsWithMessagesToSend addObject:channelID];
        
        for(AATTMessagePlus *messagePlusNeedingFile in messagesNeedingFile.allObjects) {
            NSAssert(messagePlusNeedingFile.pendingFileAttachments, @"AATTMessagePlus is missing pending file attachments");
            [messagePlusNeedingFile replacePendingFileAttachmentWithAnnotationForPendingFileWithID:pendingFileID file:file];
            
            NSDate *messageDate = messagePlusNeedingFile.displayDate;
            NSString *messageID = messagePlusNeedingFile.message.messageID;
            NSString *channelID = messagePlusNeedingFile.message.channelID;
            NSMutableOrderedDictionary *channelMessages = [self.messagesByChannelID objectForKey:channelID];
            NSMutableOrderedDictionary *unsentMessages = [self.unsentMessagesByChannelID objectForKey:channelID];
            
            if([channelMessages objectForKey:messageDate]) {
                [channelMessages setObject:messagePlusNeedingFile forKey:messageDate];
            }
            if([unsentMessages objectForKey:messageDate]) {
                [unsentMessages setObject:messagePlusNeedingFile forKey:messageDate];
            }
            
            [self.database insertOrReplaceMessage:messagePlusNeedingFile];
            [self.database deletePendingFileAttachmentForPendingFileWithID:pendingFileID messageID:messageID];
            
            if(messagePlusNeedingFile.pendingFileAttachments.count == 0) {
                [channelIDsWithMessagesToSend addObject:channelID];
            }
        }
        
        [self.messageIDsNeedingPendingFiles removeObjectForKey:pendingFileID];
        
        for(NSString *channelID in channelIDsWithMessagesToSend) {
            [self sendUnsentMessagesInChannelWithID:channelID];
        }
    }];
}

- (void)performLookupsOnMessagePlusses:(NSArray *)messagePlusses persist:(BOOL)persist {
    if(self.configuration.isLocationLookupEnabled) {
        [self lookupLocationForMessagePlusses:messagePlusses persist:persist];
    }
}

#pragma mark - Location Lookup

- (void)lookupLocationForMessagePlusses:(NSArray *)messagePlusses persist:(BOOL)persist {
    for(AATTMessagePlus *messagePlus in messagePlusses) {
        ANKMessage *message = messagePlus.message;
        
        ANKAnnotation *checkin = [message firstAnnotationOfType:kANKCoreAnnotationCheckin];
        if(checkin) {
            messagePlus.displayLocation = [AATTDisplayLocation displayLocationFromCheckinAnnotation:checkin];
            if(persist) {
                [self.database insertOrReplaceDisplayLocationInstance:messagePlus];
            }
            continue;
        }
        
        ANKAnnotation *ohai = [message firstAnnotationOfType:@"net.app.ohai.location"];
        if(ohai) {
            messagePlus.displayLocation = [AATTDisplayLocation displayLocationFromOhaiLocationAnnotation:ohai];
            if(persist) {
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
                // the async task in reverseGeocode:latitude:longitude:persist:)
                if(persist) {
                    [self.database insertOrReplaceDisplayLocationInstance:messagePlus];
                }
                continue;
            } else {
                [self reverseGeocode:messagePlus latitude:[latitude doubleValue] longitude:[longitude doubleValue]];
            }
        }
    }
}

- (void)reverseGeocode:(AATTMessagePlus *)messagePlus latitude:(double)latitude longitude:(double)longitude {
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    CLLocation *location = [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
    [geocoder reverseGeocodeLocation:location completionHandler:^(NSArray *placemarks, NSError *error) {
        if(!error) {
            AATTGeolocation *geolocation = [self geolocationForPlacemarks:placemarks latitude:latitude longitude:longitude];
            if(geolocation) {
                messagePlus.displayLocation = [AATTDisplayLocation displayLocationFromGeolocation:geolocation];
                [self.database insertOrReplaceGeolocation:geolocation];
                [self.database insertOrReplaceDisplayLocationInstance:messagePlus];
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
