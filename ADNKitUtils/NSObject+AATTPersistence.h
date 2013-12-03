//
//  NSObject+AATTPersistence.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 11/5/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (AATTPersistence)

+ (NSObject *)objectForKey:(NSString *)key;
+ (void)saveObject:(NSObject *)obj forKey:(NSString *)key;
+ (NSData *)codingObjectForKey:(NSString *)key;
+ (void)saveCodingObject:(NSObject<NSCoding> *)obj forKey:(NSString *)key;

@end
