//
//  TRVSCodeFragment.m
//  ClangFormat
//
//  Created by Travis Jeffery on 1/9/14.
//  Copyright (c) 2014 Travis Jeffery. All rights reserved.
//

#import "TRVSCodeFragment.h"
#import "XMLDictionary/XMLDictionary.h"

@interface TRVSCodeFragment ()

- (instancetype)initWithBuilder:(TRVSCodeFragmentBuilder *)builder;

@end

@implementation TRVSCodeFragmentBuilder

- (TRVSCodeFragment *)build {
  return [[TRVSCodeFragment alloc] initWithBuilder:self];
}

@end

@implementation TRVSCodeFragment

+ (instancetype)fragmentUsingBlock:
                    (void (^)(TRVSCodeFragmentBuilder *builder))block {
  TRVSCodeFragmentBuilder *builder = [TRVSCodeFragmentBuilder new];
  block(builder);
  return [builder build];
}

- (instancetype)initWithBuilder:(TRVSCodeFragmentBuilder *)builder {
  if (self = [super init]) {
    _string = [builder.string copy];
    _range = builder.range;
    _lineRange = builder.lineRange;
    _fileURL = builder.fileURL;
  }
  return self;
}

- (void)formatWithStyle:(NSString *)style
    usingClangFormatAtLaunchPath:(NSString *)launchPath
                           block:(void (^)(NSDictionary *replacements,
                                           NSError *error))block {
  char *tmpFilename = strdup(
      [[[self.fileURL URLByAppendingPathExtension:@"XXXXXX"] path] UTF8String]);
  int tmpFile = mkstemp(tmpFilename);

  write(tmpFile,
        [self.string UTF8String],
        [self.string lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
  close(tmpFile);
  NSURL *tmpFileURL =
      [NSURL fileURLWithPath:[NSString stringWithUTF8String:tmpFilename]];
  free(tmpFilename);

  NSData *errorData;
  NSPipe *outputPipe = [NSPipe pipe];
  NSPipe *errorPipe = [NSPipe pipe];

  NSRange lineRange = [self.lineRange rangeValue];

  // Xcode line ranges are zero-based, while clang-format's are one-based.
  NSUInteger firstLine = lineRange.location + 1;
  NSUInteger lastLine = firstLine + lineRange.length - 1;

  NSTask *task = [[NSTask alloc] init];
  task.standardOutput = outputPipe;
  task.standardError = errorPipe;
  task.launchPath = launchPath;
  task.arguments = @[
    [NSString stringWithFormat:@"-style=%@", style],
    [NSString stringWithFormat:@"-lines=%lu:%lu", firstLine, lastLine],
    @"-output-replacements-xml",
    [tmpFileURL path]
  ];

  [task launch];
  [task waitUntilExit];

  errorData = [errorPipe.fileHandleForReading readDataToEndOfFile];
  NSData *replacementData =
      [outputPipe.fileHandleForReading readDataToEndOfFile];

  XMLDictionaryParser *parser = [XMLDictionaryParser new];
  parser.trimWhiteSpace = NO;
  parser.stripEmptyNodes = NO;
  parser.alwaysUseArrays = YES;
  self.replacements = [parser dictionaryWithData:replacementData];

  block(
      self.replacements,
      errorData.length > 0
          ? [NSError
                errorWithDomain:@"com.travisjeffery.error"
                           code:-99
                       userInfo:@{
                                  NSLocalizedDescriptionKey : [[NSString alloc]
                                      initWithData:errorData
                                          encoding:NSUTF8StringEncoding]
                                }]
          : nil);

  [[NSFileManager defaultManager] removeItemAtURL:tmpFileURL error:NULL];
}

@end
