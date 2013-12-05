//
//  AATTActionMessageSpec.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 12/4/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AATTActionMessageSpec : NSObject

@property NSString *actionMessageID;
@property NSString *actionChannelID;
@property NSString *targetMessageID;
@property NSString *targetChannelID;

@end
