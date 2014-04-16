//
//  AATTMessageManager.h
//  MessageBeast
//
//  Created by Rob Brambley on 10/30/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTADNDatabase.h"

@class AATTActionMessageManager, AATTDisplayLocation, AATTFilteredMessageBatch, AATTMessageManagerConfiguration, AATTMessagePlus, M13OrderedDictionary;

typedef NS_ENUM(NSUInteger, AATTChannelFullSyncState) {
	AATTChannelFullSyncStateNotStarted = 0,
	AATTChannelFullSyncStateStarted,
	AATTChannelFullSyncStateComplete
};

/**
 A notification posted when unsent Messages are successfully sent.
 Since the unsent copies of the Message are deleted upon being sent,
 you may want to listen for this notification and call fetchNewestMessagesInChannelWithID:completionBlock:
 to fetch the server-generated copies of the Messages.
 
 This notification may be triggered by:
 
 sendAllUnsentForChannelWithID:
 createUnsentMessageAndAttemptSendInChannelWithID:message:
 createUnsentMessageAndAttemptSendInChannelWithID:message:pendingFileAttachments:
 
 UserInfo: @{@"channelID" : NSString*, @"messageIDs" : NSArray*}
 */
extern NSString *const AATTMessageManagerDidSendUnsentMessagesNotification;

/**
 A notification posted when unsent Messages fail to be sent.
 
 This notification may be triggered by:
 
 sendAllUnsentForChannelWithID:
 createUnsentMessageAndAttemptSendInChannelWithID:message:
 createUnsentMessageAndAttemptSendInChannelWithID:message:pendingFileAttachments:
 
 UserInfo: @{@"channelID" : NSString*, @"messageID" : NSString*, @"sendAttemptsCount" : NSNumber*}
 */
extern NSString *const AATTMessageManagerDidFailToSendUnsentMessagesNotification;

@interface AATTMessageManager : NSObject

/**
 Given a dictionary of <message id : AATTMessagePlus> pairs, return
 a M13OrderedDictionary containing those that should be excluded.
 */
typedef M13OrderedDictionary* (^AATTMessageFilter)(M13OrderedDictionary *messages);

typedef void (^AATTMessageManagerCompletionBlock)(NSArray *messagePlusses, ANKAPIResponseMeta *meta, NSError *error);
typedef void (^AATTMessageManagerCompletionWithFilterBlock)(NSArray *messagePlusses, M13OrderedDictionary *excludedResults, ANKAPIResponseMeta *meta, NSError *error);
typedef void (^AATTMessageManagerMultiChannelSyncBlock)(BOOL success, NSError *error);
typedef void (^AATTMessageManagerBatchSyncBlock)(NSArray *messagePlusses, ANKAPIResponseMeta *meta, NSError *error);
typedef void (^AATTMessageManagerRefreshCompletionBlock)(id responseObject, ANKAPIResponseMeta *meta, NSError *error);
typedef void (^AATTMessageManagerDeletionCompletionBlock)(ANKAPIResponseMeta *meta, NSError *error);

#pragma mark - Initializer

- (id)initWithANKClient:(ANKClient *)client configuration:(AATTMessageManagerConfiguration *)configuration;


#pragma mark - Clear
/**
 Purge all Message and Channel-related data from memory. This will leave the manager in
 the initial state - as it was upon construction. Note that this does not delete any persisted
 data from the sqlite database.
 */
- (void)clearAll;

#pragma mark - Getters

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

#pragma mark - Setters

/**
 Set the query parameters that should be used for the specified channel.

 You might want to consider setting your ANKClient's generalParameters property to nil if you want
 to use this functionality.

 @param channelID the id of the channel whose parameters are being set.
 @param parameters a dictionary of query parameters
 */
- (void)setQueryParametersForChannelWithID:(NSString *)channelID parameters:(NSDictionary *)parameters;

#pragma mark - Load Messages

/**
 Load persisted messages that were previously stored in the sqlite database.

 @param channelID the id of the channel for which messages should be loaded.
 @param limit the maximum number of messages to load from the database. A value of 0 will result in all Messages being loaded.
 @return a dictionary with message dates mapped to AATTMessagePlus objects, in reverse
         chronological order.
 */
- (M13OrderedDictionary *)loadPersistedMesssageForChannelWithID:(NSString *)channelID limit:(NSUInteger)limit;

/**
 Load persisted messages that were previously stored in the sqlite database,
 using a message filter to exclude a subset of the results.
 
 @param channelID the id of the channel for which messages should be loaded.
 @param limit the maximum number of messages to load from the database. A value of 0 will result in all Messages being loaded.
 @param messageFilter the AATTMessageFilter to use.
 @return a AATTFilteredMessageBatch containing the messages after a filter was applied, and
         additionally, a dictionary of messages containing the excluded messages.
 */
- (AATTFilteredMessageBatch *)loadPersistedMesssageForChannelWithID:(NSString *)channelID limit:(NSInteger)limit messageFilter:(AATTMessageFilter)messageFilter;

