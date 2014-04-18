//
//  AATTEntityGenerator.m
//  MessageBeast
//
//  Created by Rob Brambley on 4/17/14.
//  Copyright (c) 2014 Always All The Time. All rights reserved.
//

#import "AATTEntityGenerator.h"

@implementation AATTEntityGenerator

+ (ANKEntities *)entitiesForMessageText:(NSString *)messageText {
    ANKEntities *entities = [[ANKEntities alloc] init];
    entities.hashtags = [self hashtagEntitiesForMessageText:messageText];
    entities.mentions = [self mentionEntitiesForMessageText:messageText];
    entities.links = [self linkEntitiesForMessageText:messageText];
    return entities;
}

+ (NSArray *)hashtagEntitiesForMessageText:(NSString *)messageText {
    static NSString *pattern = @"\\B#\\w*[a-zA-Z]+\\w";
    
    NSError *error = NULL;
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    NSArray *matches = [expression matchesInString:messageText options:0 range:NSMakeRange(0, messageText.length)];
    NSMutableArray *hashtagEntities = [[NSMutableArray alloc] initWithCapacity:matches.count];
    
    for(NSTextCheckingResult *match in matches) {
        ANKHashtagEntity *entity = [[ANKHashtagEntity alloc] init];
        entity.position = match.range.location;
        entity.length = match.range.length;
        entity.hashtag = [[messageText substringFromIndex:match.range.location+1] substringToIndex:match.range.length-1];
        [hashtagEntities addObject:entity];
    }
    
    return hashtagEntities;
}

+ (NSArray *)linkEntitiesForMessageText:(NSString *)messageText {
    NSMutableArray *linkEntities = [[NSMutableArray alloc] init];
    //TODO
    return linkEntities;
}

+ (NSArray *)mentionEntitiesForMessageText:(NSString *)messageText {
    NSMutableArray *mentionEntities = [[NSMutableArray alloc] init];
    //TODO
    return mentionEntities;
}
@end
