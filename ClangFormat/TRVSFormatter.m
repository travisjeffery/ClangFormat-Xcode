//
//  TRVSFormatter.m
//  ClangFormat
//
//  Created by Travis Jeffery on 1/9/14.
//  Copyright (c) 2014 Travis Jeffery. All rights reserved.
//

#import "TRVSFormatter.h"
#import "TRVSXcode.h"

@interface TRVSCodeFragment : NSObject

@property(nonatomic, copy) NSString *string;
@property(nonatomic, copy) NSString *formattedString;
@property(nonatomic) NSRange range;
@property(nonatomic, strong) NSURL *fileURL;
@property(nonatomic, strong) TRVSFormatter *formatter;

@end

@implementation TRVSCodeFragment

@end

@implementation TRVSFormatter

- (instancetype)initWithStyle:(NSString *)style {
  self = [self init];

  if (self) {
    self.style = style;
  }
  
  return self;
}

- (void)formatActiveFile {
  if ([TRVSXcode hasSelection]) {
    [self formatRanges:[[TRVSXcode textView] selectedRanges] inDocument:[TRVSXcode sourceCodeDocument]];
  } else {
    [self formatRanges:@[[NSValue valueWithRange:[TRVSXcode wholeRange]]] inDocument:[TRVSXcode sourceCodeDocument]];
  }
}

- (void)formatSelectedFiles {
  // need to get the files
}

- (void)formatRanges:(NSArray *)ranges inDocument:(IDESourceCodeDocument *)document {
  DVTSourceTextStorage *textStorage = [document textStorage];
  
  NSMutableArray *lineRanges = [[NSMutableArray alloc] init];
  
  [ranges enumerateObjectsUsingBlock:^(NSValue *rangeValue, NSUInteger idx, BOOL *stop) {
     [lineRanges addObject:[NSValue valueWithRange:[textStorage lineRangeForCharacterRange:[rangeValue rangeValue]]]];
  }];
  
  NSArray *continuousLineRanges = [self continuousLinesRangeForRanges:lineRanges];
  
  NSMutableArray *fragments = [[NSMutableArray alloc] init];
  
  [continuousLineRanges enumerateObjectsUsingBlock:^(NSValue *rangeValue, NSUInteger idx, BOOL *stop) {
    NSRange lineRange = [rangeValue rangeValue];
    NSRange characterRange = [textStorage characterRangeForLineRange:lineRange];

    if (characterRange.location == NSNotFound) return;
    
    NSString *string = [[textStorage string] substringWithRange:characterRange];
    
    if (!string.length) return;

    TRVSCodeFragment *fragment = [[TRVSCodeFragment alloc] init];
    fragment.string = string;
    fragment.range = characterRange;
    fragment.fileURL = document.fileURL;
    NSURL *tmpFileURL = [fragment.fileURL URLByAppendingPathExtension:@"trvs"];
    [fragment.string writeToURL:tmpFileURL atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [self formatFilesAtURLs:@[tmpFileURL]];
    fragment.formattedString = [NSString stringWithContentsOfURL:tmpFileURL encoding:NSUTF8StringEncoding error:NULL];
    
    [fragments addObject:fragment];
  }];
  
  NSMutableArray *selectionRanges = [[NSMutableArray alloc] init];
  
  [fragments enumerateObjectsUsingBlock:^(TRVSCodeFragment *fragment, NSUInteger idx, BOOL *stop) {
    [textStorage beginEditing];
    [textStorage replaceCharactersInRange:fragment.range withString:fragment.formattedString withUndoManager:document.undoManager];
    
    if (selectionRanges.count > 0) {
      NSUInteger i = 0;
      while (i < selectionRanges.count) {
        NSRange range = [[selectionRanges objectAtIndex:i] rangeValue];
        range.location = range.location + [textStorage changeInLength];
        [selectionRanges replaceObjectAtIndex:i withObject:[NSValue valueWithRange:range]];
        i++;
      }
    }
    
    NSRange editedRange = [textStorage editedRange];
    if (editedRange.location != NSNotFound)
      [selectionRanges addObject:[NSValue valueWithRange:editedRange]];
    
    [textStorage endEditing];
  }];
  
  if (selectionRanges.count > 0)
    [[TRVSXcode textView] setSelectedRanges:selectionRanges];
}

- (NSArray *)continuousLinesRangeForRanges:(NSArray *)ranges {
  NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];

  [ranges enumerateObjectsUsingBlock:^(NSValue *rangeValue, NSUInteger idx, BOOL *stop) {
    [indexSet addIndexesInRange:[rangeValue rangeValue]];
  }];
  
  NSMutableArray *continuousRanges = [[NSMutableArray alloc] init];
  
  [indexSet enumerateRangesUsingBlock:^(NSRange range, BOOL *stop) {
    [continuousRanges addObject:[NSValue valueWithRange:range]];
  }];
  
  return continuousRanges;
}

- (void)formatFilesAtURLs:(NSArray *)fileURLs {
  [fileURLs enumerateObjectsUsingBlock:^(NSURL *URL, NSUInteger idx, BOOL *stop) {
    if (![[NSFileManager defaultManager] fileExistsAtPath:URL.path]) return;
    
    NSMutableArray *arguments = [[NSMutableArray alloc] init];
    [arguments addObject:[NSString stringWithFormat:@"--style=%@", self.style]];
    [arguments addObject:URL.path];
    
    NSPipe *outputPipe = [NSPipe pipe];
    
    NSTask *task = [[NSTask alloc] init];
    task.standardOutput = outputPipe;
    task.launchPath = self.executablePath;
    task.arguments = arguments;
    
    [outputPipe.fileHandleForReading readToEndOfFileInBackgroundAndNotify];
    
    [task launch];
    [task waitUntilExit];
  }];
}

@end