#pragma mark - Get Persisted Messages

/**
 Get persisted messages that have the specified display location.
 These messages are not kept in memory by the message manager.

 @param channelID the id of the channel for which messages should be loaded.
 @param displayLocation the AATTDisplayLocation of interest
 @param locationPrecision the precision to be used when determining whether two locations
        with the same name are considered the same display location.
 @return a dictionary with message dates mapped to AATTMessagePlus objects, in reverse
         chronological order.
 */
- (M13OrderedDictionary *)persistedMessagesForChannelWithID:(NSString *)channelID displayLocation:(AATTDisplayLocation *)displayLocation locationPrecision:(AATTLocationPrecision)locationPrecision;

/**
 Get persisted messages that have the specified display location.
 These messages are not kept in memory by the message manager.
 
 @param channelID the id of the channel for which messages should be loaded.
 @param displayLocation the AATTDisplayLocation of interest
 @param locationPrecision the precision to be used when determining whether two locations
        with the same name are considered the same display location.
 @param beforeDate a date before the display date of all associated messages. Nil is the same as the current date.
 @param limit the maximum number of Messages to load from the database. A value of 0 will result in all Messages being returned.
 @return a dictionary with message dates mapped to AATTMessagePlus objects, in reverse
        chronological order.
 */
- (M13OrderedDictionary *)persistedMessagesForChannelWithID:(NSString *)channelID displayLocation:(AATTDisplayLocation *)displayLocation locationPrecision:(AATTLocationPrecision)locationPrecision beforeDate:(NSDate *)beforeDate limit:(NSUInteger)limit;

/**
 Get persisted messages that have the specified hashtag.
 These messages are not kept in memory by the message manager.

 @param channelID the id of the channel for which messages should be loaded.
 @param hashtagName the hashtag name (without the #)
 @return a dictionary with message dates mapped to AATTMessagePlus objects, in reverse
         chronological order.
 */
- (M13OrderedDictionary *)persistedMessagesForChannelWithID:(NSString *)channelID hashtagName:(NSString *)hashtagName;

/**
 Get persisted messages that have the specified hashtag.
 These messages are not kept in memory by the message manager.
 
 @param channelID the id of the channel for which messages should be loaded.
 @param hashtagName the hashtag name (without the #)
 @param beforeDate a date before the display date of all associated messages. Nil is the same as the current date.
 @param limit the maximum number of Messages to load from the database. A value of 0 will result in all Messages being returned.
 @return a dictionary with message dates mapped to AATTMessagePlus objects, in reverse
 chronological order.
 */
- (M13OrderedDictionary *)persistedMessagesForChannelWithID:(NSString *)channelID hashtagName:(NSString *)hashtagName beforeDate:(NSDate *)beforeDate limit:(NSUInteger)limit;

/**
 Get a persisted message.
 This message is not kept in memory by the message manager.
 
 @param messageID the id of the message to load.
 @return an AATTMessagePlus or nil if none with the provided id is persisted.
 */
- (AATTMessagePlus *)persistedMessageWithID:(NSString *)messageID;

/**
 Get persisted messages.
 These messages are not kept in memory by the message manager.

 @param messageIDs the messages to load.
 @return a dictionary with message dates mapped to AATTMessagePlus objects, in reverse
         chronological order.
 */
- (M13OrderedDictionary *)persistedMessagesWithMessageIDs:(NSSet *)messageIDs;

/**
 Get persisted messages having the specified Annotation type.
 
 @param channelID the id of the channel associated with the messages to be loaded.
 @param annotationType the annotation type
 */
- (M13OrderedDictionary *)persistedMessagesForChannelWithID:(NSString *)channelID withAnnotationOfType:(NSString *)annotationType;

/**
 Get persisted messages having the specified Annotation type, before a given date.
 
 @param channelID the id of the channel associated with the messages to be loaded.
 @param annotationType the annotation type
 @param beforeDate a date before the display date of all associated messages. Nil is the same as the current date.
 @param limit the maximum number of Messages to load from the database. A value of 0 will result in all Messages being returned.
 */
- (M13OrderedDictionary *)persistedMessagesForChannelWithID:(NSString *)channelID withAnnotationOfType:(NSString *)annotationType beforeDate:(NSDate *)beforeDate limit:(NSUInteger)limit;

#pragma mark - Fetch Messages

- (void)fetchAndPersistAllMessagesInChannels:(NSArray *)channels completionBlock:(AATTMessageManagerMultiChannelSyncBlock)block;

/**
 Fetch and persist all messages in a channel.

 This is intended to be used as a one-time sync, e.g. after a user signs in.

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
 with this manager's configuration (e.g. location lookup).

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
 with this manager's configuration (e.g. location lookup).
 
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
 with this manager's configuration (e.g. location lookup).

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
 with this manager's configuration (e.g. location lookup).
 
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
 with this manager's configuration (e.g. location lookup).

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
 with this manager's configuration (e.g. location lookup).
 
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
 with this manager's configuration (e.g. location lookup).

 @param messagePlus the AATTMessagePlus to refresh.
 @param compltionBlock the AATTMessageManagerRefreshCompletionBlock to which the result will be delivered.
 */
