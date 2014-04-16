//
//  AATTADNDatabase.h
//  MessageBeast
//
//  Created by Rob Brambley on 10/30/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AATTActionMessageSpec, AATTAnnotationInstances, AATTDisplayLocation, AATTDisplayLocationInstances, AATTGeolocation, AATTHashtagInstances, AATTMessagePlus, AATTOrderedMessageBatch, AATTPendingFile, M13OrderedDictionary;

typedef NS_ENUM(NSUInteger, AATTLocationPrecision) {
    AATTLocationPrecisionOneHundredMeters = 0, //actually 111 m
    AATTLocationPrecisionOneThousandMeters = 1, //actually 1.11 km
    AATTLocationPrecisionTenThousandMeters = 2 //actually 11.1 km
};

@interface AATTADNDatabase : NSObject

+ (AATTADNDatabase *)sharedInstance;

#pragma mark - Insertion

/**
 Insert a message into the database.

 @param messagePlus The AATTMessagePlus to insert.
 */
- (void)insertOrReplaceMessage:(AATTMessagePlus *)messagePlus;

/**
 Insert an ANKPlace into the database.
 
 @param place the ANKPlace to insert
 */
- (void)insertOrReplacePlace:(ANKPlace *)place;

/**
 Use the AATTDisplayLocation associated with a message to store a display location instance.
 Display location instances are unique combinations of (name + message id + latitude + longitude).

 @param messagePlus The AATTMessagePlus whose display location should be stored as a unique
       use of that display location.
 */
- (void)insertOrReplaceDisplayLocationInstance:(AATTMessagePlus *)messagePlus;

/**
 Insert an AATTGeolocation object, using the latitude and longitude combination as the primary key.
 Latitude and longitude values are rounded to three digits, which provides precision of roughly 111 m.

 @param geolocation the AATTGeolocation to insert.
 */
- (void)insertOrReplaceGeolocation:(AATTGeolocation *)geolocation;

/**
 Insert the hashtag instances associated with a message.
 Hashtag instances are unique by (hashtag name + message id).

 @param messagePlus The AATTMessagePlus whose hashtag instances should be inserted.
 */
- (void)insertOrReplaceHashtagInstances:(AATTMessagePlus *)messagePlus;

/**
 Insert instances of annotation of a specific type.
 Annotation instances are unique by (type + mesage id).

 @param annotationType the annotation type of interest
 @param messagePlus the AATTMessagePlus whose OEmbed instances should be inserted
 */
- (void)insertOrReplaceAnnotationInstancesOfType:(NSString *)annotationType forTargetMessagePlus:(AATTMessagePlus *)messagePlus;

/**
 Insert an action message spec.

 @param messagePlus the action message
 @param targetMessageID the ID of the target message
 @param targetChannelID the ID of the target message's channel.
 @param targetMessageDisplayDate the display date of the target message.
 */
- (void)insertOrReplaceActionMessageSpec:(AATTMessagePlus *)messagePlus targetMessageID:(NSString *)targetMessageID targetChannelID:(NSString *)targetChannelID targetMessageDisplayDate:(NSDate *)targetMessageDisplayDate;

/**
 Insert an action message spec.
 
 @param actionMessageID the ID of the action message.
 @param actionChannelID the ID of the action message's channel
 @param targetMessageID the ID of the target message
 @param targetChannelID the ID of the target message's channel
 @param targetMessageDisplayDate the display date of the target message
 */
- (void)insertOrReplaceActionMessageSpecForActionMessageWithID:(NSString *)actionMessageID actionChannelID:(NSString *)actionChannelID targetMessageID:(NSString *)targetMessageID targetChannelID:(NSString *)targetChannelID targetMessageDisplayDate:(NSDate *)targetMessageDisplayDate;

/**
 Insert a pending message deletion.
 
 @param messagePlus the MessagePlus to be deleted
 */
- (void)insertOrReplacePendingDeletionForMessagePlus:(AATTMessagePlus *)messagePlus;

/**
 Insert a pending file. This is intended to be used to track files that are going to be uploaded but have not been uploaded yet.
 
 @param pendingFile the pending file to be uploaded.
 */
- (void)insertOrReplacePendingFile:(AATTPendingFile *)pendingFile;

/**
 Insert a pending file deletion.
 
 @param fileID the id of the file to be deleted at a later time.
 */
- (void)insertOrReplacePendingFileDeletion:(NSString *)fileID;

#pragma mark - Retrieval

/**
 Obtain a batch of persisted AATTMessagePlus objects in reverse chronological order.

 @param channelID the ID of the channel containing the messages.
 @param limit the maximum size of the batch. A value of 0 will result in all Messages being returned.
 @return An ordered batch of messages.
 */
