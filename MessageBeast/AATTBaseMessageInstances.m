//
//  AATTBaseMessageInstances.m
//  MessageBeast
//
//  Created by Rob Brambley on 11/2/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTBaseMessageInstances.h"
#import "M13OrderedDictionary.h"

@implementation AATTBaseMessageInstances

- (id)init {
    self = [super init];
    if(self) {
        self.messageIDs = [[NSMutableOrderedSet alloc] init];
    }
    return self;
}

- (void)addMessageID:(NSString *)messageID {
    [self.messageIDs addObject:messageID];
}

- (NSUInteger)count {
    return self.messageIDs.count;
}

@end
