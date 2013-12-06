//
//  AATTADNFileManager.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 12/6/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AATTADNFileManager : NSObject

typedef void (^AATTFileManagerCompletionBlock)(ANKFile *file, ANKAPIResponseMeta *meta, NSError *error);

- (id)initWithClient:(ANKClient *)client;

- (AATTPendingFile *)addPendingFileWithURL:(NSURL *)URL type:(NSString *)type mimeType:(NSString *)mimeType kind:(NSString *)kind isPublic:(BOOL)isPublic;
- (AATTPendingFile *)pendingFileWithID:(NSString *)pendingFileID;
- (void)uploadPendingFileWithID:(NSString *)pendingFileID completionBlock:(AATTFileManagerCompletionBlock)completionBlock;

@end