- (AATTOrderedMessageBatch *)messagesInChannelWithID:(NSString *)channelID limit:(NSUInteger)limit;

/**
 Obtain a batch of persisted AATTMessagePlus objects in reverse chronological order.
 This method will obtain messages whose display date is before a specified date.

 @param channelID the ID of the channel containing the messages.
 @param limit the maximum size of the batch. A value of 0 will result in all Messages being returned.
 @return An ordered batch of messages.
 */
- (AATTOrderedMessageBatch *)messagesInChannelWithID:(NSString *)channelID beforeDate:(NSDate *)beforeDate limit:(NSUInteger)limit;

/**
 Obtain a batch of persisted AATTMessagePlus objects using a search query.
 The query is run against the text field of all messages in the specified channel.
 
 @param channelID the ID of the channel containing the messages.
 @param searchQuery the query to use when searching.
 @return An ordered batch of messages.
 */
- (AATTOrderedMessageBatch *)messagesInChannelWithID:(NSString *)channelID searchQuery:(NSString *)query;

/**
 Obtain a batch of persisted AATTMessagePlus objects whose display locations
 have names that match or partially match the provided query
 
 @param channelID the ID of the channel containing the messages.
 @param displayLocationSearchQuery the query to use when searching.
 @return An ordered batch of messages.
 */
- (AATTOrderedMessageBatch *)messagesInChannelWithID:(NSString *)channelID displayLocationSearchQuery:(NSString *)displayLocationSearchQuery;

/**
 Obtain a batch of persisted AATTMessagePlus objects in reverse chronological order.

 @param messageIDs the IDs of the messages that should be retrieved.
 @return An ordered batch of messages
 */
- (AATTOrderedMessageBatch *)messagesWithIDs:(NSSet *)messageIDs;

/**
 Obtain an AATTMessagePlus object
 
 @param messageID the ID of the message that should be retrieved.
 @return An AATTMessagePlus
 */
- (AATTMessagePlus *)messagePlusForMessageID:(NSString *)messageID;

/**
 Obtain a set of message IDs corresponding to messages that are dependent a pending file.
 
 @param pendingFileID
 @return a set of message IDs corresponding to messages that are dependent a pending file.
 */
- (NSSet *)messageIDsDependentOnPendingFileWithID:(NSString *)pendingFileID;

/**
 Obtain all unsent AATTMessagePlus objects in the specified channel.

 Unlike the other message getters, this returns messages in chronological order
 because this is the order in which they should be sent to the server.

 @param channelID the ID of the channel containing the messages.
 @return an M13OrderedDictionary with message ID keys mapped to AATTMessagePlus objects.
 */
- (M13OrderedDictionary *)unsentMessagesInChannelWithID:(NSString *)channelID;

/**
 Obtain an AATTAnnotationInstances containing all message IDs with which the specified annotation type
 is associated.
 
 @param annotationType the type of annotation
 @param channelID the ID of the channel containing the messages
 @return an AATTAnnotationInstances object containing all message IDs with which the specified annotation type
 is associated.
 */
- (AATTAnnotationInstances *)annotationInstancesOfType:(NSString *)annotationType inChannelWithID:(NSString *)channelID;

/**
 Obtain an AATTAnnotationInstances containing all message IDs with which the specified annotation type
 is associated.
 
 @param annotationType the type of annotation
 @param channelID the ID of the channel containing the messages
 @param beforeDate a date that all display dates associated with the annotation instances must
        come after. This is useful for paging. A nil value is the same as passing the current date.
 @param limit the maximum number of instances to obtain. A value of 0 will result in all instances being returned.
 @return an AATTAnnotationInstances object containing all message IDs with which the specified annotation type
 is associated.
 */
- (AATTAnnotationInstances *)annotationInstancesOfType:(NSString *)annotationType inChannelWithID:(NSString *)channelID beforeDate:(NSDate *)beforeDate limit:(NSUInteger)limit;

/**
 Obtain an NSArray of AATTDisplayLocationInstances for a channel with the specified ID.
 Each AATTDisplayLocationInstances contains all message IDs with which its display location
 is associated. This method uses a precision of AATTLocationPrecisionTenThousandMeters (actually ~1.11 km)
 when determining if two locations with the same name are considered equal.

 @param channelID the ID of the channel containing the messages with which the returned
        display location instances are associated.
 @return an array of AATTDisplayLocationInstances, each of which contains a set of
         message IDs associated with its display location. The array will be have
         reverse chronological ordering - based on when the location was last used.
 */
