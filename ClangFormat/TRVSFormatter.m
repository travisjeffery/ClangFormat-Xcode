//
//  TRVSFormatter.m
//  ClangFormat
//
//  Created by Travis Jeffery on 1/9/14.
//  Copyright (c) 2014 Travis Jeffery. All rights reserved.
//

#import "TRVSFormatter.h"
#import "TRVSXcode.h"
#import "TRVSCodeFragment.h"
#import "NSDocument+TRVSClangFormat.h"

@interface TRVSFormatter ()

@property (nonatomic, copy) NSSet *supportedFileTypes;

@end

@implementation TRVSFormatter

+ (instancetype)sharedFormatter {
  static id sharedFormatter = nil;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
      sharedFormatter = [[self alloc] initWithStyle:nil
                                     executablePath:nil
                               useSystemClangFormat:NO];
  });

  return sharedFormatter;
}

- (instancetype)initWithStyle:(NSString *)style
               executablePath:(NSString *)executablePath
         useSystemClangFormat:(BOOL)useSystemClangFormat {
  if (self = [self init]) {
    self.style = style;
    self.executablePath = executablePath;
    self.useSystemClangFormat = useSystemClangFormat;
  }
  return self;
}

- (void)formatActiveFile {
  [self formatRanges:
            @[ [NSValue valueWithRange:[TRVSXcode wholeRangeOfTextView]] ]
          inDocument:[TRVSXcode sourceCodeDocument]];
}

- (void)formatSelectedCharacters {
  if (![TRVSXcode textViewHasSelection])
    return;

  [self formatRanges:[[TRVSXcode textView] selectedRanges]
          inDocument:[TRVSXcode sourceCodeDocument]];
}

- (void)formatSelectedFiles {
  [[TRVSXcode selectedFileNavigableItems]
      enumerateObjectsUsingBlock:^(IDEFileNavigableItem *fileNavigableItem,
                                   NSUInteger idx,
                                   BOOL *stop) {
          NSDocument *document = [IDEDocumentController
              retainedEditorDocumentForNavigableItem:fileNavigableItem
                                               error:NULL];

          if ([document
                  isKindOfClass:NSClassFromString(@"IDESourceCodeDocument")]) {
            IDESourceCodeDocument *sourceCodeDocument =
                (IDESourceCodeDocument *)document;

            [self
                formatRanges:
                    @[
                      [NSValue
                          valueWithRange:
                              NSMakeRange(
                                  0, [[sourceCodeDocument textStorage] length])]
                    ]
                  inDocument:sourceCodeDocument];

            [document saveDocument:nil];
          }

          [IDEDocumentController releaseEditorDocument:document];
      }];
}

- (void)formatDocument:(IDESourceCodeDocument *)document {
  NSUInteger location = [[TRVSXcode textView] selectedRange].location;
  NSUInteger length = [[document textStorage] length];

  [self formatRanges:@[ [NSValue valueWithRange:NSMakeRange(0, length)] ]
          inDocument:document];

  NSUInteger textStorageLength = [[document textStorage] length];
  NSUInteger diff = MAX(length, textStorageLength) - MIN(length, textStorageLength);

  BOOL documentIsLongerAfterFormatting =
      length > [[document textStorage] length];

  if (documentIsLongerAfterFormatting && location > diff) {
    location -= diff;
  } else if (!documentIsLongerAfterFormatting) {
    location += diff;
  }

  NSRange range = NSMakeRange(location, 0);
  [[TRVSXcode textView] setSelectedRange:range];
  [[TRVSXcode textView] scrollRangeToVisible:range];
}

#pragma mark - Private

- (void)formatRanges:(NSArray *)ranges
          inDocument:(IDESourceCodeDocument *)document {
  if (![document trvs_shouldFormat])
    return;

  DVTSourceTextStorage *textStorage = [document textStorage];

  NSArray *lineRanges =
      [self lineRangesOfCharacterRanges:ranges usingTextStorage:textStorage];
  NSArray *continuousLineRanges =
      [self continuousLineRangesOfRanges:lineRanges];
  [self
      fragmentsOfContinuousLineRanges:continuousLineRanges
                     usingTextStorage:textStorage
                         withDocument:document
                                block:^(NSArray *fragments, NSArray *errors) {
                                    if (errors.count == 0) {
                                      NSArray *selectionRanges = [self
                                          selectionRangesAfterReplacingFragments:
                                              fragments usingTextStorage:
                                                            textStorage
                                                                    withDocument:
                                                                        document];

                                      if (selectionRanges.count > 0)
                                        [[TRVSXcode textView]
                                            setSelectedRanges:selectionRanges];
                                    } else {
                                      NSAlert *alert = [NSAlert new];
                                      alert.messageText =
                                          [(NSError *)errors.firstObject
                                                  localizedDescription];
                                      [alert runModal];
                                    }
                                }];
}

- (NSArray *)
    selectionRangesAfterReplacingFragments:(NSArray *)fragments
                          usingTextStorage:(DVTSourceTextStorage *)textStorage
                              withDocument:(IDESourceCodeDocument *)document {
  NSMutableArray *selectionRanges = [[NSMutableArray alloc] init];

  [fragments enumerateObjectsUsingBlock:^(TRVSCodeFragment *fragment,
                                          NSUInteger idx,
                                          BOOL *stop) {
      [textStorage beginEditing];

      [textStorage replaceCharactersInRange:fragment.rangeToReplace
                                 withString:fragment.formattedString
                            withUndoManager:document.undoManager];

      [self addSelectedRangeToSelectedRanges:selectionRanges
                            usingTextStorage:textStorage];

      [textStorage endEditing];
  }];

  return selectionRanges;
}

