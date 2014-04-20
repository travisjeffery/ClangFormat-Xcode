//
//  NSDocument+TRVSClangFormat.h
//  ClangFormat
//
//  Created by Travis Jeffery on 1/11/14.
//  Copyright (c) 2014 Travis Jeffery. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSDocument (TRVSClangFormat)

+ (BOOL)trvs_formatOnSave;
+ (void)settrvs_formatOnSave:(BOOL)formatOnSave;

- (BOOL)trvs_shouldFormat;

@end
