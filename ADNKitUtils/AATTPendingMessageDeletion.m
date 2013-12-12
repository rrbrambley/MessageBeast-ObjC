//
//  AATTPendingMessageDeletion.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 12/12/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTPendingMessageDeletion.h"

@implementation AATTPendingMessageDeletion

- (id)initWithMessageID:(NSString *)messageID channelID:(NSString *)channelID deleteAssociatedFiles:(BOOL)deleteAssociatedFiles {
    self = [super init];
    if(self) {
        self.messageID = messageID;
        self.channelID = channelID;
        self.deleteAssociatedFiles = deleteAssociatedFiles;
    }
    return self;
}

@end
