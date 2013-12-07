//
//  AATTPendingFile.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 12/6/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTPendingFile.h"

@implementation AATTPendingFile

+ (instancetype)pendingFileWithFileAtURL:(NSURL *)URL {
    ANKFile *file = [ANKFile fileWithFileAtURL:URL];
    AATTPendingFile *pendingFile = [[AATTPendingFile alloc] init];
    pendingFile.name = file.name;
    pendingFile.mimeType = file.mimeType;
    pendingFile.kind = file.kind;
    pendingFile.URL = URL;
    pendingFile.ID = [[NSUUID UUID] UUIDString];
    return pendingFile;
}

- (NSInteger)incrementSendAttemptsCount {
    self.sendAttemptsCount++;
    return self.sendAttemptsCount;
}

- (ANKFile *)file {
    ANKFile *file = [ANKFile fileWithFileAtURL:self.URL];
    file.isPublic = self.isPublic;
    file.type = self.type;
    return file;
}

@end