- (NSArray *)displayLocationInstancesInChannelWithID:(NSString *)channelID;

/**
 Obtain an AATTDisplayLocationInstances for a specific display location.
 This method uses a lookup precision of approximately 111 meters, meaning that
 two display locations with the same name will be considered to be the same unique
 location if they fall within 111 meters of each other.

 @param channelID the ID of the channel containing the messages with which the returned
        AATTDisplayLocationInstances' display location is associated.
 @param displayLocation the AATTDisplayLocation for which instances should be obtained.
 @return an AATTDisplayLocationInstances containing all message IDs associated with
         the specified display location.
 */
- (AATTDisplayLocationInstances *)displayLocationInstancesInChannelWithID:(NSString *)channelID displayLocation:(AATTDisplayLocation *)displayLocation;

/**
 Obtain an AATTDisplayLocationInstances for a specific display location,
 using the provided AATTLocationPrecision. The location precision will be used to determine
 how close two locations with the same name must be to each other in order to consider them
 the same location.

 @param channelID the ID of the channel containing the messages with which the returned
        AATTDisplayLocationInstances' display location is associated.
 @param displayLocation the AATTDisplayLocation for which instances should be obtained.
 @param locationPrecision the precision to use when determining uniqueness of locations
        with the same name.
 @return an AATTDisplayLocationInstances containing all message IDs associated with
         the specified display location.
 */
- (AATTDisplayLocationInstances *)displayLocationInstancesInChannelWithID:(NSString *)channelID displayLocation:(AATTDisplayLocation *)displayLocation locationPrecision:(AATTLocationPrecision)locationPrecision;

/**
 Obtain an AATTDisplayLocationInstances for a specific display location,
 using the provided AATTLocationPrecision. The location precision will be used to determine
 how close two locations with the same name must be to each other in order to consider them
 the same location.
 
 @param beforeDate a date that all display dates associated with the display location instances must
        come after. This is useful for paging. A nil value is the same as passing the current date.
 @param limit the maximum number of instances to obtain. A value of 0 will result in all instances being returned.
 @return an AATTDisplayLocationInstances containing message IDs associated with
        the specified display location.
*/
- (AATTDisplayLocationInstances *)displayLocationInstancesInChannelWithID:(NSString *)channelID displayLocation:(AATTDisplayLocation *)displayLocation locationPrecision:(AATTLocationPrecision)locationPrecision beforeDate:(NSDate *)beforeDate limit:(NSUInteger)limit;

/**
 Obtain a dictionary of hashtag instances in reverse chronological order.
 The dictionary maps hashtag names to AATTHashtagInstances objects.

 @param channelID the ID of the channel containing the messages with which the returned
        AATTHashtagInstances objects are associated.
 @return an array of AATTHashtagInstances, each of which contains a set of
         message IDs associated with the hashtag. The array will be have
         reverse chronological ordering - based on when the hashtag was last used.
 */
- (NSArray *)hashtagInstancesInChannelWithID:(NSString *)channelID;

/**
 Obtain a dictionary of all hashtag instances that were used since a specified date.
 The dictionary maps hashtag names to AATTHashtagInstances objects and is in reverse chronological
 order.

 @param channelID the ID of the channel containing the messages with which the returned
        AATTHashtagInstances objects are associated.
 @param sinceDate the date since which the returned hashtags were used.
 @return an array of AATTHashtagInstances, each of which contains a set of
         message IDs associated with the hashtag. The array will be have
         reverse chronological ordering - based on when the hashtag was last used.
 */
- (NSArray *)hashtagInstancesInChannelWithID:(NSString *)channelID sinceDate:(NSDate *)sinceDate;

/**
 Obtain a dictionary of all hashtag instances that were used within a specified date window.
 The dictionary maps hashtag names to AATTHashtagInstances objects and is in reverse chronological
 order.

 @param channelID the ID of the channel containing the messages with which the returned
        AATTHashtagInstances objects are associated.
 @param beforeDate the date before which the returned hashtags were used.
 @param sinceDate the date since which the returned hashtags were used.
 @return an array of AATTHashtagInstances, each of which contains a set of
         message IDs associated with the hashtag. The array will be have
         reverse chronological ordering - based on when the hashtag was last used.
 */
- (NSArray *)hashtagInstancesInChannelWithID:(NSString *)channelID beforeDate:(NSDate *)beforeDate sinceDate:(NSDate *)sinceDate;

/**
 Obtain an AATTHashtagInstances containing all message IDs with which the specified hashtag
 is associated.

 @param channelID the ID of the channel containing the messages with which the returned
        AATTHashtagInstances object is associated.
 @param hashtagName the hashtag (without the #)
 @return an AATTHashtagInstances object containing all message IDs with which the specified hashtag
 is associated.
 */
