//
//  AATTBaseMessageInstances.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 11/2/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AATTBaseMessageInstances : NSObject

@property NSMutableOrderedSet *messageIDs;
@property NSString *name;

- (void)addMessageID:(NSString *)messageID;
- (NSUInteger)count;

@end
