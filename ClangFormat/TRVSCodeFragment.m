//
//  TRVSCodeFragment.m
//  ClangFormat
//
//  Created by Travis Jeffery on 1/9/14.
//  Copyright (c) 2014 Travis Jeffery. All rights reserved.
//

#import "TRVSCodeFragment.h"

@implementation TRVSCodeFragment

- (void)formatWithStyle:(NSString *)style
    usingClangFormatAtLaunchPath:(NSString *)launchPath {
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
    [NSString stringWithFormat:@"--style=%@", style],
    @"-i",
    [tmpFileURL path]
  ];

  [outputPipe.fileHandleForReading readToEndOfFileInBackgroundAndNotify];
  [task launch];
  [task waitUntilExit];

  NSData *stdErr = [errorPipe.fileHandleForReading readDataToEndOfFile];
  if ([stdErr length] > 0) {
    NSString *errorMessage =
        [[NSString alloc] initWithData:stdErr encoding:NSUTF8StringEncoding];
    self.errorMessage = errorMessage;
    self.formattedSuccessfully = NO;
  } else {
    self.formattedString =
        [NSString stringWithContentsOfURL:tmpFileURL
                                 encoding:NSUTF8StringEncoding
                                    error:NULL];
    self.formattedSuccessfully = YES;
  }
  [[NSFileManager defaultManager] removeItemAtURL:tmpFileURL error:NULL];
}

@end
