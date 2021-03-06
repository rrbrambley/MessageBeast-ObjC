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
#import "AATTADNFileManager.h"
#import "AATTADNPersistence.h"
#import "AATTAnnotationInstances.h"
#import "AATTCustomPlace.h"
#import "AATTDisplayLocation.h"
#import "AATTDisplayLocationInstances.h"
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
#import "M13OrderedDictionary.h"

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
@property AATTActionMessageManager *actionMessageManager;
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

#pragma mark - Clear

- (void)clearAll {
    [self.messagesByChannelID removeAllObjects];
    [self.unsentMessagesByChannelID removeAllObjects];
    [self.messageIDsNeedingPendingFiles removeAllObjects];
    [self.queryParametersByChannel removeAllObjects];
    [self.minMaxPairs removeAllObjects];
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
    M13OrderedDictionary *messages = [self.messagesByChannelID objectForKey:channelID];
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

- (M13OrderedDictionary *)loadPersistedMesssageForChannelWithID:(NSString *)channelID limit:(NSUInteger)limit {
    AATTOrderedMessageBatch *batch = [self loadPersistedMessageBatchForChannelWithID:channelID limit:limit performLookups:YES];
    return batch.messagePlusses;
}

- (AATTFilteredMessageBatch *)loadPersistedMesssageForChannelWithID:(NSString *)channelID limit:(NSInteger)limit messageFilter:(AATTMessageFilter)messageFilter {
    AATTOrderedMessageBatch *batch = [self loadPersistedMessageBatchForChannelWithID:channelID limit:limit performLookups:NO];
    AATTFilteredMessageBatch *filteredBatch = [AATTFilteredMessageBatch filteredMessageBatchWithOrderedMessageBatch:batch messageFilter:messageFilter];
    M13OrderedDictionary *excludedMessages = filteredBatch.excludedMessages;
    
    //remove the excluded messages from the main channel message dictionary.
    NSMutableOrderedDictionary *channelMessages = [self.messagesByChannelID objectForKey:channelID];
    [self removeExcludedMessages:excludedMessages fromDictionary:channelMessages];
    
    //do this after we have successfully filtered out stuff,
    //as to not perform lookups on things we didn't keep.
    [self performLookupsOnMessagePlusses:filteredBatch.messagePlusses.allObjects persist:NO];
    
    return filteredBatch;
}

#pragma mark - Get Persisted Messages

- (M13OrderedDictionary *)persistedMessagesForChannelWithID:(NSString *)channelID displayLocation:(AATTDisplayLocation *)displayLocation locationPrecision:(AATTLocationPrecision)locationPrecision {
    AATTDisplayLocationInstances *instances = [self.database displayLocationInstancesInChannelWithID:channelID displayLocation:displayLocation locationPrecision:locationPrecision];
    return [self persistedMessagesWithMessageIDs:instances.messageIDs.set];
}

- (M13OrderedDictionary *)persistedMessagesForChannelWithID:(NSString *)channelID displayLocation:(AATTDisplayLocation *)displayLocation locationPrecision:(AATTLocationPrecision)locationPrecision beforeDate:(NSDate *)beforeDate limit:(NSUInteger)limit {
    AATTDisplayLocationInstances *instances = [self.database displayLocationInstancesInChannelWithID:channelID displayLocation:displayLocation locationPrecision:locationPrecision beforeDate:beforeDate limit:limit];
    return [self persistedMessagesWithMessageIDs:instances.messageIDs.set];
}

- (M13OrderedDictionary *)persistedMessagesForChannelWithID:(NSString *)channelID hashtagName:(NSString *)hashtagName {
    AATTHashtagInstances *hashtagInstances = [self.database hashtagInstancesInChannelWithID:channelID hashtagName:hashtagName];
    return [self persistedMessagesWithMessageIDs:hashtagInstances.messageIDs.set];
}

- (M13OrderedDictionary *)persistedMessagesForChannelWithID:(NSString *)channelID hashtagName:(NSString *)hashtagName beforeDate:(NSDate *)beforeDate limit:(NSUInteger)limit {
    AATTHashtagInstances *hashtagInstances = [self.database hashtagInstancesInChannelWithID:channelID hashtagName:hashtagName beforeDate:beforeDate limit:limit];
    return [self persistedMessagesWithMessageIDs:hashtagInstances.messageIDs.set];
}

- (AATTMessagePlus *)persistedMessageWithID:(NSString *)messageID {
    AATTMessagePlus *messagePlus = [self.database messagePlusForMessageID:messageID];
    if(messagePlus) {
        [self performLookupsOnMessagePlusses:@[messagePlus] persist:NO];
    }
    return messagePlus;
}

- (M13OrderedDictionary *)persistedMessagesWithMessageIDs:(NSSet *)messageIDs {
    AATTOrderedMessageBatch *messageBatch = [self.database messagesWithIDs:messageIDs];
    M13OrderedDictionary *messagePlusses = messageBatch.messagePlusses;
    [self performLookupsOnMessagePlusses:messagePlusses.allObjects persist:NO];
    return messagePlusses;
}

- (M13OrderedDictionary *)persistedMessagesForChannelWithID:(NSString *)channelID withAnnotationOfType:(NSString *)annotationType {
    AATTAnnotationInstances *annotationInstances = [self.database annotationInstancesOfType:annotationType inChannelWithID:channelID];
    return [self persistedMessagesWithMessageIDs:annotationInstances.messageIDs.set];
}

- (M13OrderedDictionary *)persistedMessagesForChannelWithID:(NSString *)channelID withAnnotationOfType:(NSString *)annotationType beforeDate:(NSDate *)beforeDate limit:(NSUInteger)limit {
    AATTAnnotationInstances *annotationInstances = [self.database annotationInstancesOfType:annotationType inChannelWithID:channelID beforeDate:beforeDate limit:limit];
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
        [self.actionMessageManager fetchAndPersistAllMessagesInActionChannelWithID:nextChannel.channelID completionBlock:currentChannelSyncBlock];
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
                [channelMessages setObject:messagePlus forKey:messagePlus.message.messageID];
            }
            
            [self insertMessagePlus:messagePlus];
            [self performLookupsOnMessagePlusses:@[messagePlus] persist:YES];

            block(messagePlus, meta, error);
        } else {
            block(nil, meta, error);
        }
    }];
}

