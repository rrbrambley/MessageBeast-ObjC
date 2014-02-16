//
//  AATTPendingMessageDeletion.h
//  MessageBeast
//
//  Created by Rob Brambley on 12/12/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AATTPendingMessageDeletion : NSObject

@property NSString *messageID;
@property NSString *channelID;

- (id)initWithMessageID:(NSString *)messageID channelID:(NSString *)channelID;

@end
