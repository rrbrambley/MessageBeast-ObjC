//
//  ANKClient+ANKConfigurationHelper.h
//  MessageBeast
//
//  Created by Rob Brambley on 4/2/14.
//  Copyright (c) 2014 Always All The Time. All rights reserved.
//

@interface ANKClient (ANKConfigurationHelper)

/**
 Update the persisted Configuration if due.
 
 http://developers.app.net/docs/resources/config/#how-to-use-the-configuration-object
 
 @param completionBlock the completion block to use.
 */
- (void)updateConfigurationIfDueWithCompletion:(void (^)(BOOL didUpdate))completionBlock;

@end
