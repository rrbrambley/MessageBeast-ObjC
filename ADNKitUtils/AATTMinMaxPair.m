//
//  AATTMinMaxPair.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/31/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTMinMaxPair.h"

@implementation AATTMinMaxPair

- (AATTMinMaxPair *)combineWith:(AATTMinMaxPair *)otherMinMaxPair {
    NSNumber *thisMin = self.minID ? [NSNumber numberWithInteger:[self.minID integerValue]] : nil;
    NSNumber *thisMax = self.maxID ? [NSNumber numberWithInteger:[self.maxID integerValue]] : nil;
    NSNumber *otherMin = otherMinMaxPair.minID ? [NSNumber numberWithInteger:[otherMinMaxPair.minID integerValue]] : nil;
    NSNumber *otherMax = otherMinMaxPair.maxID ? [NSNumber numberWithInteger:[otherMinMaxPair.maxID integerValue]] : nil;
    
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

@end
