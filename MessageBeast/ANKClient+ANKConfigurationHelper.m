//
//  ANKClient+ANKConfigurationHelper.m
//  MessageBeast
//
//  Created by Rob Brambley on 4/2/14.
//  Copyright (c) 2014 Always All The Time. All rights reserved.
//

#import "AATTADNPersistence.h"
#import "ANKClient+ANKConfigurationHelper.h"

@implementation ANKClient (ANKConfigurationHelper)

- (void)updateConfigurationIfDueWithCompletion:(void (^)(BOOL didUpdate))completionBlock {
    NSDate *saveDate = [AATTADNPersistence configurationSaveDate];
    
    BOOL fetch = !saveDate;
    if(!fetch) {
        NSUInteger unitFlags = NSDayCalendarUnit;
        NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        NSDateComponents *components = [calendar components:unitFlags fromDate:saveDate toDate:[NSDate date] options:0];
        fetch = ABS([components day]) >= 1;
    }
    
    if(fetch) {
        [self fetchConfigurationWithCompletion:^(id responseObject, ANKAPIResponseMeta *meta, NSError *error) {
            if(!error && responseObject) {
                ANKConfiguration *configuration = responseObject;
                [AATTADNPersistence saveConfiguration:configuration];
            }
            if(completionBlock) {
                completionBlock(!error && responseObject);
            }
        }];
    } else if(completionBlock) {
        completionBlock(fetch);
    }
}

@end
