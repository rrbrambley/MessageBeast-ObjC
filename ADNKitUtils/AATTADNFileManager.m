//
//  AATTADNFileManager.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 12/6/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTADNDatabase.h"
#import "AATTADNFileManager.h"
#import "AATTPendingFile.h"

@interface AATTADNFileManager ()
@property AATTADNDatabase *database;
@end

@implementation AATTADNFileManager

+ (instancetype)sharedInstance {
    static AATTADNFileManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[AATTADNFileManager alloc] init];
    });
    
    return sharedInstance;
}

- (id)init {
    self = [super init];
    if(self) {
        self.database = [AATTADNDatabase sharedInstance];
    }
    return self;
}

- (AATTPendingFile *)addPendingFileWithURL:(NSURL *)URL type:(NSString *)type mimeType:(NSString *)mimeType kind:(NSString *)kind isPublic:(BOOL)isPublic {
    AATTPendingFile *pendingFile = [[AATTPendingFile alloc] init];
    pendingFile.URL = URL;
    pendingFile.ID = [[NSUUID UUID] UUIDString];
    pendingFile.type = type;
    pendingFile.mimeType = mimeType;
    pendingFile.kind = kind;
    pendingFile.isPublic = isPublic;
    
    [self.database insertOrReplacePendingFile:pendingFile];
    return pendingFile;
}

- (AATTPendingFile *)pendingFileWithID:(NSString *)pendingFileID {
    return [self.database pendingFileWithID:pendingFileID];
}

@end
