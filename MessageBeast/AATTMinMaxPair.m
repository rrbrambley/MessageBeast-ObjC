//
//  AATTMinMaxPair.m
//  MessageBeast
//
//  Created by Rob Brambley on 10/31/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTMinMaxPair.h"

@implementation AATTMinMaxPair

- (AATTMinMaxPair *)combineWith:(AATTMinMaxPair *)otherMinMaxPair {
    NSNumber *thisMin = [self minIDAsNumber];
    NSNumber *thisMax = [self maxIDAsNumber];
    NSNumber *otherMin = [otherMinMaxPair minIDAsNumber];
    NSNumber *otherMax = [otherMinMaxPair maxIDAsNumber];
    
    NSString *newMin = nil;
    NSString *newMax = nil;
    if(thisMin && otherMin) {
        newMin = [NSString stringWithFormat:@"%d", MIN([thisMin intValue], [otherMin intValue])];
    } else if(otherMin) {
        newMin = [otherMin stringValue];
    } else if(thisMin) {
        newMin = [thisMin stringValue];
    }
    
    if(thisMax && otherMax) {
        newMax = [NSString stringWithFormat:@"%d", MAX([thisMax intValue], [otherMax intValue])];
    } else if(otherMax) {
        newMax = [otherMax stringValue];
    } else if(thisMax) {
        newMax = [thisMax stringValue];
    }
    
    AATTMinMaxPair *pair = [[AATTMinMaxPair alloc] init];
    pair.minID = newMin;
    pair.maxID = newMax;
    
    return pair;
}

- (NSNumber *)maxIDAsNumber {
    return self.maxID ? [NSNumber numberWithInteger:[self.maxID integerValue]] : nil;
}

- (NSNumber *)minIDAsNumber {
    return self.minID ? [NSNumber numberWithInteger:[self.minID integerValue]] : nil;
}

@end
