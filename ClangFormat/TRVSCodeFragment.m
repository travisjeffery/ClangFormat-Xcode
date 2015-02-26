//
//  TRVSCodeFragment.m
//  ClangFormat
//
//  Created by Travis Jeffery on 1/9/14.
//  Copyright (c) 2014 Travis Jeffery. All rights reserved.
//

#import "TRVSCodeFragment.h"

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
    _textRange = builder.textRange;
    _fileURL = builder.fileURL;
  }
  return self;
}

// Find the smallest possible part that is different from before formatting,
// so we don't have to replace the entire file.
- (void)updateRangeToReplace:(NSString *)formattedDoc {
  NSRange diffBefore = NSMakeRange(0, _string.length);
  NSRange diffAfter = NSMakeRange(0, formattedDoc.length);
  NSUInteger i = 0;
  while (i < diffBefore.length && i < diffAfter.length) {
    if ([_string characterAtIndex:i] == [formattedDoc characterAtIndex:i]) {
      ++i;
    } else {
      break;
    }
  }
  diffBefore.location = i;
  diffAfter.location = i;
  i = 0;
  while (i < (diffBefore.length - diffBefore.location) &&
         i < (diffAfter.length - diffAfter.location)) {
    if ([_string characterAtIndex:diffBefore.length - i - 1] ==
        [formattedDoc characterAtIndex:diffAfter.length - i - 1]) {
      ++i;
    } else {
      break;
    }
  }
  diffBefore.length = diffBefore.length - i - diffBefore.location;
  diffAfter.length = diffAfter.length - i - diffAfter.location;

  self.rangeToReplace = diffBefore;
  self.formattedString = [formattedDoc substringWithRange:diffAfter];
};

- (void)formatWithStyle:(NSString *)style
    usingClangFormatAtLaunchPath:(NSString *)launchPath
                       lineRange:(NSRange)lineRange
                           block:(void (^)(NSString *formattedString,
                                           NSError *error))block {
  NSURL *tmpFileURL = [self.fileURL URLByAppendingPathExtension:@"trvs"];
  [self.string writeToURL:tmpFileURL
               atomically:YES
                 encoding:NSUTF8StringEncoding
                    error:NULL];

  NSPipe *outputPipe = [NSPipe pipe];
  NSPipe *errorPipe = [NSPipe pipe];

  NSTask *task = [[NSTask alloc] init];
  task.standardOutput = outputPipe;
  task.standardError = errorPipe;
  task.launchPath = launchPath;
  task.arguments = @[
    [NSString
        stringWithFormat:@"-lines=%tu:%tu",
                         lineRange.location + 1,                  // 1-based
                         lineRange.location + lineRange.length],  // 1-based
    [NSString stringWithFormat:@"--style=%@", style],
    @"-i",
    [tmpFileURL path]
  ];

  [outputPipe.fileHandleForReading readToEndOfFileInBackgroundAndNotify];

  [task launch];
  [task waitUntilExit];

  NSData *errorData = [errorPipe.fileHandleForReading readDataToEndOfFile];

  NSString *formattedDoc = [NSString stringWithContentsOfURL:tmpFileURL
                                                    encoding:NSUTF8StringEncoding
                                                       error:NULL];
  [self updateRangeToReplace:formattedDoc];
  block(self.formattedString,
        errorData.length > 0
            ? [NSError errorWithDomain:@"com.travisjeffery.error"
                                  code:-99
                              userInfo:@{
                                         NSLocalizedDescriptionKey :
                                         [[NSString alloc]
                                             initWithData:errorData
                                                 encoding:NSUTF8StringEncoding]
                                       }]
            : nil);

  [[NSFileManager defaultManager] removeItemAtURL:tmpFileURL error:NULL];
}

@end
