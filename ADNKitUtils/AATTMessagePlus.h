//
//  AATTMessagePlus.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/30/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

@class AATTDisplayLocation;

@interface AATTMessagePlus : NSObject

@property ANKMessage *message;
@property NSDate *displayDate;
@property AATTDisplayLocation *displayLocation;
@property BOOL isUnsent;
@property NSInteger sendAttemptsCount;
@property (nonatomic) NSArray *photoOEmbeds;
@property (nonatomic) NSArray *html5VideoOEmbeds;
@property NSSet *pendingOEmbeds;

+ (instancetype)unsentMessagePlusForChannelWithID:(NSString *)channelID messageID:(NSString *)messageID message:(ANKMessage *)message pendingFileIDsForOEmbeds:(NSSet *)pendingFileIDsForOEmbeds;

- (id)initWithMessage:(ANKMessage *)message;
- (ANKAnnotation *)firstPhotoOEmbedAnnotation;
- (ANKAnnotation *)firstHTML5VideoOEmbedAnnotation;
- (NSURL *)firstHTML5VideoOEmbedSourceURL;
- (void)incrementSendAttemptsCount;

@end
