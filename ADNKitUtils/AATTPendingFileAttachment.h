//
//  AATTPendingFileAttachment.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 1/14/14.
//  Copyright (c) 2014 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AATTPendingFileAttachment : NSObject

@property NSString *pendingFileID;
@property BOOL isOEmbed;

- (id)initWithPendingFileID:(NSString *)pendingFileID isOEmbed:(BOOL)isOEmbed;
@end
