//
//  AATTMessageManager.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/30/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

@class AATTMessageManagerConfiguration, NSOrderedDictionary;

@interface AATTMessageManager : NSObject

typedef void (^AATTMessageManagerResponseBlock)(NSArray *messagePlusses, BOOL appended, ANKAPIResponseMeta *meta, NSError *error);

#pragma mark Initializer

- (id)initWithANKClient:(ANKClient *)client configuration:(AATTMessageManagerConfiguration *)configuration;

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

#pragma mark Fetch Messages

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
/// @param withResponseBlock the AATTMessageManagerResponseBlock block to which the results will be delivered.
///
- (void)fetchMessagesInChannelWithID:(NSString *)channelID withResponseBlock:(AATTMessageManagerResponseBlock)block;

/// Fetch the newest messages in the channel with the specified ID.
///
/// The since_id parameter is set by using the max message ID that has been loaded into memory
/// thus far, while the before_id parameter is set to nil.
///
/// After messages are fetched, processing on the messages will occur in accordance
/// with this manager's configuration (e.g. database insertion).
///
/// @param channelID the ID of the channel for which messages should be fetched.
/// @param withResponseBlock the AATTMessageManagerResponseBlock block to which the results will be delivered.
///
- (void)fetchNewestMessagesInChannelWithID:(NSString *)channelID withResponseBlock:(AATTMessageManagerResponseBlock)block;

/// Fetch more messages in the channel with the specified ID.
///
/// The before parameter is set by using the min message ID that has been loaded into memory
/// thus far, while the since_id parameter is set to nil.
///
/// After messages are fetched, processing on the messages will occur in accordance
/// with this manager's configuration (e.g. database insertion).
///
/// @param channelID the ID of the channel for which messages should be fetched.
/// @param withResponseBlock the AATTMessageManagerResponseBlock block to which the results will be delivered.
///
- (void)fetchMoreMessagesInChannelWithID:(NSString *)channelID withResponseBlock:(AATTMessageManagerResponseBlock)block;

@end
