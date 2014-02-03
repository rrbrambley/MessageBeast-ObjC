//
//  AATTMinMaxPair.h
//  MessageBeast
//
//  Created by Rob Brambley on 10/31/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 AATTMinMaxPair contains the min and max IDs, as well as the min and
 max dates for an associated group of AATTMessagePlusObjects.
 */
@interface AATTMinMaxPair : NSObject

@property NSString *minID;
@property NSString *maxID;
@property NSDate *minDate;
@property NSDate *maxDate;

/**
 Initialize a new AATTMinMaxPair
 
 @param minID the min id of the Messages in the associated message batch
 @param maxID the max id of the Messages in the associated message batch
 @param minDate the min date of the Messages in the associated message batch
 @param maxDate the max date of the Messages in the associated message batch
 */
- (id)initWithMinID:(NSString *)minID maxID:(NSString *)maxID minDate:(NSDate *)minDate maxDate:(NSDate *)maxDate;

/**
 @return the max ID as an NSNumber
 */
- (NSNumber *)maxIDAsNumber;

/**
 @return the min ID as an NSNumber
 */
- (NSNumber *)minIDAsNumber;

/**
 Combine another AATTMinMaxPair with this one. The properties in this object
 will be updated to contain the min of the mins and the maxes of the maxes.
 
 @param otherMinMaxPair the other AATTMinMaxPair to combine with this one.
 */
- (void)updateByCombiningWithMinMaxPair:(AATTMinMaxPair *)otherMinMaxPair;

/**
 If the provided date is less than the current min, or greater than the current max,
 update this AATTMinMaxPair's date accordingly.
 
 @param the date to apply to this AATTMinMaxPair
 */
- (void)expandDateIfMinOrMaxForDate:(NSDate *)date;

@end
