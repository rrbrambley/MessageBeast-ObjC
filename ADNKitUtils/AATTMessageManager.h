//
//  AATTMessageManager.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 10/30/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTMessageManagerConfiguration.h"

@interface AATTMessageManager : NSObject

- (id)initWithANKClient:(ANKClient *)client configuration:(AATTMessageManagerConfiguration *)configuration;

@end
