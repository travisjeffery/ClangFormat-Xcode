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
      sharedFormatter = [[self alloc] initWithStyle:nil executablePath:nil];
  });

  return sharedFormatter;
}

- (instancetype)initWithStyle:(NSString *)style
               executablePath:(NSString *)executablePath {
  if (self = [self init]) {
    self.style = style;
    self.executablePath = executablePath;
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

          if (![document shouldFormat])
            return;

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

  NSUInteger diff = labs(length - [[document textStorage] length]);

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
  DVTSourceTextStorage *textStorage = [document textStorage];

  NSArray *lineRanges =
      [self lineRangesOfCharacterRanges:ranges usingTextStorage:textStorage];
  NSArray *continuousLineRanges =
      [self continuousLineRangesOfRanges:lineRanges];
  NSArray *fragments =
      [self fragmentsOfContinuousLineRanges:continuousLineRanges
                           usingTextStorage:textStorage
                               withDocument:document];

  NSArray *selectionRanges =
      [self selectionRangesAfterReplacingFragments:fragments
                                  usingTextStorage:textStorage
                                      withDocument:document];

  if (selectionRanges.count > 0)
    [[TRVSXcode textView] setSelectedRanges:selectionRanges];
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

      [textStorage replaceCharactersInRange:fragment.range
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

  NSRange editedRange = [textStorage editedRange];
  if (editedRange.location != NSNotFound)
    [selectionRanges addObject:[NSValue valueWithRange:editedRange]];
}

- (NSArray *)fragmentsOfContinuousLineRanges:(NSArray *)continuousLineRanges
                            usingTextStorage:(DVTSourceTextStorage *)textStorage
                                withDocument:(IDESourceCodeDocument *)document {
  NSMutableArray *fragments = [[NSMutableArray alloc] init];

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

      TRVSCodeFragment *fragment = [[TRVSCodeFragment alloc] init];
      fragment.string = string;
      fragment.range = characterRange;
      fragment.fileURL = document.fileURL;
      [fragment formatWithStyle:self.style
          usingClangFormatAtLaunchPath:self.executablePath];

      [fragments addObject:fragment];
  }];

  return fragments;
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

- (BOOL)shouldFormatDocument:(NSDocument *)document {
  return [[self supportedFileTypes]
      containsObject:[[[document fileURL] pathExtension] lowercaseString]];
}

- (NSSet *)supportedFileTypes {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
      _supportedFileTypes =
          [NSSet setWithObjects:@"c", @"h", @"mm", @"cpp", @"m", nil];
  });
  return _supportedFileTypes;
}

@end
