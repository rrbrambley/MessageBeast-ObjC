//
//  AATTADNFileManager.m
//  MessageBeast
//
//  Created by Rob Brambley on 12/6/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
#import <AssetsLibrary/AssetsLibrary.h>
#endif

#import "AATTADNDatabase.h"
#import "AATTADNFileManager.h"
#import "AATTPendingFile.h"

@interface AATTADNFileManager ()
@property AATTADNDatabase *database;
@property ANKClient *client;
@property NSMutableSet *filesInProgress;
@end

@implementation AATTADNFileManager

- (id)initWithClient:(ANKClient *)client {
    self = [super init];
    if(self) {
        self.client = client;
        self.database = [AATTADNDatabase sharedInstance];
        self.filesInProgress = [NSMutableSet set];
    }
    return self;
}

- (AATTPendingFile *)addPendingFileWithURL:(NSURL *)URL name:(NSString *)name type:(NSString *)type mimeType:(NSString *)mimeType kind:(NSString *)kind isPublic:(BOOL)isPublic {
    AATTPendingFile *pendingFile = [[AATTPendingFile alloc] init];
    pendingFile.URL = URL;
    pendingFile.ID = [[NSUUID UUID] UUIDString];
    pendingFile.name = name;
    pendingFile.type = type;
    pendingFile.mimeType = mimeType;
    pendingFile.kind = kind;
    pendingFile.isPublic = isPublic;
    
    [self.database insertOrReplacePendingFile:pendingFile];
    return pendingFile;
}

- (void)addPendingFile:(AATTPendingFile *)pendingFile {
    [self.database insertOrReplacePendingFile:pendingFile];
}

- (AATTPendingFile *)pendingFileWithID:(NSString *)pendingFileID {
    return [self.database pendingFileWithID:pendingFileID];
}

- (void)uploadPendingFileWithID:(NSString *)pendingFileID completionBlock:(AATTFileManagerCompletionBlock)completionBlock {
    if(![self.filesInProgress containsObject:pendingFileID]) {
        [self.filesInProgress addObject:pendingFileID];
        
        AATTPendingFile *pendingFile = [self pendingFileWithID:pendingFileID];
        NSAssert(pendingFile, @"pending file with id %@ doesn't exist in database", pendingFileID);
        
        ANKFile *file = pendingFile.file;
        
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
        ALAssetsLibrary* assetslibrary = [[ALAssetsLibrary alloc] init];
        
        [assetslibrary assetForURL:pendingFile.URL resultBlock:^(ALAsset *asset) {
            ALAssetRepresentation *representation = [asset defaultRepresentation];
            CGImageRef ref = [representation fullResolutionImage];
            NSData *data = UIImageJPEGRepresentation([UIImage imageWithCGImage:ref], 1);
            
            [self.client createFile:file withData:data completion:^(id responseObject, ANKAPIResponseMeta *meta, NSError *error) {
                [self.filesInProgress removeObject:pendingFileID];
                if(!error) {
                    [self.database deletePendingFile:pendingFile];
                    completionBlock(responseObject, meta, error);
                } else {
                    [pendingFile incrementSendAttemptsCount];
                    [self.database insertOrReplacePendingFile:pendingFile];
                    completionBlock(nil, meta, error);
                }
            }];
        } failureBlock:^(NSError *error) {
            [self.filesInProgress removeObject:pendingFileID];
            completionBlock(nil, nil, error);
        }];
#endif
        
//TODO: handle OS X
        
    } else {
        completionBlock(nil, nil, nil);
    }
}

@end
