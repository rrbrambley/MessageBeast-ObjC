//
//  AATTChannelSpec.m
//  MessageBeast
//
//  Created by Rob Brambley on 12/23/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTChannelSpec.h"

@implementation AATTChannelSpec

- (id)initWithType:(NSString *)type queryParameters:(NSDictionary *)queryParameters {
    self = [super init];
    if(self) {
        self.type = type;
        self.queryParameters = queryParameters;
    }
    return self;
}

@end
