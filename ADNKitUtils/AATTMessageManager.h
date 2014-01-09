//
//  AATTMessageManager.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/30/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTADNDatabase.h"

@class AATTDisplayLocation, AATTMessageManagerConfiguration, AATTMessagePlus, NSOrderedDictionary;

typedef NS_ENUM(NSUInteger, AATTChannelFullSyncState) {
	AATTChannelFullSyncStateNotStarted = 0,
	AATTChannelFullSyncStateStarted,
	AATTChannelFullSyncStateComplete
};

extern NSString *const AATTMessageManagerDidSendUnsentMessagesNotification;

@interface AATTMessageManager : NSObject

/**
 Given a dictionary of <message id : AATTMessagePlus> pairs, return
 a NSOrderedDictionary containing those that should be excluded.
 */
typedef NSOrderedDictionary* (^AATTMessageFilter)(NSOrderedDictionary *messages);

typedef void (^AATTMessageManagerCompletionBlock)(NSArray *messagePlusses, BOOL appended, ANKAPIResponseMeta *meta, NSError *error);
typedef void (^AATTMessageManagerCompletionWithFilterBlock)(NSArray *messagePlusses, BOOL appended, NSOrderedDictionary *excludedResults, ANKAPIResponseMeta *meta, NSError *error);
typedef void (^AATTMessageManagerMultiChannelSyncBlock)(BOOL success, NSError *error);
typedef void (^AATTMessageManagerBatchSyncBlock)(NSArray *messagePlusses, ANKAPIResponseMeta *meta, NSError *error);
typedef void (^AATTMessageManagerRefreshCompletionBlock)(AATTMessagePlus *messagePlus, ANKAPIResponseMeta *meta, NSError *error);
typedef void (^AATTMessageManagerDeletionCompletionBlock)(ANKAPIResponseMeta *meta, NSError *error);

#pragma mark Initializer

- (id)initWithANKClient:(ANKClient *)client configuration:(AATTMessageManagerConfiguration *)configuration;

#pragma mark Getters

/**
 Get the ANKClient used by this AATTMessageManager
 
 @return the ANKClient used by this AATTMessageManager
 */
- (ANKClient *)client;

/**
 Get the full sync state for the channel with the specified id.

 @param channelID the channel id
 @return an AATTChannelFullSyncState corresponding to the sync state of the channel
         with the specified id
 */
- (AATTChannelFullSyncState)fullSyncStateForChannelWithID:(NSString *)channelID;

/**
 Get an AATTChannelFullSyncState representing the sync state of multiple channels.
 In some cases, we might need several channels to be synced, and one
 or more of them may be in a AATTChannelFullSyncStateNotStarted or AATTChannelFullSyncStateStarted
 state. Since we typically would not need to disclose granular details about the sync state of
 many channels to a user, this method will return AATTChannelFullSyncStateStarted if *any* channel
 in the provided array is in the AATTChannelFullSyncStateStarted state. Otherwise,
 AATTChannelFullSyncStateNotStarted will be returned if any of the channels is not COMPLETE.

 @param channels
 @return an AATTChannelFullSyncState representing the sync state of the provided array of channels.
 */
- (AATTChannelFullSyncState)fullSyncStateForChannels:(NSArray *)channels;

/**
 Get an array of the currently loaded messages in the specified channel id.
 
 @return an array of the currently loaded messages in the specified channel id.
 */
- (NSArray *)loadedMessagesForChannelWithID:(NSString *)channelID;

#pragma mark Setters

/**
 Set the query parameters that should be used for the specified channel.

 You might want to consider setting your ANKClient's generalParameters property to nil if you want
 to use this functionality.

 @param channelID the id of the channel whose parameters are being set.
 @param parameters a dictionary of query parameters
 */
- (void)setQueryParametersForChannelWithID:(NSString *)channelID parameters:(NSDictionary *)parameters;

#pragma mark Load Messages

/**
 Load persisted messages that were previously stored in the sqlite database.

 @param channelID the id of the channel for which messages should be loaded.
 @param limit the maximum number of messages to load from the database.
 @return a dictionary with message IDs mapped to AATTMessagePlus objects, in reverse
         chronological order.
 */
