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

- (id)initWithMessageManager:(AATTMessageManager *)messageManager;
- (void)fetchAndPersistAllMessagesInActionChannelWithID:(NSString *)actionChannelId targetChannelId:(NSString *)targetChannelId batchSyncBlock:(AATTMessageManagerBatchSyncBlock)block completionBlock:(AATTMessageManagerCompletionBlock)completionBlock;
@end
