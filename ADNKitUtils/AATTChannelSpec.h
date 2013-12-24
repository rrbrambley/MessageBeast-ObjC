//
//  AATTChannelSpec.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 12/23/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AATTChannelSpec : NSObject

@property NSString *type;
@property NSDictionary *queryParameters;

- (id)initWithType:(NSString *)type queryParameters:(NSDictionary *)queryParameters;

@end
