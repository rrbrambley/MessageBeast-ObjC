//
//  AATTSharedDateFormatter.m
//  MessageBeast
//
//  Created by Rob Brambley on 3/2/14.
//  Copyright (c) 2014 Always All The Time. All rights reserved.
//

#import "AATTSharedDateFormatter.h"

@implementation AATTSharedDateFormatter

+ (NSDateFormatter *)dateFormatter {
	static NSDateFormatter *sharedDateFormatter = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedDateFormatter = [[NSDateFormatter alloc] init];
		sharedDateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
        sharedDateFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
	});
	return sharedDateFormatter;
}

@end
