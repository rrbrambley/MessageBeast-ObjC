//
//  AATTMinMaxPair.h
//  MessageBeast
//
//  Created by Rob Brambley on 10/31/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AATTMinMaxPair : NSObject

@property NSString *minID;
@property NSString *maxID;

- (AATTMinMaxPair *)combineWith:(AATTMinMaxPair *)otherMinMaxPair;
- (NSNumber *)maxIDAsNumber;
- (NSNumber *)minIDAsNumber;

@end
