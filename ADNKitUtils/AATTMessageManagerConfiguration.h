//
//  AATTMessageManagerConfiguration.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/30/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AATTMessageManagerConfiguration : NSObject

@property BOOL isDatabaseInsertionEnabled;
@property BOOL isLocationLookupEnabled;

@property (nonatomic, copy) NSDate * (^dateAdapter)(ANKMessage *message);

@end