- (void)refreshMessagesWithMessageIDs:(NSSet *)messageIDs channelID:(NSString *)channelID completionBlock:(AATTMessageManagerRefreshCompletionBlock)block {
    NSArray *messageIDsArray = [messageIDs allObjects];
    NSMutableDictionary *parameters = [self.queryParametersByChannel objectForKey:channelID];
    [self.client fetchMessagesWithIDs:messageIDsArray parameters:parameters completion:^(id responseObject, ANKAPIResponseMeta *meta, NSError *error) {
        if(!error) {
            NSArray *responseMessages = responseObject;
            NSMutableOrderedDictionary *messagePlusses = [NSMutableOrderedDictionary orderedDictionaryWithCapacity:responseMessages.count];
            
            for(ANKMessage *message in responseMessages) {
                AATTMessagePlus *messagePlus = [[AATTMessagePlus alloc] initWithMessage:message];
                [self adjustDateForMessagePlus:messagePlus];
                
                NSMutableOrderedDictionary *channelMessages = [self.messagesByChannelID objectForKey:messagePlus.message.channelID];
                //could be nil if the channel messages weren't loaded first, etc.
                if(channelMessages && [channelMessages objectForKey:message.messageID]) {
                    [channelMessages setObject:messagePlus forKey:messagePlus.message.messageID];
                }
                
                [self insertMessagePlus:messagePlus];
                [messagePlusses setObject:messagePlus forKey:message.messageID];
            }
            
            [self sortDictionaryObjectsByDisplayDate:messagePlusses];
            [self performLookupsOnMessagePlusses:[messagePlusses allObjects] persist:YES];
            block([messagePlusses allObjects], meta, error);
        } else {
            block(nil, meta, error);
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
        if([unsentChannelMessages objectForKey:message.messageID]) {
            [unsentChannelMessages removeEntryWithKey:message.messageID];
        }
        [self deleteFromChannelMapAndUpdateMinMaxPairForMessagePlus:messagePlus];
        
        if(block) {
            block(nil, nil);
        }
    } else {
        void (^finishDelete)(void) = ^void(void) {
            [self.database deleteMessagePlus:messagePlus];
            [self deleteFromChannelMapAndUpdateMinMaxPairForMessagePlus:messagePlus];
        };
        
        void (^deleteMessage)(void) = ^void(void) {
            [self.database insertOrReplacePendingDeletionForMessagePlus:messagePlus];
            [self.client deleteMessage:messagePlus.message completion:^(id responseObject, ANKAPIResponseMeta *meta, NSError *error) {
                if(!error) {
                    finishDelete();
                    [self.database deletePendingMessageDeletionForMessageWithID:messagePlus.message.messageID];
                    if(block) {
                        block(meta, error);
                    }
                } else {
                    finishDelete();
                    if(block) {
                        block(meta, error);
                    }
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

- (AATTMessagePlus *)createUnsentMessageAndAttemptSendInChannelWithID:(NSString *)channelID message:(ANKMessage *)message attemptToSendImmediately:(BOOL)attemptToSendImmediately {
    return [self createUnsentMessageAndAttemptSendInChannelWithID:channelID message:message pendingFileAttachments:[NSArray array] attemptToSendImmediately:attemptToSendImmediately];
}

- (AATTMessagePlus *)createUnsentMessageAndAttemptSendInChannelWithID:(NSString *)channelID message:(ANKMessage *)message pendingFileAttachments:(NSArray *)pendingFileAttachments attemptToSendImmediately:(BOOL)attemptToSendImmediately {

    M13OrderedDictionary *channelMessages = [self existingOrNewMessagesDictionaryforChannelWithID:channelID];
    if(channelMessages.count == 0) {
        //we do this so that the max id is known.
        [self loadPersistedMesssageForChannelWithID:channelID limit:1];
    }
    
    NSString *newMessageIDString = [[NSUUID UUID] UUIDString];
    
    AATTMessagePlus *unsentMessagePlus = [AATTMessagePlus unsentMessagePlusForChannelWithID:channelID messageID:newMessageIDString message:message pendingFileAttachments:pendingFileAttachments];
    
    if(self.configuration.isLocationLookupEnabled) {
        [self lookupLocationForMessagePlusses:@[unsentMessagePlus] persist:YES];
    }
    
    [self.database insertOrReplaceMessage:unsentMessagePlus];
    
    NSMutableOrderedDictionary *unsentChannelMessages = [self existingOrNewUnsentMessagesDictionaryforChannelWithID:channelID];
    [unsentChannelMessages setObject:unsentMessagePlus forKey:newMessageIDString];
    
    NSMutableOrderedDictionary *newChannelMessages = [NSMutableOrderedDictionary orderedDictionaryWithCapacity:channelMessages.count + 1];
    [newChannelMessages setObject:unsentMessagePlus forKey:newMessageIDString];
    [newChannelMessages addEntriesFromOrderedDictionary:channelMessages];
    [self.messagesByChannelID setObject:newChannelMessages forKey:channelID];
    
    AATTMinMaxPair *minMaxPair = [self minMaxPairForChannelID:channelID];
    [minMaxPair expandDateIfMinOrMaxForDate:unsentMessagePlus.displayDate];
    
    if(attemptToSendImmediately) {
        [self sendUnsentMessagesInChannelWithID:channelID];
    }
    
    return unsentMessagePlus;
}

#pragma mark - Send Unsent

- (void)sendAllUnsentForChannelWithID:(NSString *)channelID {
    [self sendPendingDeletionsInChannelWithID:channelID completionBlock:^(ANKAPIResponseMeta *meta, NSError *error) {
        [self sendUnsentMessagesInChannelWithID:channelID];
    }];
}

- (void)sendUnsentMessagesSentNotificationForChannelID:(NSString *)channelID sentMessageIDs:(NSArray *)sentMessageIDs replacementMessageIDs:(NSArray *)replacementMessageIDs {
    NSDictionary *userInfo = @{@"channelID" : channelID,
                               @"messageIDs" : sentMessageIDs,
                               @"replacementMessageIDs" : replacementMessageIDs};
    [[NSNotificationCenter defaultCenter] postNotificationName:AATTMessageManagerDidSendUnsentMessagesNotification object:self userInfo:userInfo];
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

#pragma mark - Other

- (void)attachActionMessageManager:(AATTActionMessageManager *)actionMessageManager {
    self.actionMessageManager = actionMessageManager;
}

- (void)replaceInMemoryMessagePlusWithMessagePlus:(AATTMessagePlus *)messagePlus {
    NSString *channelID = messagePlus.message.channelID;
    NSString *messageID = messagePlus.message.messageID;
    
    NSMutableOrderedDictionary *channelMessages = [self.messagesByChannelID objectForKey:channelID];
    if(channelMessages) {
        if([channelMessages objectForKey:messageID]) {
            [channelMessages setObject:messagePlus forKey:messageID];
        }
    }
    
    NSMutableOrderedDictionary *unsentChannelMessages = [self.unsentMessagesByChannelID objectForKey:channelID];
    if(unsentChannelMessages) {
        if([unsentChannelMessages objectForKey:messageID]) {
            [unsentChannelMessages setObject:messagePlus forKey:messageID];
        }
    }
}

#pragma mark - Private Stuff


- (BOOL)sendUnsentMessagesInChannelWithID:(NSString *)channelID {
    NSMutableOrderedDictionary *unsentMessages = [self existingOrNewUnsentMessagesDictionaryforChannelWithID:channelID];
    if(unsentMessages.count > 0) {
        NSMutableOrderedDictionary *channelMessages = [self existingOrNewMessagesDictionaryforChannelWithID:channelID];
        if(channelMessages.count == 0) {
            [self loadPersistedMesssageForChannelWithID:channelID limit:(unsentMessages.count + 1)];
        }
        NSMutableArray *sentMessageIDs = [NSMutableArray arrayWithCapacity:unsentMessages.count];
        NSMutableArray *replacementMessageIDs = [NSMutableArray arrayWithCapacity:unsentMessages.count];
        [self sendUnsentMessages:unsentMessages sentMessageIDs:sentMessageIDs replacementMessageIDs:replacementMessageIDs];
        return YES;
    }
    return NO;
}

- (void)sendUnsentMessages:(NSMutableOrderedDictionary *)unsentMessages sentMessageIDs:(NSMutableArray *)sentMessageIDs replacementMessageIDs:(NSMutableArray *)replacementMessageIDs {
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
        
        NSDictionary *params = [self.queryParametersByChannel objectForKey:message.channelID];
        [self.client createMessage:message inChannelWithID:message.channelID parameters:params completion:^(id responseObject, ANKAPIResponseMeta *meta, NSError *error) {
            if(!error) {
                ANKMessage *newMessage = responseObject;
                
                [unsentMessages removeEntryWithKey:message.messageID];
                [sentMessageIDs addObject:message.messageID];
                [replacementMessageIDs addObject:newMessage.messageID];
                
                //delete the old one.
                [self.database deleteMessagePlus:messagePlus];
                [self deleteFromChannelMapAndUpdateMinMaxPairForMessagePlus:messagePlus];
                
                //now create a new one and add it to the places, update all the things.
                AATTMinMaxPair *minMaxPair = [self minMaxPairForChannelID:message.channelID];
                AATTMessagePlus *newMessagePlus = [[AATTMessagePlus alloc] initWithMessage:newMessage];
                NSDate *date = [self adjustDateForMessagePlus:newMessagePlus];
                [self performLookupsOnMessagePlusses:@[newMessagePlus] persist:YES];
                [self insertMessagePlus:newMessagePlus];
                
                //just like with fetchMessages..., only keep this message in memory if
                //it is replacing an existing message in memory, or if the date is greater
                //than the current min date in memory.
                NSMutableOrderedDictionary *channelMessages = [self existingOrNewMessagesDictionaryforChannelWithID:newMessagePlus.message.channelID];
                BOOL inMemory = [channelMessages objectForKey:message.messageID];
                if(inMemory) {
                    [channelMessages removeObjectForKey:message.messageID];
                }
                if(inMemory || !minMaxPair.minDate || date.timeIntervalSince1970 >= minMaxPair.minDate.timeIntervalSince1970) {
                    [channelMessages setObject:newMessagePlus forKey:newMessage.messageID];
                    [minMaxPair expandDateIfMinOrMaxForDate:newMessagePlus.displayDate];
                    [minMaxPair expandIDIfMinOrMaxForID:newMessagePlus.message.messageID];
                    [self sortDictionaryObjectsByDisplayDate:channelMessages];
                }
                
                if(unsentMessages.count > 0) {
                    [self sendUnsentMessages:unsentMessages sentMessageIDs:sentMessageIDs replacementMessageIDs:replacementMessageIDs];
                } else {
                    if(self.actionMessageManager) {
                        [self.actionMessageManager didSendUnsentMessagesInChannelWithID:newMessage.channelID sentMessageIDs:sentMessageIDs replacementMessageIDs:replacementMessageIDs];
                    } else {
                        [self sendUnsentMessagesSentNotificationForChannelID:message.channelID sentMessageIDs:sentMessageIDs replacementMessageIDs:replacementMessageIDs];
                    }
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
    
    [self fetchMessagesWithQueryParameters:parameters inChannelWithId:channelID forceKeepInMemory:keepInMemory messageFilter:nil completionBlock:^(NSArray *messagePlusses, ANKAPIResponseMeta *meta, NSError *error) {
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
    
    return [self fetchMessagesWithQueryParameters:parameters inChannelWithId:channelID forceKeepInMemory:YES messageFilter:messageFilter completionBlock:block filterBlock:filterBlock];
}

- (void)sortDictionaryObjectsByDisplayDate:(NSMutableOrderedDictionary *)dictionary {
    [dictionary sortEntriesByObjectUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        AATTMessagePlus *mp1 = obj1;
        NSTimeInterval mp1Time = mp1.displayDate.timeIntervalSince1970;
        
        AATTMessagePlus *mp2 = obj2;
        NSTimeInterval mp2Time = mp2.displayDate.timeIntervalSince1970;
        
        if(mp1Time > mp2Time) {
            return NSOrderedAscending;
        } else if(mp2Time > mp1Time) {
            return NSOrderedDescending;
        }
        return NSOrderedSame;
    }];
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
    
    if([channelMessages.allKeys containsObject:messagePlus.message.messageID]) {
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
        
        for(NSDate *nextID in channelMessages.allKeys) {
            AATTMessagePlus *nextMessagePlus = [channelMessages objectForKey:nextID];
            NSDate *nextDate = nextMessagePlus.displayDate;
            
            //so this is the second date, and the first date was the one that was removed
            //the new max date is the second key.
            if(lastDate && !secondToLastDate && lastDate.timeIntervalSince1970 == deletedDate) {
                minMaxPair.maxDate = nextDate;
            }
            
            if(!nextMessagePlus.isUnsent) {
                NSInteger nextID = nextMessagePlus.message.messageID.integerValue;
                if(adjustMax && maxIDAsNumber.integerValue > nextID && (!newMaxID || nextID > newMaxID.integerValue)) {
                    newMaxID = [NSNumber numberWithInteger:nextID];
                }
                if(adjustMin && minIDAsNumber.integerValue < nextID && (!newMinID || nextID < newMinID.integerValue)) {
                    newMinID = [NSNumber numberWithInteger:nextID];
                }
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
        
        [channelMessages removeEntryWithKey:messagePlus.message.messageID];
    }
}

- (BOOL)fetchMessagesWithQueryParameters:(NSDictionary *)parameters inChannelWithId:(NSString *)channelID forceKeepInMemory:(BOOL)forceKeepInMemory messageFilter:(AATTMessageFilter)filter completionBlock:(AATTMessageManagerCompletionBlock)block filterBlock:(AATTMessageManagerCompletionWithFilterBlock)filterBlock {
    NSMutableOrderedDictionary *unsentMessages = [self existingOrNewUnsentMessagesDictionaryforChannelWithID:channelID];
    if(unsentMessages.count > 0) {
        return NO;
    }
    if([self.database pendingMessageDeletionsInChannelWithID:channelID].count > 0) {
        return NO;
    }
    
    [self.client fetchMessagesInChannelWithID:channelID parameters:parameters completion:^(id responseObject, ANKAPIResponseMeta *meta, NSError *error) {
        M13OrderedDictionary *excludedResults = nil;
        
        NSArray *responseMessages = responseObject;
        NSMutableOrderedDictionary *channelMessagePlusses = [self existingOrNewMessagesDictionaryforChannelWithID:channelID];
        NSMutableOrderedDictionary *newestMessagesDictionary = [[NSMutableOrderedDictionary alloc] initWithCapacity:responseMessages.count];
        NSMutableOrderedDictionary *newChannelMessages = [NSMutableOrderedDictionary orderedDictionaryWithCapacity:([channelMessagePlusses count] + [responseMessages count])];
        AATTMinMaxPair *minMaxPair = [self minMaxPairForChannelID:channelID];
        
        [newChannelMessages addEntriesFromOrderedDictionary:channelMessagePlusses];
        
        for(ANKMessage *m in responseMessages) {
            AATTMessagePlus *messagePlus = [[AATTMessagePlus alloc] initWithMessage:m];
            NSDate *date = [self adjustDateForMessagePlus:messagePlus];
            
            [newestMessagesDictionary setObject:messagePlus forKey:messagePlus.message.messageID];
            
            //only keep messages in memory if they are newer than the ones
            //we currently have in memory, or no messages are in memory, indicating
            //that there are no persisted messages.
            //(unless forceKeepInMemory == true)
            if(forceKeepInMemory || !minMaxPair.minDate || date.timeIntervalSince1970 >= minMaxPair.minDate.timeIntervalSince1970) {
                [newChannelMessages setObject:messagePlus forKey:messagePlus.message.messageID];
            }
        }
        
        //SORT!
        [self sortDictionaryObjectsByDisplayDate:newChannelMessages];
        
        if(filter) {
            excludedResults = filter(newestMessagesDictionary);
            [self removeExcludedMessages:excludedResults fromDictionary:newChannelMessages];
            [self removeExcludedMessages:excludedResults fromDictionary:newestMessagesDictionary];
        }
        
        NSDate *minDate = nil;
        NSDate *maxDate = nil;
        
        for(AATTMessagePlus *messagePlus in [newestMessagesDictionary allObjects]) {
            [self insertMessagePlus:messagePlus];
            
            //only consider this a candidate for a min/max if
            //we kept it in the newChannelMessages - a couple steps above.
            if([newChannelMessages objectForKey:messagePlus.message.messageID]) {
                NSTimeInterval time = messagePlus.displayDate.timeIntervalSince1970;
                
                if(!minDate || time < minDate.timeIntervalSince1970) {
                    minDate = messagePlus.displayDate;
                }
                if(!maxDate || time > maxDate.timeIntervalSince1970) {
                    maxDate = messagePlus.displayDate;
                }
            }
        }
        
        [self.messagesByChannelID setObject:newChannelMessages forKey:channelID];
        
        AATTMinMaxPair *batchMinMaxPair = [[AATTMinMaxPair alloc] initWithMinID:meta.minID maxID:meta.maxID minDate:minDate maxDate:maxDate];
        [minMaxPair updateByCombiningWithMinMaxPair:batchMinMaxPair];
        
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
    M13OrderedDictionary *messagePlusses = orderedMessageBatch.messagePlusses;
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

- (void)removeExcludedMessages:(M13OrderedDictionary *)excludedMessages fromDictionary:(NSMutableOrderedDictionary *)dictionary {
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

- (NSDate *)adjustDateForMessagePlus:(AATTMessagePlus *)messagePlus {
    NSDate *adjustedDate = [self adjustedDateForMessage:messagePlus.message];
    messagePlus.displayDate = adjustedDate;
    return adjustedDate;
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
        M13OrderedDictionary *messagesNeedingFile = orderedMessageBatch.messagePlusses;
        
        //always add the provided channel ID so that we can finish the
        //sending of the unsent message in that channel.
        NSMutableSet *channelIDsWithMessagesToSend = [NSMutableSet set];
        [channelIDsWithMessagesToSend addObject:channelID];
        
        for(AATTMessagePlus *messagePlusNeedingFile in messagesNeedingFile.allObjects) {
            NSAssert(messagePlusNeedingFile.pendingFileAttachments, @"AATTMessagePlus is missing pending file attachments");
            [messagePlusNeedingFile replacePendingFileAttachmentWithAnnotationForPendingFileWithID:pendingFileID file:file];
            
            NSString *messageID = messagePlusNeedingFile.message.messageID;
            NSString *channelID = messagePlusNeedingFile.message.channelID;
            NSMutableOrderedDictionary *channelMessages = [self.messagesByChannelID objectForKey:channelID];
            NSMutableOrderedDictionary *unsentMessages = [self.unsentMessagesByChannelID objectForKey:channelID];
            
            if([channelMessages objectForKey:messageID]) {
                [channelMessages setObject:messagePlusNeedingFile forKey:messageID];
            }
            if([unsentMessages objectForKey:messageID]) {
                [unsentMessages setObject:messagePlusNeedingFile forKey:messageID];
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
                
                ANKPlace *place = [[ANKPlace alloc] initWithJSONDictionary:checkin.value];
                if(place && place.factualID) {
                    [self.database insertOrReplacePlace:place];
                }
            }
            continue;
        }
        
        ANKAnnotation *ohai = [message firstAnnotationOfType:@"net.app.ohai.location"];
        if(ohai) {
            messagePlus.displayLocation = [AATTDisplayLocation displayLocationFromOhaiLocationAnnotation:ohai];
            if(persist) {
                [self.database insertOrReplaceDisplayLocationInstance:messagePlus];
                
                NSDictionary *ohaiValue = ohai.value;
                NSString *ID = [ohaiValue objectForKey:@"id"];
                ANKPlace *place = [[ANKPlace alloc] initWithJSONDictionary:ohaiValue];
                if(place) {
                    AATTCustomPlace *customPlace = [[AATTCustomPlace alloc] initWithID:ID place:place];
                    [self.database insertOrReplacePlace:customPlace];
                }
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
            AATTGeolocation *geolocation = [[AATTGeolocation alloc] initWithPlacemarks:placemarks latitude:latitude longitude:longitude];
            messagePlus.displayLocation = [AATTDisplayLocation displayLocationFromGeolocation:geolocation];
            [self.database insertOrReplaceGeolocation:geolocation];
            [self.database insertOrReplaceDisplayLocationInstance:messagePlus];
            //
            //TODO
            // call back for UI?
        } else {
            NSLog(@"%@", error.description);
        }
    }];
}
@end
