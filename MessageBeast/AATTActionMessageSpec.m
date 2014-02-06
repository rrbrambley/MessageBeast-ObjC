//
//  AATTActionMessageSpec.m
//  MessageBeast
//
//  Created by Rob Brambley on 12/4/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTActionMessageSpec.h"

@implementation AATTActionMessageSpec

- (id)initWithActionMessageID:(NSString *)actionMessageID actionChannelID:(NSString *)actionChannelID targetMessageID:(NSString *)targetMessageID targetChannelID:(NSString *)targetChannelID targetMessageDate:(NSDate *)targetMessageDate {
    self = [super init];
    if(self) {
        self.actionMessageID = actionMessageID;
        self.actionChannelID = actionChannelID;
        self.targetMessageID = targetMessageID;
        self.targetChannelID = targetChannelID;
        self.targetMessageDate = targetMessageDate;
    }
    return self;
}
@end
