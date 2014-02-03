//
//  AATTMinMaxPair.m
//  MessageBeast
//
//  Created by Rob Brambley on 10/31/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTMinMaxPair.h"

@implementation AATTMinMaxPair

- (id)initWithMinID:(NSString *)minID maxID:(NSString *)maxID minDate:(NSDate *)minDate maxDate:(NSDate *)maxDate {
    self = [super init];
    if(self) {
        self.minID = minID;
        self.maxID = maxID;
        self.minDate = minDate;
        self.maxDate = maxDate;
    }
    return self;
}

- (void)updateByCombiningWithMinMaxPair:(AATTMinMaxPair *)otherMinMaxPair {
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
    
    self.minID = newMin;
    self.maxID = newMax;
    
    //
    //date
    //
    NSTimeInterval newMinDate = 0;
    NSTimeInterval newMaxDate = 0;
    
    if(self.minDate && otherMinMaxPair.minDate) {
        newMinDate = MIN(self.minDate.timeIntervalSince1970, otherMinMaxPair.minDate.timeIntervalSince1970);
    } else if(otherMinMaxPair.minDate) {
        newMinDate = otherMinMaxPair.minDate.timeIntervalSince1970;
    } else if(self.minDate) {
        newMinDate = self.minDate.timeIntervalSince1970;
    }
    
    if(self.maxDate && otherMinMaxPair.maxDate) {
        newMaxDate = MAX(self.maxDate.timeIntervalSince1970, otherMinMaxPair.maxDate.timeIntervalSince1970);
    } else if(otherMinMaxPair.maxDate) {
        newMaxDate = otherMinMaxPair.maxDate.timeIntervalSince1970;
    } else if(self.maxDate) {
        newMaxDate = self.maxDate.timeIntervalSince1970;
    }
    
    self.minDate = [NSDate dateWithTimeIntervalSince1970:newMinDate];
    self.maxDate = [NSDate dateWithTimeIntervalSince1970:newMaxDate];
}

- (NSNumber *)maxIDAsNumber {
    return self.maxID ? [NSNumber numberWithInteger:[self.maxID integerValue]] : nil;
}

- (NSNumber *)minIDAsNumber {
    return self.minID ? [NSNumber numberWithInteger:[self.minID integerValue]] : nil;
}

- (void)expandDateIfMinOrMaxForDate:(NSDate *)date {
    NSTimeInterval time = date.timeIntervalSince1970;
    if(time < self.minDate.timeIntervalSince1970) {
        self.minDate = date;
    } else if(time > self.maxDate.timeIntervalSince1970) {
        self.maxDate = date;
    }
}

@end