- (AATTHashtagInstances *)hashtagInstancesInChannelWithID:(NSString *)channelID hashtagName:(NSString *)hashtagName;

/**
 Obtain an AATTHashtagInstances containing all message IDs with which the specified hashtag
 is associated.
 
 @param channelID the ID of the channel containing the messages with which the returned
        AATTHashtagInstances object is associated.
 @param hashtagName the hashtag (without the #)
 @param beforeDate a date that all display dates associated with the hashtag instances must
        come after. This is useful for paging. A nil value is the same as passing the current date.
 @param limit the maximum number of instances to obtain. A value of 0 will result in all instances being returned.
 @return an AATTHashtagInstances object containing all message IDs with which the specified hashtag
 is associated.
 */
- (AATTHashtagInstances *)hashtagInstancesInChannelWithID:(NSString *)channelID hashtagName:(NSString *)hashtagName beforeDate:(NSDate *)beforeDate limit:(NSUInteger)limit;

/**
 Obtain an AATTGeolocation for the specified latitude and longitude, or nil of none exists.
 A location precision of approximately 111 meters (lat/long rounded to 3 decimal places) is
 used to do the lookup.

 @param latitude the latitude coordinate
 @param longitude the longitude coordinate
 @return an AATTGeolcation if one exists, otherwise nil.
 */
- (AATTGeolocation *)geolocationForLatitude:(double)latitude longitude:(double)longitude;

/**
 Obtain the persisted Place with the provided ID.
 
 @param ID the ID of the Place. for App.net Places, this is the factual ID,
        for AATTCustomPlaces, this is the UUID value of the ID property.
 @return the ANKPlace or AATTCustomPlace with the ID, or nil of none exists.
 */
- (ANKPlace *)placeForID:(NSString *)ID;

/**
 Obtain an array of places whose geocoordinates match the provided coordinates to a certain precision.
 
 ANKPlace latitude and longitude are stored by rounding to three decimal places. By providing a less
 precise AATTLocationPrecision, you can lookup by locations that match, e.g. 2 or 1 decimal places.
 
 @param latitude the latitude to match
 @param longitude the longitude to match
 @return an array of ANKPlace objects whose latitude and longitude match when the provided AATTLocationPrecision
 is applied.
 */
- (NSArray *)placesForLatitude:(double)latitude longitude:(double)longitude locationPrecision:(AATTLocationPrecision)locationPrecision;

/**
 Get an array of places whose names match the provided query.

 This uses the full-text search virtual table corresponding to the location instances
 to find matching names, so only places with display location instances in the db will
 be returned (i.e. if you delete all messages that use a place, then this method will
 not return that place, even if the places table contains it).

 @param query The query to match against the name of the places.
 @return an array of ANKPlace objects whose names match the provided query.
 */
- (NSArray *)placesWithNameMatchingQuery:(NSString *)query;

/**
 Get an array of places whose names match the provided query., optionally excluding
 custom Places.

 This uses the full-text search virtual table corresponding to the location instances
 to find matching names, so only places with display location instances in the db will
 be returned (i.e. if you delete all messages that use a place, then this method will
 not return that place, even if the Places table contains it).

 @param query The query to match against the name of the places.
 @param excludeCustom YES if AATTCustomPlace should be excluded, NO otherwise.
 @return an array of ANKPlace objects whose names match the provided query.
 */
- (NSArray *)placesWithNameMatchingQuery:(NSString *)query excludeCustom:(BOOL)excludeCustom;

/**
 Obtain an AATTActionMessageSpec for an action message ID.
 
 @param actionMessageID the action message ID
 */
- (AATTActionMessageSpec *)actionMessageSpecForActionMessageWithID:(NSString *)actionMessageID;

/**
 Obtain an array of AATTActionMessageSpec objects.
 
 @param targetMessageIDs the target message ids of the action message specs to be obtained.
 @return an array of AATTActionMessageSpec objects corresponding to the provided targetMessageIDs
 */
- (NSArray *)actionMessageSpecsForTargetMessagesWithIDs:(NSArray *)targetMessageIDs;

/**
 Obtain an array of AATTActionMessageSpec objects.
 
 @param targetMessageIDs the target message ids of the action message specs to be obtained.
 @param actionChannelID the id of the action channel associated with the action message specs of interest
 @return an array of AATTActionMessageSpec objects.
 */
- (NSArray *)actionMessageSpecsForTargetMessagesWithIDs:(NSArray *)targetMessageIDs inActionChannelWithID:(NSString *)actionChannelID;

