//
//  Xcode.h
//  ClangFormat
//
//  Created by Travis Jeffery on 1/7/14.
//  Copyright (c) 2014 Travis Jeffery. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TRVSPrivateXcode.h"

@interface TRVXcode : NSObject

+ (IDEWorkspaceDocument *)workspaceDocument;
+ (IDESourceCodeDocument *)sourceCodeDocument;
+ (NSTextView *)textView;
+ (BOOL)hasSelection;
+ (void)replaceTextWithString:(NSString *)string;
+ (NSArray *)selectedFileNavigableItems;

@end
