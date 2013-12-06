//
//  AATTPendingFile.m
//  ADNKitUtils
//
//  Created by Rob Brambley on 12/6/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import "AATTPendingFile.h"

@implementation AATTPendingFile

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