/**
 Obtain an array of AATTActionMessageSpec objects ordered by target message ID.
 
 @param actionChannelID the id of the action channel associated with the action message specs of interest
 @param limit the maximum number of specs to obtain from the database.
 */
- (NSArray *)actionMessageSpecsOrderedByTargetMessageDisplayDateInActionChannelWithID:(NSString *)actionChannelID limit:(NSUInteger)limit;

/**
 Obtain an array of AATTActionMessageSpec objects ordered by target message ID.
 
 @param actionChannelID the id of the action channel associated with the action message specs of interest
 @param beforeDate a date later than the target message date of all returned specs
 @param limit the maximum number of specs to obtain from the database
 */
- (NSArray *)actionMessageSpecsOrderedByTargetMessageDisplayDateInActionChannelWithID:(NSString *)actionChannelID beforeDate:(NSDate *)beforeDate limit:(NSUInteger)limit;

/**
 Obtain a pending file.
 
 @param pendingFileID the id of the pending file
 @return an AATTPendingFile corresponding to the file with the provided id that has yet to be uploaded
 */
- (AATTPendingFile *)pendingFileWithID:(NSString *)pendingFileID;

/**
 Obtain an array of AATTPendingFileAttachment objects associated with
 a message.
 
 @param messageID the id of the Message
 @return an array of AATTPendingFileAttachment objects associated with
 the message with the provided id.
 */
- (NSArray *)pendingFileAttachmentsForMessageWithID:(NSString *)messageID;

/**
 Obtain a dictionary of AATTPendingMessageDeletion objects for messages in a specific channel.
 
 @param channelID the id of the channel from which pending message deletions should be obtained.
 @return a dictionary of AATTPendingMessageDeletion objects for messages in a specific channel.
 */
- (NSDictionary *)pendingMessageDeletionsInChannelWithID:(NSString *)channelID;

/**
 Get the ids of all files that are pending deletion.
 
 @return an NSSet containing the ids of all files that are pending deletion.
 */
- (NSSet *)pendingFileDeletions;

#pragma mark - Deletion

/**
 Delete a message and all persisted data associated (hashtag instances, location instances,
 OEmbed instances, etc.) with it.

 @param messagePlus the message to delete.
 */
- (void)deleteMessagePlus:(AATTMessagePlus *)messagePlus;

/**
 Delete a pending message deletion.
 
 @param messageID the id corresponding to the message that is associated with the pending message deletion.
 */
- (void)deletePendingMessageDeletionForMessageWithID:(NSString *)messageID;

/**
 Delete a pending file.
 
 @param pendingFile the pending file to be deleted.
 */
- (void)deletePendingFile:(AATTPendingFile *)pendingFile;

/**
 Delete a pending file.
 
 @param pendingFileID the id associated with the pending file to be deleted.
 */
- (void)deletePendingFileWithID:(NSString *)pendingFileID;

/**
 Delete a pending file attachment.
 
 @param pendingFileID the pending file associated with this attachment.
 @param messageID the id of the message to which the file was attached.
 @param channelID the id of the channel associated with the message
 */
- (void)deletePendingFileAttachmentForPendingFileWithID:(NSString *)pendingFileID messageID:(NSString *)messageID;

/**
 Delete an action message spec.
 
 @param actionMessageID the id of the Action Message.
 */
- (void)deleteActionMessageSpecForActionMessageWithID:(NSString *)actionMessageID;

/**
 Delete action message specs associated with a specific target message and action channel.
 
 @param targetMessageID the target message id associated with the action message
 @param actionChannelID the id of the action channel
 */
- (void)deleteActionMessageSpecWithTargetMessageID:(NSString *)targetMessageID actionChannelID:(NSString *)actionChannelID;

/**
 Delete a pending file deletion.
 
 @param fileID the id of the file that was pending deletion.
 */
- (void)deletePendingFileDeletionForFileWithID:(NSString *)fileID;

/**
 Delete a place.
 
 @param the ID of the place to delete
 */
- (void)deletePlaceWithID:(NSString *)ID;

/**
 Delete all persisted places.
 */
- (void)deletePlaces;

/**
 Delete data from all tables.
 */
- (void)deleteAll;

#pragma mark - Other

/**
 Return YES if an action message spec exists for a specific target message in an action channel.
 
 @param actionChannelID the id of the action channel
 @param targetMesssageID the id of the target message
 */
- (BOOL)hasActionMessageSpecForActionChannelWithID:(NSString *)actionChannelID targetMessageID:(NSString *)targetMessageID;

@end
