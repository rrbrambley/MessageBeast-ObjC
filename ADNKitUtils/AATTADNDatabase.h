//
//  AATTADNDatabase.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/30/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AATTDisplayLocation, AATTDisplayLocationInstances, AATTGeolocation, AATTHashtagInstances, AATTMessagePlus, AATTOrderedMessageBatch, AATTPendingFile, NSOrderedDictionary;

typedef NS_ENUM(NSUInteger, AATTLocationPrecision) {
    AATTLocationPrecisionOneHundredMeters = 0, //actually 111 m
    AATTLocationPrecisionOneThousandMeters = 1, //actually 1.11 km
    AATTLocationPrecisionTenThousandMeters = 2 //actually 11.1 km
};

@interface AATTADNDatabase : NSObject

+ (AATTADNDatabase *)sharedInstance;

#pragma mark - Insertion

/// Insert a message into the database.
///
/// @param messagePlus The AATTMessagePlus to insert.
///
- (void)insertOrReplaceMessage:(AATTMessagePlus *)messagePlus;

/// Use the AATTDisplayLocation associated with a message to store a display location instance.
/// Display location instances are unique combinations of (name + message id + latitude + longitude).
///
/// @param messagePlus The AATTMessagePlus whose display location should be stored as a unique
///       use of that display location.
///
- (void)insertOrReplaceDisplayLocationInstance:(AATTMessagePlus *)messagePlus;

/// Insert an AATTGeolocation object, using the latitude and longitude combination as the primary key.
/// Latitude and longitude values are rounded to three digits, which provides precision of roughly 111 m.
///
/// @param geolocation the AATTGeolocation to insert.
///
- (void)insertOrReplaceGeolocation:(AATTGeolocation *)geolocation;

/// Insert the hashtag instances associated with a message.
/// Hashtag instances are unique by (hashtag name + message id).
///
/// @param messagePlus The AATTMessagePlus whose hashtag instances should be inserted.
///
- (void)insertOrReplaceHashtagInstances:(AATTMessagePlus *)messagePlus;

/// Insert a message's associated OEmbed instances.
/// OEmbed instances are unique by (type + mesage id).
///
/// @param messagePlus the AATTMessagePlus whose OEmbed instances should be inserted.
///
- (void)insertOrReplaceOEmbedInstances:(AATTMessagePlus *)messagePlus;

/// Insert an action message spec.
///
/// @param messagePlus the action message
/// @param targetMessageID the ID of the target message
/// @param targetChannelID the ID of the target message's channel.
///
- (void)insertOrReplaceActionMessageSpec:(AATTMessagePlus *)messagePlus targetMessageID:(NSString *)targetMessageID targetChannelID:(NSString *)targetChannelID;

- (void)insertOrReplacePendingDeletionForMessagePlus:(AATTMessagePlus *)messagePlus deleteAssociatedFiles:(BOOL)deleteAssociatedFiles;

- (void)insertOrReplacePendingFile:(AATTPendingFile *)pendingFile;

#pragma mark - Retrieval

/// Obtain a batch of persisted AATTMessagePlus objects in reverse chronological order.
///
/// @param channelID the ID of the channel containing the messages.
/// @param limit the maximum size of the batch.
/// @return An ordered batch of messages.
///
- (AATTOrderedMessageBatch *)messagesInChannelWithID:(NSString *)channelID limit:(NSUInteger)limit;

/// Obtain a batch of persisted AATTMessagePlus objects in reverse chronological order.
/// This method will obtain messages whose display date is before a specified date.
///
/// @param channelID the ID of the channel containing the messages.
/// @param limit the maximum size of the batch.
/// @return An ordered batch of messages.
///
- (AATTOrderedMessageBatch *)messagesInChannelWithID:(NSString *)channelID beforeDate:(NSDate *)beforeDate limit:(NSUInteger)limit;

- (AATTOrderedMessageBatch *)messagesInChannelWithID:(NSString *)channelID searchQuery:(NSString *)query;

/// Obtain a batch of persisted AATTMessagePlus objects in reverse chronological order.
///
/// @param channelID the ID of the channel containing the messages.
/// @param messageIDs the IDs of the messages that should be retrieved.
/// @return An ordered batch of messages
- (AATTOrderedMessageBatch *)messagesInChannelWithID:(NSString *)channelID messageIDs:(NSSet *)messageIDs;

- (AATTMessagePlus *)messagePlusForMessageInChannelWithID:(NSString *)channelID messageID:(NSString *)messageID;

/// Obtain all unsent AATTMessagePlus objects in the specified channel.
///
/// Unlike the other message getters, this returns messages in chronological order
/// because this is the order in which they should be sent to the server.
///
/// @param channelID the ID of the channel containing the messages.
/// @return an NSOrderedDictionary with message ID keys mapped to AATTMessagePlus objects.
- (NSOrderedDictionary *)unsentMessagesInChannelWithID:(NSString *)channelID;

/// Obtain an NSArray of AATTDisplayLocationInstances for a channel with the specified ID.
/// Each AATTDisplayLocationInstances contains all message IDs with which its display location
/// is associated.
///
/// @param channelID the ID of the channel containing the messages with which the returned
///        display location instances are associated.
/// @return an array of AATTDisplayLocationInstances, each of which contains a set of
///         message IDs associated with its display location. The array will be have
///         reverse chronological ordering - based on when the location was last used.
///
- (NSArray *)displayLocationInstancesInChannelWithID:(NSString *)channelID;

