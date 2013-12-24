//
//  AATTActionMessageManager.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 12/1/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AATTMessageManager.h"

@interface AATTActionMessageManager : NSObject

typedef void (^AATTActionMessageManagerChannelInitBlock)(ANKChannel *actionChannel, NSError *error);

+ (AATTActionMessageManager *)sharedInstanceWithMessageManager:(AATTMessageManager *)messageManager;

#pragma mark - Action Channel

- (void)initActionChannelWithType:(NSString *)actionType targetChannel:(ANKChannel *)targetChannel completionBlock:(AATTActionMessageManagerChannelInitBlock)completionBlock;

#pragma mark - Lookup

- (BOOL)isActionedTargetMessageID:(NSString *)targetMessageID inActionChannelWithID:(NSString *)actionChannelID;

#pragma mark - Other Getters

- (AATTMessageManager *)messageManager;

#pragma mark - Retrieval

- (void)fetchAndPersistAllMessagesInActionChannelWithID:(NSString *)actionChannelId targetChannelId:(NSString *)targetChannelId completionBlock:(AATTMessageManagerCompletionBlock)completionBlock;

#pragma mark - Apply/Remove Actions

- (void)applyActionForActionChannelWithID:(NSString *)actionChannelID toTargetMessagePlus:(AATTMessagePlus *)messagePlus;
- (void)removeActionForActionChannelWithID:(NSString *)actionChannelID fromTargetMessageWithID:(NSString *)targetMessageID;
@end
