//
//  AATTPendingFile.h
//  ADNKitUtils
//
//  Created by Rob Brambley on 12/6/13.
//  Copyright (c) 2013 Always All The Time. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AATTPendingFile : NSObject

@property NSString *ID;
@property NSURL *URL;
@property NSString *type;
@property NSString *name;
@property NSString *mimeType;
@property NSString *kind;
@property BOOL isPublic;
@property NSInteger sendAttemptsCount;
@property (readonly) ANKFile *file;

+ (instancetype)pendingFileWithFileAtURL:(NSURL *)URL;

- (NSInteger)incrementSendAttemptsCount;

@end
