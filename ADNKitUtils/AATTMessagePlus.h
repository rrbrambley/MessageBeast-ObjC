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
@property (nonatomic) NSArray *photoOEmbeds;
@property (nonatomic) NSArray *html5VideoOEmbeds;

- (id)initWithMessage:(ANKMessage *)message;
- (ANKAnnotation *)firstPhotoOEmbedAnnotation;
- (ANKAnnotation *)firstVideoOEmbedAnnotation;

@end
