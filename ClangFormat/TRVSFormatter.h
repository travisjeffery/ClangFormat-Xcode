//
//  TRVSFormatter.h
//  ClangFormat
//
//  Created by Travis Jeffery on 1/9/14.
//  Copyright (c) 2014 Travis Jeffery. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class IDESourceCodeDocument;

@interface TRVSFormatter : NSObject

@property (nonatomic, copy) NSString *style;
@property (nonatomic, copy) NSString *executablePath;

+ (instancetype)sharedFormatter;
- (instancetype)initWithStyle:(NSString *)style
               executablePath:(NSString *)executablePath;
- (void)formatActiveFile;
- (void)formatSelectedCharacters;
- (void)formatSelectedFiles;
- (void)formatDocument:(IDESourceCodeDocument *)document;

- (void)deleteLine;

@end
