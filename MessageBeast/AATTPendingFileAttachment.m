//
//  AATTPendingFileAttachment.m
//  MessageBeast
//
//  Created by Rob Brambley on 1/14/14.
//  Copyright (c) 2014 Always All The Time. All rights reserved.
//

#import "AATTPendingFileAttachment.h"

@implementation AATTPendingFileAttachment

- (id)initWithPendingFileID:(NSString *)pendingFileID isOEmbed:(BOOL)isOEmbed {
    self = [super init];
    if(self) {
        self.pendingFileID = pendingFileID;
        self.isOEmbed = isOEmbed;
    }
    return self;
}

@end