- (void)addSelectedRangeToSelectedRanges:(NSMutableArray *)selectionRanges
                        usingTextStorage:(DVTSourceTextStorage *)textStorage {
  if (selectionRanges.count > 0) {
    NSUInteger i = 0;

    while (i < selectionRanges.count) {
      NSRange range = [[selectionRanges objectAtIndex:i] rangeValue];
      range.location += [textStorage changeInLength];
      [selectionRanges replaceObjectAtIndex:i
                                 withObject:[NSValue valueWithRange:range]];
      i++;
    }
  }

  NSRange editedRange = textStorage.editedRange;
  if (editedRange.location != NSNotFound) {
    [selectionRanges addObject:[NSValue valueWithRange:editedRange]];
  }
}

- (void)fragmentsOfContinuousLineRanges:(NSArray *)continuousLineRanges
                       usingTextStorage:(DVTSourceTextStorage *)textStorage
                           withDocument:(IDESourceCodeDocument *)document
                                  block:(void (^)(NSArray *fragments,
                                                  NSArray *errors))block {
  NSMutableArray *fragments = [[NSMutableArray alloc] init];
  NSMutableArray *errors = [[NSMutableArray alloc] init];

  NSString *executablePath = self.executablePath;
  if (self.useSystemClangFormat) {
    NSDictionary *environmentDict = [[NSProcessInfo processInfo] environment];
    NSString *shellString =
        [environmentDict objectForKey:@"SHELL"] ?: @"/bin/bash";

    NSPipe *outputPipe = [NSPipe pipe];
    NSPipe *errorPipe = [NSPipe pipe];

    NSTask *task = [[NSTask alloc] init];
    task.standardOutput = outputPipe;
    task.standardError = errorPipe;
    task.launchPath = shellString;
    task.arguments = @[ @"-l", @"-c", @"which clang-format" ];

    [task launch];
    [task waitUntilExit];
    [errorPipe.fileHandleForReading readDataToEndOfFile];
    NSData *outputData = [outputPipe.fileHandleForReading readDataToEndOfFile];
    NSString *outputPath = [[NSString alloc] initWithData:outputData
                                                 encoding:NSUTF8StringEncoding];
    outputPath = [outputPath
        stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
      
    BOOL isDirectory = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:outputPath isDirectory:&isDirectory] && !isDirectory) {
      executablePath = outputPath;
    }
  }

  [continuousLineRanges enumerateObjectsUsingBlock:^(NSValue *rangeValue,
                                                     NSUInteger idx,
                                                     BOOL *stop) {
      NSRange characterRange =
          [textStorage characterRangeForLineRange:[rangeValue rangeValue]];

      if (characterRange.location == NSNotFound)
        return;

      NSString *string =
          [[textStorage string] substringWithRange:characterRange];

      if (!string.length)
        return;

      TRVSCodeFragment *fragment = [TRVSCodeFragment
          fragmentUsingBlock:^(TRVSCodeFragmentBuilder *builder) {
              builder.string = [textStorage string];
              builder.textRange = characterRange;
              builder.fileURL = document.fileURL;
          }];

    // clang-format doesn't support descrete ranges, so only the first range
    // can be taken. This is fine because in practice, we have only one
    // selected range in Xcode.
    NSRange lineRange = [continuousLineRanges[0] rangeValue];
      __weak typeof(fragment) weakFragment = fragment;
      [fragment formatWithStyle:self.style
          usingClangFormatAtLaunchPath:executablePath
                             lineRange:lineRange
                                 block:^(NSString *formattedString,
                                         NSError *error) {
                                     __strong typeof(weakFragment)
                                         strongFragment = weakFragment;
                                     if (error) {
                                       [errors addObject:error];
                                       *stop = YES;
                                     } else {
                                       [fragments addObject:strongFragment];
                                     }
                                 }];
  }];

  block(fragments, errors);
}

- (NSArray *)lineRangesOfCharacterRanges:(NSArray *)characterRanges
                        usingTextStorage:(DVTSourceTextStorage *)textStorage {
  NSMutableArray *lineRanges = [[NSMutableArray alloc] init];

  [characterRanges enumerateObjectsUsingBlock:^(NSValue *rangeValue,
                                                NSUInteger idx,
                                                BOOL *stop) {
      [lineRanges
          addObject:[NSValue valueWithRange:[textStorage
                                                lineRangeForCharacterRange:
                                                    [rangeValue rangeValue]]]];
  }];

  return lineRanges;
}

- (NSArray *)continuousLineRangesOfRanges:(NSArray *)ranges {
  NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];

  [ranges enumerateObjectsUsingBlock:^(NSValue *rangeValue,
                                       NSUInteger idx,
                                       BOOL *stop) {
      [indexSet addIndexesInRange:[rangeValue rangeValue]];
  }];

  NSMutableArray *continuousRanges = [[NSMutableArray alloc] init];

  [indexSet enumerateRangesUsingBlock:^(NSRange range, BOOL *stop) {
      [continuousRanges addObject:[NSValue valueWithRange:range]];
  }];

  return continuousRanges;
}

@end
