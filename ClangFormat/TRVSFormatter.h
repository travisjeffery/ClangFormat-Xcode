//
//  TRVSFormatter.h
//  ClangFormat
//
//  Created by Travis Jeffery on 1/9/14.
//  Copyright (c) 2014 Travis Jeffery. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TRVSFormatter : NSObject

@property(nonatomic, copy) NSString *style;
@property(nonatomic, copy) NSString *executablePath;

- (instancetype)initWithStyle:(NSString *)style;
- (void)formatActiveFile;
- (void)formatSelectedFiles;
- (void)formatFilesAtURLs:(NSArray *)fileURLs;

@end