- (NSOrderedDictionary *)loadPersistedMesssageForChannelWithID:(NSString *)channelID limit:(NSInteger)limit;

/**
 Load persisted messages that have the specified display location.
 These messages are not kept in memory by the message manager.

 @param channelID the id of the channel for which messages should be loaded.
 @param displayLocation the AATTDisplayLocation of interest
 @param locationPrecision the precision to be used when determining whether two locations
        with the same name are considered the same display location.
 @return a dictionary with message IDs mapped to AATTMessagePlus objects, in reverse
         chronological order.
 */
- (NSOrderedDictionary *)loadPersistedMessagesTemporarilyForChannelWithID:(NSString *)channelID displayLocation:(AATTDisplayLocation *)displayLocation locationPrecision:(AATTLocationPrecision)locationPrecision;

/**
 Load persisted messages that have the specified hashtag.
 These messages are not kept in memory by the message manager.

 @param channelID the id of the channel for which messages should be loaded.
 @param hashtagName the hashtag name (without the #)
 @return a dictionary with message IDs mapped to AATTMessagePlus objects, in reverse
         chronological order.
 */
- (NSOrderedDictionary *)loadPersistedMessagesTemporarilyForChannelWithID:(NSString *)channelID hashtagName:(NSString *)hashtagName;

/**
 Load persisted messages.
 These messages are not kept in memory by the message manager.

 @param channelID the id of the channel for which messages should be loaded.
 @param messageIDs the messages to load.
 @return a dictionary with message IDs mapped to AATTMessagePlus objects, in reverse
         chronological order.
 */
- (NSOrderedDictionary *)loadPersistedMessagesTemporarilyForChannelWithID:(NSString *)channelID messageIDs:(NSSet *)messageIDs;

#pragma mark Fetch Messages

- (void)fetchAndPersistAllMessagesInChannels:(NSArray *)channels completionBlock:(AATTMessageManagerMultiChannelSyncBlock)block;

/**
 Fetch and persist all messages in a channel.

 This is intended to be used as a one-time sync, e.g. after a user signs in. For this reason,
 it is required that your AATTMessageManagerConfiguration has its isDatabaseInsertionEnabled property
 set to YES.

 Because this could potentially result in a very large amount of messages being obtained,
 the provided AATTMessageManagerCompletionBlock will only be passed the first 100 messages that are
 obtained, while the others will be persisted to the sqlite database, but not kept in memory.
 However, these can easily be loaded into memory afterwards by calling
 loadPersistedMessagesForChannelWithID:limit:

 @param channelID the id of the channel for which messages should be synced.
 @param batchSyncBlock the AATTMessageManagerBatchSyncBlock to which batch updates will be delivered.
        This can be used to perform extra processing on individual messages. May be nil.
 @param completionBlock the AATTMessageManagerCompletionBlock to which the results will be delivered.
 */
- (void)fetchAndPersistAllMessagesInChannelWithID:(NSString *)channelID batchSyncBlock:(AATTMessageManagerBatchSyncBlock)batchSyncBlock completionBlock:(AATTMessageManagerCompletionBlock)block;

/**
 Fetch messages in the channel with the specified ID.

 The since_id and before_id parameters are set by using the in-memory AATTMinMaxPair for
 the associated channel, which contains the min and max message IDs that have been loaded
 into memory thus far.

 After messages are fetched, processing on the messages will occur in accordance
 with this manager's configuration (e.g. database insertion).

 This method can only succesfully execute if there are 0 unsent messages in the specified channel.

 @param channelID the ID of the channel for which messages should be fetched.
 @param completionBlock the AATTMessageManagerCompletionBlock to which the results will be delivered.
 @return NO if the fetch cannot be executed because unsent message must be sent first, or YES otherwise.
 */
- (BOOL)fetchMessagesInChannelWithID:(NSString *)channelID completionBlock:(AATTMessageManagerCompletionBlock)block;

