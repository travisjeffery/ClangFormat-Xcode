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
  self = [self init];

  if (self) {
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
  NSArray *fileNavigableItems = [TRVSXcode selectedFileNavigableItems];

  [fileNavigableItems
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
            NSTextStorage *textStorage = [sourceCodeDocument textStorage];
            NSRange wholeRange = NSMakeRange(0, [textStorage length]);

            BOOL errorsFound =
                [self formatRanges:@[ [NSValue valueWithRange:wholeRange] ]
                        inDocument:sourceCodeDocument];
            if (errorsFound) {
              *stop = YES;
            } else {
              [document saveDocument:nil];
            }
          }

          [IDEDocumentController releaseEditorDocument:document];
      }];
}

- (void)formatDocument:(IDESourceCodeDocument *)document {
  NSUInteger location = [[TRVSXcode textView] selectedRange].location;
  NSUInteger length = [[document textStorage] length];
  NSRange wholeRangeOfDocument = NSMakeRange(0, length);

  [self formatRanges:@[ [NSValue valueWithRange:wholeRangeOfDocument] ]
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

- (BOOL)formatRanges:(NSArray *)ranges
          inDocument:(IDESourceCodeDocument *)document {
  DVTSourceTextStorage *textStorage = [document textStorage];
  BOOL errorsFound = YES;
  NSArray *lineRanges =
      [self lineRangesOfCharacterRanges:ranges usingTextStorage:textStorage];

  NSArray *continuousLineRanges =
      [self continuousLineRangesOfRanges:lineRanges];

  NSArray *fragments =
      [self fragmentsOfContinuousLineRanges:continuousLineRanges
                           usingTextStorage:textStorage
                               withDocument:document];

  TRVSCodeFragment *firstUnsuccessfulFragment = nil;
  firstUnsuccessfulFragment = [self findFirstUnsuccessfulFragment:fragments];
  if (firstUnsuccessfulFragment) {
    [self presentClangFormatError:firstUnsuccessfulFragment.errorMessage];
    return errorsFound;
  }
  NSArray *selectionRanges =
      [self selectionRangesAfterReplacingFragments:fragments
                                  usingTextStorage:textStorage
                                      withDocument:document];

  if (selectionRanges.count > 0)
    [[TRVSXcode textView] setSelectedRanges:selectionRanges];
  return !errorsFound;
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

- (TRVSCodeFragment *)findFirstUnsuccessfulFragment:(NSArray *)fragments {
  __block TRVSCodeFragment *firstUnsuccessfulFragment = nil;
  [fragments
      enumerateObjectsUsingBlock:^(id fragment, NSUInteger idx, BOOL *stop) {
          if (![fragment formattedSuccessfully]) {
            firstUnsuccessfulFragment = fragment;
            *stop = YES;
          }
      }];
  return firstUnsuccessfulFragment;
}

- (void)presentClangFormatError:(NSString *)errorMessage {
  NSAlert *alert = [[NSAlert alloc] init];
  [alert setMessageText:errorMessage];
  [alert runModal];
}

@end
