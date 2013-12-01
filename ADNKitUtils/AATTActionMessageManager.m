//
//  AATTActionMessageManager.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 12/1/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTActionMessageManager.h"
#import "AATTADNDatabase.h"
#import "AATTMessageManager.h"

@interface AATTActionMessageManager ()
@property AATTMessageManager *messageManager;
@property NSMutableDictionary *actionChannels;
@property NSMutableDictionary *actionedMessages;
@property AATTADNDatabase *database;
@end

@implementation AATTActionMessageManager

- (id)initWithMessageManager:(AATTMessageManager *)messageManager {
    self = [super init];
    if(self) {
        self.messageManager = messageManager;
        self.actionChannels = [NSMutableDictionary dictionaryWithCapacity:1];
        self.actionedMessages = [NSMutableDictionary dictionaryWithCapacity:1];
        self.database = [AATTADNDatabase sharedInstance];
    }
    return self;
}

@end
