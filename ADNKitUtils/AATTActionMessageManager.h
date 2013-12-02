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

- (id)initWithMessageManager:(AATTMessageManager *)messageManager;

- (void)initActionChannelWithType:(NSString *)actionType targetChannel:(ANKChannel *)targetChannel completionBlock:(AATTActionMessageManagerChannelInitBlock)completionBlock;
- (void)fetchAndPersistAllMessagesInActionChannelWithID:(NSString *)actionChannelId targetChannelId:(NSString *)targetChannelId completionBlock:(AATTMessageManagerCompletionBlock)completionBlock;
@end
