//
//  NSObject+AATTPersistence.h
//  MessageBeast
//
//  Created by Rob Brambley on 11/5/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (AATTPersistence)

/**
 A convenience method for obtaining an NSObject from NSUserDefaults
 */
+ (NSObject *)objectForKey:(NSString *)key;

/**
 A convenience method for saving an NSObject to NSUserDefaults
 */
+ (void)saveObject:(NSObject *)obj forKey:(NSString *)key;

/**
 A convenience method for obtaining NSData from NSUserDefaults
 */
+ (NSData *)codingObjectForKey:(NSString *)key;

/**
 A convenience method for saving a NSCoding object to NSUserDefaults
 */
+ (void)saveCodingObject:(NSObject<NSCoding> *)obj forKey:(NSString *)key;

@end
