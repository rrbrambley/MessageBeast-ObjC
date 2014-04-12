//
//  AATTMessagePlus.h
//  MessageBeast
//
//  Created by Rob Brambley on 10/30/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

@class AATTDisplayLocation;

/**
 AATTMessagePlus is an ANKMessage wrapper containing extra metadata. Instances
 are usually constructed by AATTMessageManager.
 */
@interface AATTMessagePlus : NSObject

@property ANKMessage *message;
@property NSDate *displayDate;
@property AATTDisplayLocation *displayLocation;
@property BOOL isUnsent;
@property NSUInteger sendAttemptsCount;
@property (nonatomic) NSArray *photoOEmbeds;
@property (nonatomic) NSArray *html5VideoOEmbeds;
@property NSDictionary *pendingFileAttachments;

/**
 Create an unsent AATTMessagePlus. You usually want to rely on the AATTMessageManager
 to construct, store, and send unsent messages (so don't call this directly).
 */
+ (instancetype)unsentMessagePlusForChannelWithID:(NSString *)channelID messageID:(NSString *)messageID message:(ANKMessage *)message pendingFileAttachments:(NSArray *)pendingFileAttachments;

- (id)initWithMessage:(ANKMessage *)message;

/**
 Get the first OEmbed Annotation that is found.
 
 @return the first OEmbed Annotation or nil if none exists.
 */
- (ANKAnnotation *)firstPhotoOEmbedAnnotation;

/**
 Get the first HTML5 video Annotation that is found.
 
 @return the first HTML5 video Annotation or nil if none exists.
 */
- (ANKAnnotation *)firstHTML5VideoOEmbedAnnotation;

/**
 Get the source URL of the first HTML5 video Annotation.
 
 @return the the source url of the first HTML5 video Annotation, or nil if none exists.
 */
- (NSURL *)firstHTML5VideoOEmbedSourceURL;

/**
 Increment the send attempts count. This is called by AATTMessageManager when an unsent
 message is attempted to be sent but fails. The value of the  sendAttemptsCount property can
 be examined to know if a particular Message is having trouble being sent (e.g. perhaps you
 decide that if it fails X many times, you delete it).
 */
- (void)incrementSendAttemptsCount;

/**
 Given a pending file ID, replace the associated pending file attachment with an annotation (before
 sending it to the server). This is called by AATTMessageManager and probably should not be called
 directly otherwise.
 
 @param pendingFileID the id of the pending file
 @param file the ANKFile that was obtained after the pending file was successfully sent.
 */
- (void)replacePendingFileAttachmentWithAnnotationForPendingFileWithID:(NSString *)pendingFileID file:(ANKFile *)file;

/**
 If a target message annotation already exists on this Messsage, replace the value of "id"
 with the new target Message ID. This is performed by AATTActionMessageManager after an unsent
 Message with an associated action Message is successfully sent.
 
 @param newTargetMessageID the new target Message ID to replace the old one.
 */
- (void)replaceTargetMessageAnnotationMessageID:(NSString *)newTargetMessageID;

@end
