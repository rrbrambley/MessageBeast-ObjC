//
//  NSObject+AATTPersistence.m
//  MessageBeast
//
//  Created by Rob Brambley on 11/5/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "NSObject+AATTPersistence.h"

@implementation NSObject (AATTPersistence)

+ (NSObject *)objectForKey:(NSString *)key {
    NSObject *object;
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    if(standardUserDefaults) {
        object = [standardUserDefaults objectForKey:key];
    }
    return object;
}

+ (void)saveObject:(NSObject *)obj forKey:(NSString *)key {
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    if(standardUserDefaults) {
        [standardUserDefaults setObject:obj forKey:key];
        [standardUserDefaults synchronize];
    }
}

+ (NSData *)codingObjectForKey:(NSString *)key {
    NSData *codedObj = (NSData *)[self objectForKey:key];
    if(codedObj) {
        return [NSKeyedUnarchiver unarchiveObjectWithData:codedObj];
    }
    return nil;
}

+ (void)saveCodingObject:(NSObject<NSCoding> *)obj forKey:(NSString *)key {
    [self saveObject:[NSKeyedArchiver archivedDataWithRootObject:obj] forKey:key];
}

@end
