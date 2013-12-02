//
//  AATTMessageManager.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/30/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTADNDatabase.h"

@class AATTDisplayLocation, AATTMessageManagerConfiguration, AATTMessagePlus, NSOrderedDictionary;

@interface AATTMessageManager : NSObject

typedef void (^AATTMessageManagerCompletionBlock)(NSArray *messagePlusses, BOOL appended, ANKAPIResponseMeta *meta, NSError *error);
typedef void (^AATTMessageManagerBatchSyncBlock)(NSArray *messagePlusses, ANKAPIResponseMeta *meta, NSError *error);
typedef void (^AATTMessageManagerRefreshCompletionBlock)(AATTMessagePlus *messagePlus, ANKAPIResponseMeta *meta, NSError *error);
typedef void (^AATTMessageManagerDeletionCompletionBlock)(ANKAPIResponseMeta *meta, NSError *error);

#pragma mark Initializer

- (id)initWithANKClient:(ANKClient *)client configuration:(AATTMessageManagerConfiguration *)configuration;

#pragma mark Getters

- (ANKClient *)client;

#pragma mark Setters

/// Set the query parameters that should be used for the specified channel.
///
/// You might want to consider setting your ANKClient's generalParameters property to nil if you want
/// to use this functionality.
///
/// @param channelID the id of the channel whose parameters are being set.
/// @param parameters a dictionary of query parameters
///
- (void)setQueryParametersForChannelWithID:(NSString *)channelID parameters:(NSDictionary *)parameters;

#pragma mark Load Messages

/// Load persisted messages that were previously stored in the sqlite database.
///
/// @param channelID the id of the channel for which messages should be loaded.
/// @param limit the maximum number of messages to load from the database.
/// @return a dictionary with message IDs mapped to AATTMessagePlus objects, in reverse
///         chronological order.
///
- (NSOrderedDictionary *)loadPersistedMesssageForChannelWithID:(NSString *)channelID limit:(NSInteger)limit;

/// Load persisted messages that have the specified display location.
/// These messages are not kept in memory by the message manager.
///
/// @param channelID the id of the channel for which messages should be loaded.
/// @param displayLocation the AATTDisplayLocation of interest
/// @param locationPrecision the precision to be used when determining whether two locations
///        with the same name are considered the same display location.
/// @return a dictionary with message IDs mapped to AATTMessagePlus objects, in reverse
///         chronological order.
///
- (NSOrderedDictionary *)loadPersistedMessagesTemporarilyForChannelWithID:(NSString *)channelID displayLocation:(AATTDisplayLocation *)displayLocation locationPrecision:(AATTLocationPrecision)locationPrecision;

/// Load persisted messages that have the specified hashtag.
/// These messages are not kept in memory by the message manager.
///
/// @param channelID the id of the channel for which messages should be loaded.
/// @param hashtagName the hashtag name (without the #)
/// @return a dictionary with message IDs mapped to AATTMessagePlus objects, in reverse
///         chronological order.
///
- (NSOrderedDictionary *)loadPersistedMessagesTemporarilyForChannelWithID:(NSString *)channelID hashtagName:(NSString *)hashtagName;

/// Load persisted messages.
/// These messages are not kept in memory by the message manager.
///
/// @param channelID the id of the channel for which messages should be loaded.
/// @param messageIDs the messages to load.
/// @return a dictionary with message IDs mapped to AATTMessagePlus objects, in reverse
///         chronological order.
///
- (NSOrderedDictionary *)loadPersistedMessagesTemporarilyForChannelWithID:(NSString *)channelID messageIDs:(NSSet *)messageIDs;

#pragma mark Fetch Messages

/// Fetch and persist all messages in a channel.
///
/// This is intended to be used as a one-time sync, e.g. after a user signs in. For this reason,
/// it is required that your AATTMessageManagerConfiguration has its isDatabaseInsertionEnabled property
/// set to YES.
///
/// Because this could potentially result in a very large amount of messages being obtained,
/// the provided AATTMessageManagerCompletionBlock will only be passed the first 100 messages that are
/// obtained, while the others will be persisted to the sqlite database, but not kept in memory.
/// However, these can easily be loaded into memory afterwards by calling
/// loadPersistedMessagesForChannelWithID:limit:
///
/// @param channelID the id of the channel for which messages should be synced.
/// @param batchSyncBlock the AATTMessageManagerBatchSyncBlock to which batch updates will be delivered.
///        This can be used to perform extra processing on individual messages. May be nil.
/// @param completionBlock the AATTMessageManagerCompletionBlock to which the results will be delivered.
- (void)fetchAndPersistAllMessagesInChannelWithID:(NSString *)channelID batchSyncBlock:(AATTMessageManagerBatchSyncBlock)batchSyncBlock completionBlock:(AATTMessageManagerCompletionBlock)block;

/// Fetch messages in the channel with the specified ID.
///
/// The since_id and before_id parameters are set by using the in-memory AATTMinMaxPair for
/// the associated channel, which contains the min and max message IDs that have been loaded
/// into memory thus far.
///
/// After messages are fetched, processing on the messages will occur in accordance
/// with this manager's configuration (e.g. database insertion).
///
/// @param channelID the ID of the channel for which messages should be fetched.
/// @param completionBlock the AATTMessageManagerCompletionBlock to which the results will be delivered.
///
- (void)fetchMessagesInChannelWithID:(NSString *)channelID completionBlock:(AATTMessageManagerCompletionBlock)block;

/// Fetch the newest messages in the channel with the specified ID.
///
/// The since_id parameter is set by using the max message ID that has been loaded into memory
/// thus far, while the before_id parameter is set to nil.
///
/// After messages are fetched, processing on the messages will occur in accordance
/// with this manager's configuration (e.g. database insertion).
///
/// @param channelID the ID of the channel for which messages should be fetched.
/// @param completionBlock the AATTMessageManagerCompletionBlock to which the results will be delivered.
///
- (void)fetchNewestMessagesInChannelWithID:(NSString *)channelID completionBlock:(AATTMessageManagerCompletionBlock)block;

/// Fetch more messages in the channel with the specified ID.
///
/// The before parameter is set by using the min message ID that has been loaded into memory
/// thus far, while the since_id parameter is set to nil.
///
/// After messages are fetched, processing on the messages will occur in accordance
/// with this manager's configuration (e.g. database insertion).
///
/// @param channelID the ID of the channel for which messages should be fetched.
/// @param completionBlock the AATTMessageManagerCompletionBlock to which the results will be delivered.
///
- (void)fetchMoreMessagesInChannelWithID:(NSString *)channelID completionBlock:(AATTMessageManagerCompletionBlock)block;

/// Fetch a new instance of the specified AATTMessagePlus' backing message.
///
/// After the message is fetched, processing will occur in accordance
/// with this manager's configuration (e.g. database insertion).
///
/// @param messagePlus the AATTMessagePlus to refresh.
/// @param compltionBlock the AATTMessageManagerRefreshCompletionBlock to which the result will be delivered.
///
- (void)refreshMessagePlus:(AATTMessagePlus *)messagePlus completionBlock:(AATTMessageManagerRefreshCompletionBlock)block;

#pragma mark - Delete Messages

- (void)deleteMessage:(AATTMessagePlus *)messagePlus completionBlock:(AATTMessageManagerDeletionCompletionBlock)block;
@end