/// Obtain an AATTDisplayLocationInstances for a specific display location.
/// This method uses a lookup precision of approximately 111 meters, meaning that
/// two display locations with the same name will be considered to be the same unique
/// location if they fall within 111 meters of each other.
///
/// @param channelID the ID of the channel containing the messages with which the returned
///        AATTDisplayLocationInstances' display location is associated.
/// @param displayLocation the AATTDisplayLocation for which instances should be obtained.
/// @return an AATTDisplayLocationInstances containing all message IDs associated with
///         the specified display location.
///
- (AATTDisplayLocationInstances *)displayLocationInstancesInChannelWithID:(NSString *)channelID displayLocation:(AATTDisplayLocation *)displayLocation;

/// Obtain an AATTDisplayLocationInstances for a specific display location,
/// using the provided AATTLocationPrecision. The location precision will be used to determine
/// how close two locations with the same name must be to each other in order to consider them
/// the same location.
///
/// @param channelID the ID of the channel containing the messages with which the returned
///        AATTDisplayLocationInstances' display location is associated.
/// @param displayLocation the AATTDisplayLocation for which instances should be obtained.
/// @param locationPrecision the precision to use when determining uniqueness of locations
///        with the same name.
/// @return an AATTDisplayLocationInstances containing all message IDs associated with
///         the specified display location.
///
- (AATTDisplayLocationInstances *)displayLocationInstancesInChannelWithID:(NSString *)channelID displayLocation:(AATTDisplayLocation *)displayLocation locationPrecision:(AATTLocationPrecision)locationPrecision;

/// Obtain a dictionary of hashtag instances in reverse chronological order.
/// The dictionary maps hashtag names to AATTHashtagInstances objects.
///
/// @param channelID the ID of the channel containing the messages with which the returned
///        AATTHashtagInstances objects are associated.
/// @return an array of AATTHashtagInstances, each of which contains a set of
///         message IDs associated with the hashtag. The array will be have
///         reverse chronological ordering - based on when the hashtag was last used.
///
- (NSArray *)hashtagInstancesInChannelWithID:(NSString *)channelID;

/// Obtain a dictionary of all hashtag instances that were used since a specified date.
/// The dictionary maps hashtag names to AATTHashtagInstances objects and is in reverse chronological
/// order.
///
/// @param channelID the ID of the channel containing the messages with which the returned
///        AATTHashtagInstances objects are associated.
/// @param sinceDate the date since which the returned hashtags were used.
/// @return an array of AATTHashtagInstances, each of which contains a set of
///         message IDs associated with the hashtag. The array will be have
///         reverse chronological ordering - based on when the hashtag was last used.
///
- (NSArray *)hashtagInstancesInChannelWithID:(NSString *)channelID sinceDate:(NSDate *)sinceDate;

/// Obtain a dictionary of all hashtag instances that were used within a specified date window.
/// The dictionary maps hashtag names to AATTHashtagInstances objects and is in reverse chronological
/// order.
///
/// @param channelID the ID of the channel containing the messages with which the returned
///        AATTHashtagInstances objects are associated.
/// @param beforeDate the date before which the returned hashtags were used.
/// @param sinceDate the date since which the returned hashtags were used.
/// @return an array of AATTHashtagInstances, each of which contains a set of
///         message IDs associated with the hashtag. The array will be have
///         reverse chronological ordering - based on when the hashtag was last used.
///
- (NSArray *)hashtagInstancesInChannelWithID:(NSString *)channelID beforeDate:(NSDate *)beforeDate sinceDate:(NSDate *)sinceDate;

/// Obtain an AATTHashtagInstances containing all message IDs with which the specified hashtag
/// is associated.
///
/// @param channelID the ID of the channel containing the messages with which the returned
///        AATTHashtagInstances object is associated.
/// @return an AATTHashtagInstances object containing all message IDs with which the specified hashtag
/// is associated.
///
- (AATTHashtagInstances *)hashtagInstancesInChannelWithID:(NSString *)channelID hashtagName:(NSString *)hashtagName;

/// Obtain an AATTGeolocation for the specified latitude and longitude, or nil of none exists.
/// A location precision of approximately 111 meters (lat/long rounded to 3 decimal places) is
/// used to do the lookup.
///
/// @param latitude the latitude coordinate
/// @param longitude the longitude coordinate
/// @return an AATTGeolcation if one exists, otherwise nil.
///
- (AATTGeolocation *)geolocationForLatitude:(double)latitude longitude:(double)longitude;

- (NSArray *)actionMessageSpecsForTargetMessagesWithIDs:(NSArray *)targetMessageIDs;

- (NSArray *)actionMessageSpecsForTargetMessagesWithIDs:(NSArray *)targetMessageIDs inActionChannelWithID:(NSString *)actionChannelID;

- (AATTPendingFile *)pendingFileWithID:(NSString *)pendingFileID;

- (NSDictionary *)pendingMessageDeletionsInChannelWithID:(NSString *)channelID;

#pragma mark - Deletion

/// Delete a message and all persisted data associated (hashtag instances, location instances,
/// OEmbed instances, etc.) with it.
///
/// @param messagePlus the message to delete.
///
- (void)deleteMessagePlus:(AATTMessagePlus *)messagePlus;

- (void)deletePendingMessageDeletionForMessageWithID:(NSString *)messageID;

- (void)deletePendingFile:(AATTPendingFile *)pendingFile;

- (void)deletePendingFileWithID:(NSString *)pendingFileID;

- (void)deletePendingOEmbedForPendingFileWithID:(NSString *)pendingFileID messageID:(NSString *)messageID channelID:(NSString *)channelID;

- (void)deleteActionMessageSpecForActionMessageWithID:(NSString *)actionMessageID;

- (void)deleteActionMessageSpecWithTargetMessageID:(NSString *)targetMessageID actionChannelID:(NSString *)actionChannelID;

#pragma mark - Other

- (BOOL)hasActionMessageSpecForActionChannelWithID:(NSString *)actionChannelID targetMessageID:(NSString *)targetMessageID;

@end
