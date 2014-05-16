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
#import "TRVSXcode.h"
#import <objc/runtime.h>

static BOOL trvs_formatOnSave;
static BOOL trvs_formatOnBuild;

@implementation NSDocument (TRVSClangFormat)

- (void)trvs_saveDocumentWithDelegate:(id)delegate
                      didSaveSelector:(SEL)didSaveSelector
                          contextInfo:(void *)contextInfo {
  // if trvs_formatOnBuild is set this will be handled at a lower level.
  if ([NSDocument trvs_formatOnSave] && ![NSDocument trvs_formatOnBuild] &&
      [self trvs_shouldFormatBeforeSaving])
    [[TRVSFormatter sharedFormatter]
        formatDocument:(IDESourceCodeDocument *)self];

  [self trvs_saveDocumentWithDelegate:delegate
                      didSaveSelector:didSaveSelector
                          contextInfo:contextInfo];
}

- (void)trvs_saveToURL:(NSURL *)url
                ofType:(NSString *)typeName
      forSaveOperation:(NSSaveOperationType)saveOperation
     completionHandler:(void (^)(NSError *))completionHandler {

  // only format on build if format on save is also enabled and the save
  // operation is NSSaveOperation an explict save.
  if ([NSDocument trvs_formatOnSave] && [NSDocument trvs_formatOnBuild] &&
      [self trvs_shouldFormatBeforeSaving] &&
      saveOperation == NSSaveOperation) {
    [[TRVSFormatter sharedFormatter]
        formatDocument:(IDESourceCodeDocument *)self];
  }

  [self trvs_saveToURL:url
                 ofType:typeName
       forSaveOperation:saveOperation
      completionHandler:completionHandler];
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

  original = class_getInstanceMethod(
      self,
      NSSelectorFromString(
          @"saveToURL:ofType:forSaveOperation:completionHandler:"));
  swizzle = class_getInstanceMethod(
      self,
      NSSelectorFromString(
          @"trvs_saveToURL:ofType:forSaveOperation:completionHandler:"));

  method_exchangeImplementations(original, swizzle);
}

+ (void)settrvs_formatOnSave:(BOOL)formatOnSave {
  trvs_formatOnSave = formatOnSave;
}

+ (BOOL)trvs_formatOnSave {
  return trvs_formatOnSave;
}

+ (void)settrvs_formatOnBuild:(BOOL)formatOnBuild {
  trvs_formatOnBuild = formatOnBuild;
}

+ (BOOL)trvs_formatOnBuild {
  return trvs_formatOnBuild;
}

- (BOOL)trvs_shouldFormatBeforeSaving {
  return [self trvs_shouldFormat] && [TRVSXcode sourceCodeDocument] == self;
}

- (BOOL)trvs_shouldFormat {
  return [[NSSet setWithObjects:@"c", @"h", @"mm", @"cpp", @"m", nil]
      containsObject:[[[self fileURL] pathExtension] lowercaseString]];
}

@end
