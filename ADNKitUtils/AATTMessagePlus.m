//
//  AATTMessagePlus.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/30/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTMessagePlus.h"

@implementation AATTMessagePlus

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

- (ANKAnnotation *)firstVideoOEmbedAnnotation {
    if(!self.html5VideoOEmbeds) {
        [self initOEmbedAnnotations];
    }
    return self.html5VideoOEmbeds.count > 0 ? [self.html5VideoOEmbeds objectAtIndex:0] : nil;
}

@end