- (void)refreshMessagePlus:(AATTMessagePlus *)messagePlus completionBlock:(AATTMessageManagerRefreshCompletionBlock)block;

/**
 Fetch a new instance of an AATTMessagePlus for the Messages corresponding to the provided
 Message IDs.
 
 After the message is fetched, processing will occur in accordance
 with this manager's configuration (e.g. location lookup).
 
 @param messageIDs a set of Message IDs corresponding to the Messages to refresh
 @param channelID the Channel ID associated with the messages. This is used to look up
        the preferred query parameters.
 @param compltionBlock the AATTMessageManagerRefreshCompletionBlock to which the result will be delivered.
 */
- (void)refreshMessagesWithMessageIDs:(NSSet *)messageIDs channelID:(NSString *)channelID completionBlock:(AATTMessageManagerRefreshCompletionBlock)block;

#pragma mark - Search Messages

/**
 Search persisted Message text with a query.
 
 @param query the search query
 @param channelID the id of the Channel from which Messages will be retrieved
 */
- (AATTOrderedMessageBatch *)searchMessagesWithQuery:(NSString *)query inChannelWithID:(NSString *)channelID;

/**
 Search for persisted Messages, using a query that matches against their associated AATTDisplayLocations.
 
 @param displayLocationQuery the search query
 @param channelID the id of the Channel from which Messages will be retrieved
 */
- (AATTOrderedMessageBatch *)searchMessagesWithDisplayLocationQuery:(NSString *)displayLocationQuery inChannelWithID:(NSString *)channelID;

#pragma mark - Delete Messages

/**
 Delete a message. If the provided message is unsent, it will simply be deleted form the local sqlite database and
 no server request is required.
 
 If the message has attached files or OEmbeds, they will not be deleted.
 
 @param messagePlus the AATTMessagePlus associated with the message to be deleted.
 @param block the AATTMessageManagerDeletionCompletionBlock to act as a callback upon deletion.
 */
- (void)deleteMessage:(AATTMessagePlus *)messagePlus completionBlock:(AATTMessageManagerDeletionCompletionBlock)block;

/**
 Delete a message. If the provided message is unsent, it will simply be deleted form the local sqlite database and
 no server request is required.
 
 Associated files, namely file attachments and OEmbeds (that are backed by App.net File objects) can be deleted by
 passing YES for the value of deleteAssociatedFiles.
 
 @param messagePlus the AATTMessagePlus associated with the message to be deleted.
 @param deleteAssociatedFiles YES if file attachments and OEmbed files should be deleted, NO otherwise.
 @param block the AATTMessageManagerDeletionCompletionBlock to act as a callback upon deletion.
 */
- (void)deleteMessage:(AATTMessagePlus *)messagePlus deleteAssociatedFiles:(BOOL)deleteAssociatedFiles completionBlock:(AATTMessageManagerDeletionCompletionBlock)block;

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
 @param YES if the message manager should attempt to send the message immediately, NO
        if the client application will send it at a later time.
 */
- (AATTMessagePlus *)createUnsentMessageAndAttemptSendInChannelWithID:(NSString *)channelID message:(ANKMessage *)message attemptToSendImmediately:(BOOL)attemptToSendImmediately;

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
 @param pendingFileAttachments an array of AATTPendingFileAttachments corresponding to pending files that need to be sent before this message can be sent to the server
 @param YES if the message manager should attempt to send the message immediately, NO
        if the client application will send it at a later time.
 */
- (AATTMessagePlus *)createUnsentMessageAndAttemptSendInChannelWithID:(NSString *)channelID message:(ANKMessage *)message pendingFileAttachments:(NSArray *)pendingFileAttachments attemptToSendImmediately:(BOOL)attemptToSendImmediately;

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

/**
 Send NSNotifcation indicating that unsent messages have been sent.
 Not intended to be used by a client application.
 */
- (void)sendUnsentMessagesSentNotificationForChannelID:(NSString *)channelID sentMessageIDs:(NSArray *)sentMessageIDs replacementMessageIDs:(NSArray *)replacementMessageIDs;

#pragma mark - Other

/**
 Attach an AATTActionMessageManager.
 
 By attaching an AATTActionMessageManager, it will get first dibs on handling some
 responses and processing action messages. Basically, by allowing the message manager
 to have knowledge of the AATTActionMessageManager, we can assure the message manager
 can perform a few select actions safely, before notifications go out and blocks are called
 that may handle new messages in the client application.
 
 @param actionMessageManager the manager to attach.
 */
- (void)attachActionMessageManager:(AATTActionMessageManager *)actionMessageManager;

/**
 Replace any in-memory instances the provided AATTMessagePlus (i.e. those with the same
 channelID + displayDate)
 
 @param messagePlus the AATTMessagePlus to replace the old ones.
 */
- (void)replaceInMemoryMessagePlusWithMessagePlus:(AATTMessagePlus *)messagePlus;

@end
