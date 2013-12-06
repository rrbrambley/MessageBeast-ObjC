//
//  AATTMessagePlus.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/30/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTMessagePlus.h"
#import "ANKMessage+AATTAnnotationHelper.h"

@implementation AATTMessagePlus

+ (instancetype)unsentMessagePlusForChannelWithID:(NSString *)channelID messageID:(NSString *)messageID message:(ANKMessage *)message pendingFileIDsForOEmbeds:(NSSet *)pendingFileIDsForOEmbeds {

    NSDate *date = [NSDate date];
    
    message.messageID = messageID;
    message.channelID = channelID;
    [message addDisplayDateAnnotationWithDate:date];
    
    AATTMessagePlus *unsentMessagePlus = [[AATTMessagePlus alloc] initWithMessage:message];
    unsentMessagePlus.isUnsent = YES;
    unsentMessagePlus.displayDate = date;
    unsentMessagePlus.pendingOEmbeds = [NSMutableSet setWithSet:pendingFileIDsForOEmbeds];
    
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

- (void)replacePendingOEmbedWithOEmbedAnnotationForPendingFileWithID:(NSString *)pendingFileID file:(ANKFile *)file {
    if([self.pendingOEmbeds containsObject:pendingFileID]) {
        [self.pendingOEmbeds removeObject:pendingFileID];
        
        ANKAnnotation *annotation = [ANKAnnotation oembedAnnotationForFile:file];
        NSMutableArray *annotations = [NSMutableArray arrayWithCapacity:(self.message.annotations.count + 1)];
        if(self.message.annotations) {
            [annotations addObjectsFromArray:annotations];
        }
        [annotations addObject:annotation];
        self.message.annotations = annotations;
    }
}

@end
