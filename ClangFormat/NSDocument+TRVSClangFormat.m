//
//  NSDocument+TRVSClangFormat.m
//  ClangFormat
//
//  Created by Travis Jeffery on 1/11/14.
//  Copyright (c) 2014 Travis Jeffery. All rights reserved.
//

#import "NSDocument+TRVSClangFormat.h"
#import <objc/runtime.h>
#import "TRVSFormatter.h"

static BOOL trvs_formatOnSave;

@implementation NSDocument (TRVSClangFormat)

+ (void)settrvs_formatOnSave:(BOOL)formatOnSave {
  trvs_formatOnSave = formatOnSave;
}

+ (BOOL)trvs_formatOnSave {
  return trvs_formatOnSave;
}

- (void)trvs_saveDocumentWithDelegate:(id)delegate
                      didSaveSelector:(SEL)didSaveSelector
                          contextInfo:(void *)contextInfo {
  if ([[self class] trvs_formatOnSave])
    [[TRVSFormatter sharedFormatter]
        formatDocument:(IDESourceCodeDocument *)self];

  [self trvs_saveDocumentWithDelegate:delegate
                      didSaveSelector:didSaveSelector
                          contextInfo:contextInfo];
}

+ (void)load {
  Method original, swizzle;

  original = class_getInstanceMethod(
      self,
      NSSelectorFromString(
          @"saveDocumentWithDelegate:didSaveSelector:contextInfo:"));
  swizzle = class_getInstanceMethod(
      self,
      NSSelectorFromString(
          @"trvs_saveDocumentWithDelegate:didSaveSelector:contextInfo:"));

  method_exchangeImplementations(original, swizzle);
}

@end
