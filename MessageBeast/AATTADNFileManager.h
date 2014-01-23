//
//  AATTADNFileManager.h
//  MessageBeast
//
//  Created by Rob Brambley on 12/6/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AATTADNFileManager : NSObject

typedef void (^AATTFileManagerCompletionBlock)(ANKFile *file, ANKAPIResponseMeta *meta, NSError *error);

- (id)initWithClient:(ANKClient *)client;

- (AATTPendingFile *)addPendingFileWithURL:(NSURL *)URL name:(NSString *)name type:(NSString *)type mimeType:(NSString *)mimeType kind:(NSString *)kind isPublic:(BOOL)isPublic;
- (void)addPendingFile:(AATTPendingFile *)pendingFile;
- (AATTPendingFile *)pendingFileWithID:(NSString *)pendingFileID;
- (void)uploadPendingFileWithID:(NSString *)pendingFileID completionBlock:(AATTFileManagerCompletionBlock)completionBlock;

@end