/**
 Fetch messages in a channel, using an AATTMessageFilter to exclude messages
 in the response. Excluded messages will not be persisted and will be returned in a 
 separate array in the completion block.
 
 The since_id and before_id parameters are set by using the in-memory AATTMinMaxPair for
 the associated channel, which contains the min and max message IDs that have been loaded
 into memory thus far.
 
 After messages are fetched, processing on the messages will occur in accordance
 with this manager's configuration (e.g. database insertion).
 
 This method can only succesfully execute if there are 0 unsent messages in the specified channel.
 
 @param channelID the ID of the channel for which messages should be fetched.
 @param messageFilter the AATTMessageFilter to be used when fetching messages.
 @param completionBlock the AATTMessageManagerCompletionWithFilterBlock to which the results will be delivered.
 @return NO if the fetch cannot be executed because unsent message must be sent first, or YES otherwise.
 */
- (BOOL)fetchMessagesInChannelWithID:(NSString *)channelID messageFilter:(AATTMessageFilter)messageFilter completionBlock:(AATTMessageManagerCompletionWithFilterBlock)block;

/**
 Fetch the newest messages in the channel with the specified ID.

 The since_id parameter is set by using the max message ID that has been loaded into memory
 thus far, while the before_id parameter is set to nil.

 After messages are fetched, processing on the messages will occur in accordance
 with this manager's configuration (e.g. database insertion).

 This method can only succesfully execute if there are 0 unsent messages in the specified channel.

 @param channelID the ID of the channel for which messages should be fetched.
 @param completionBlock the AATTMessageManagerCompletionBlock to which the results will be delivered.
 @return NO if the fetch cannot be executed because unsent message must be sent first, or YES otherwise.
 */
- (BOOL)fetchNewestMessagesInChannelWithID:(NSString *)channelID completionBlock:(AATTMessageManagerCompletionBlock)block;

/**
 Fetch the newest messages in a channel, using an AATTMessageFilter to exclude messages
 in the response. Excluded messages will not be persisted and will be returned in a
 separate array in the completion block.
 
 The since_id parameter is set by using the max message ID that has been loaded into memory
 thus far, while the before_id parameter is set to nil.
 
 After messages are fetched, processing on the messages will occur in accordance
 with this manager's configuration (e.g. database insertion).
 
 This method can only succesfully execute if there are 0 unsent messages in the specified channel.
 
 @param channelID the ID of the channel for which messages should be fetched.
 @param messageFilter the AATTMessageFilter to be used when fetching messages.
 @param completionBlock the AATTMessageManagerCompletionWithFilterBlock to which the results will be delivered.
 @return NO if the fetch cannot be executed because unsent message must be sent first, or YES otherwise.
 */
- (BOOL)fetchNewestMessagesInChannelWithID:(NSString *)channelID messageFilter:(AATTMessageFilter)messageFilter completionBlock:(AATTMessageManagerCompletionWithFilterBlock)block;

/**
 Fetch more messages in the channel with the specified ID.

 The before parameter is set by using the min message ID that has been loaded into memory
 thus far, while the since_id parameter is set to nil.

 After messages are fetched, processing on the messages will occur in accordance
 with this manager's configuration (e.g. database insertion).

 This method can only succesfully execute if there are 0 unsent messages in the specified channel.

 @param channelID the ID of the channel for which messages should be fetched.
 @param completionBlock the AATTMessageManagerCompletionBlock to which the results will be delivered.
 @return NO if the fetch cannot be executed because unsent message must be sent first, or YES otherwise.
 */
- (BOOL)fetchMoreMessagesInChannelWithID:(NSString *)channelID completionBlock:(AATTMessageManagerCompletionBlock)block;

/**
 Fetch more in a channel, using an AATTMessageFilter to exclude messages
 in the response. Excluded messages will not be persisted and will be returned in a
 separate array in the completion block.
 
 The before parameter is set by using the min message ID that has been loaded into memory
 thus far, while the since_id parameter is set to nil.
 
 After messages are fetched, processing on the messages will occur in accordance
 with this manager's configuration (e.g. database insertion).
 
 This method can only succesfully execute if there are 0 unsent messages in the specified channel.
 
 @param channelID the ID of the channel for which messages should be fetched.
 @param messageFilter the AATTMessageFilter to use when fetching messages.
 @param completionBlock the AATTMessageManagerCompletionWithFilterBlock to which the results will be delivered.
 @return NO if the fetch cannot be executed because unsent message must be sent first, or YES otherwise.
 */
