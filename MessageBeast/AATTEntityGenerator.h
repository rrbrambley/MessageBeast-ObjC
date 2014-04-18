//
//  AATTEntityGenerator.h
//  MessageBeast
//
//  Created by Rob Brambley on 4/17/14.
//  Copyright (c) 2014 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AATTEntityGenerator : NSObject

+ (ANKEntities *)entitiesForMessageText:(NSString *)messageText;
+ (NSArray *)hashtagEntitiesForMessageText:(NSString *)messageText;
+ (NSArray *)linkEntitiesForMessageText:(NSString *)messageText;
+ (NSArray *)mentionEntitiesForMessageText:(NSString *)messageText;

@end
