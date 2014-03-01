//
//  AATTMessagePlus.m
//  MessageBeast
//
//  Created by Rob Brambley on 10/30/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTMessagePlus.h"
#import "AATTPendingFileAttachment.h"
#import "ANKMessage+AATTAnnotationHelper.h"

@implementation AATTMessagePlus

+ (instancetype)unsentMessagePlusForChannelWithID:(NSString *)channelID messageID:(NSString *)messageID message:(ANKMessage *)message pendingFileAttachments:(NSArray *)pendingFileAttachments {
    
    message.messageID = messageID;
    message.channelID = channelID;

    NSDate *date = [message ohaiDisplayDate];
    if(!date) {
        date = [NSDate date];
        [message addDisplayDateAnnotationWithDate:date];
    }
    
    AATTMessagePlus *unsentMessagePlus = [[AATTMessagePlus alloc] initWithMessage:message];
    unsentMessagePlus.isUnsent = YES;
    unsentMessagePlus.displayDate = date;
    
    NSMutableDictionary *pendingFileAttachmentsDictionary = [NSMutableDictionary dictionaryWithCapacity:pendingFileAttachments.count];
    for(AATTPendingFileAttachment *attachment in pendingFileAttachments) {
        [pendingFileAttachmentsDictionary setObject:attachment forKey:attachment.pendingFileID];
    }
    
    unsentMessagePlus.pendingFileAttachments = pendingFileAttachmentsDictionary;
    
    return unsentMessagePlus;
}

- (id)initWithMessage:(ANKMessage *)message {
    self = [super init];
    if(self) {
        self.message = message;
    }
    return self;
}

- (void)initOEmbedAnnotations {
    NSArray *OEmbedAnnotations = [self.message annotationsWithType:kANKCoreAnnotationEmbeddedMedia];
    NSMutableArray *photos = [NSMutableArray arrayWithCapacity:OEmbedAnnotations.count];
    NSMutableArray *videos = [NSMutableArray arrayWithCapacity:OEmbedAnnotations.count];
    
    for(ANKAnnotation *annotation in OEmbedAnnotations) {
        NSString *type = [[annotation value] objectForKey:@"type"];
        
        if([@"photo" isEqualToString:type]) {
            [photos addObject:annotation];
        } else if([@"html5video" isEqualToString:type]) {
            [videos addObject:annotation];
        } else {
            NSLog(@"Unknown OEmbed annotation type: %@", type);
        }
    }
    
    self.photoOEmbeds = [NSArray arrayWithArray:photos];
    self.html5VideoOEmbeds = [NSArray arrayWithArray:videos];
}

- (NSArray *)photoOEmbeds {
    if(!_photoOEmbeds) {
        [self initOEmbedAnnotations];
    }
    return _photoOEmbeds;
}

- (NSArray *)html5VideoOEmbeds {
    if(!_html5VideoOEmbeds) {
        [self initOEmbedAnnotations];
    }
    return _html5VideoOEmbeds;
}

- (ANKAnnotation *)firstPhotoOEmbedAnnotation {
    if(!self.photoOEmbeds) {
        [self initOEmbedAnnotations];
    }
    return self.photoOEmbeds.count > 0 ? [self.photoOEmbeds objectAtIndex:0] : nil;
}

- (ANKAnnotation *)firstHTML5VideoOEmbedAnnotation {
    if(!self.html5VideoOEmbeds) {
        [self initOEmbedAnnotations];
    }
    return self.html5VideoOEmbeds.count > 0 ? [self.html5VideoOEmbeds objectAtIndex:0] : nil;
}

- (NSURL *)firstHTML5VideoOEmbedSourceURL {
    ANKAnnotation *annotation = [self firstHTML5VideoOEmbedAnnotation];
    if(annotation) {
        NSDictionary *value = annotation.value;
        NSArray *sources = [value objectForKey:@"sources"];
        if(sources.count > 0) {
            NSDictionary *firstSource = [sources objectAtIndex:0];
            NSString *url = [firstSource objectForKey:@"url"];
            if(url) {
                return [NSURL URLWithString:url];
            }
        }
    }
    return nil;
}

- (void)incrementSendAttemptsCount {
    self.sendAttemptsCount++;
}

- (void)replacePendingFileAttachmentWithAnnotationForPendingFileWithID:(NSString *)pendingFileID file:(ANKFile *)file {
    AATTPendingFileAttachment *pendingFileAttachment = [self.pendingFileAttachments objectForKey:pendingFileID];
    if(pendingFileAttachment) {
        if(pendingFileAttachment.isOEmbed) {
            ANKAnnotation *annotation = [ANKAnnotation oembedAnnotationForFile:file];
            NSMutableArray *annotations = [NSMutableArray arrayWithCapacity:(self.message.annotations.count + 1)];
            if(self.message.annotations) {
                [annotations addObjectsFromArray:self.message.annotations];
            }
            [annotations addObject:annotation];
            self.message.annotations = annotations;
        } else {
            [self.message appendToAttachments:file];
        }
        
        [(NSMutableDictionary *)self.pendingFileAttachments removeObjectForKey:pendingFileID];
    }
}

- (void)replaceTargetMessageAnnotationMessageID:(NSString *)newTargetMessageID {
    NSArray *targetMessageAnnotations = [self.message annotationsWithType:kMessageAnnotationTargetMessage];
    if(targetMessageAnnotations.count > 0) {
        ANKAnnotation *annotation = [targetMessageAnnotations objectAtIndex:0];
        NSMutableDictionary *newValue = [NSMutableDictionary dictionaryWithDictionary:annotation.value];
        [newValue setObject:newTargetMessageID forKey:@"id"];
        annotation.value = newValue;
    }
}

@end