- (BOOL)fetchMoreMessagesInChannelWithID:(NSString *)channelID messageFilter:(AATTMessageFilter)messageFilter completionBlock:(AATTMessageManagerCompletionWithFilterBlock)block;

/**
 Fetch a new instance of the specified AATTMessagePlus' backing message.

 After the message is fetched, processing will occur in accordance
 with this manager's configuration (e.g. database insertion).

 @param messagePlus the AATTMessagePlus to refresh.
 @param compltionBlock the AATTMessageManagerRefreshCompletionBlock to which the result will be delivered.
 */
- (void)refreshMessagePlus:(AATTMessagePlus *)messagePlus completionBlock:(AATTMessageManagerRefreshCompletionBlock)block;

#pragma mark - Delete Messages

/*
 Delete a message. If the provided message is unsent, it will simply be deleted form the local sqlite database and
 no server request is required.
 
 @param messagePlus the AATTMessagePlus associated with the message to be deleted.
 @param block the AATTMessageManagerDeletionCompletionBlock to act as a callback upon deletion.
 */
- (void)deleteMessage:(AATTMessagePlus *)messagePlus completionBlock:(AATTMessageManagerDeletionCompletionBlock)block;

#pragma mark - Create Messages

/**
 Create a new message in the channel with the specified id.
 
 This is not to be called if you have unsent messages.
 
 @param channelID the id of the Channel in which the Message should be created
 @param message the message to be created
 @param block the completion block to use as a callback
 */
- (void)createMessageInChannelWithID:(NSString *)channelID message:(ANKMessage *)message completionBlock:(AATTMessageManagerCompletionBlock)block;

/**
 Create a new unsent message in the channel with the specified id and attempt to send.

 If the message cannot be sent (e.g. no internet connection), it will still be stored in the
 sqlite database as if the message exists in the channel, but with an unsent flag set on it.
 Any number of unsent messages can exist, but no more messages can be retrieved until all
 unsent messages have been successfully sent (or deleted).

 Upon completion of the send request, a notification with the name AATTMessageManagerDidSendUnsentMessagesNotification
 will be posted with an userInfo containing the keys channelID and messageIDs.

 @param channelID the id of the channel in which the message should be created
 @param message the message to be created
 */
- (AATTMessagePlus *)createUnsentMessageAndAttemptSendInChannelWithID:(NSString *)channelID message:(ANKMessage *)message;

/**
 Create a new unsent message that requires files to be uploaded prior to creation.
 
 If the message cannot be sent (e.g. no internet connection), it will still be stored in the
 sqlite database as if the message exists in the channel, but with an unsent flag set on it.
 Any number of unsent messages can exist, but no more messages can be retrieved until all
 unsent messages have been successfully sent (or deleted).
 
 Upon completion of the send request, a notification with the name AATTMessageManagerDidSendUnsentMessagesNotification
 will be posted with an userInfo containing the keys channelID and messageIDs.
 
 @param channelId the id of the Channel in which the Message should be created
 @param message The Message to be created
 @param pendingFileIDs the ids of the pending files that need to be sent before this message can be sent to the server
 */
- (AATTMessagePlus *)createUnsentMessageAndAttemptSendInChannelWithID:(NSString *)channelID message:(ANKMessage *)message pendingFileIDs:(NSSet *)pendingFileIDs;

#pragma mark - Send Unsent

/**
 Send all pending deletions and unsent messages in a channel.

 The pending deletions will be sent first.

 @param channelID the channel id
 */
- (void)sendAllUnsentForChannelWithID:(NSString *)channelID;

/**
 Send all pending message deletions in a channel.

 @param channelID the channel id
 @param block AATTMessageManagerDeletionCompletionBlock
 */
- (void)sendPendingDeletionsInChannelWithID:(NSString *)channelID completionBlock:(AATTMessageManagerDeletionCompletionBlock)block;

@end
