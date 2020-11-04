//
//  NSTask+TRVSClangFormat.m
//  ClangFormat
//
//  Created by Seth Delackner on 5/16/14.
//  Copyright (c) 2014 Travis Jeffery. All rights reserved.
//

#import "NSTask+TRVSClangFormat.h"

@implementation NSTask (TRVSClangFormat)

- (void) killIfNotDoneBy:(NSDate *) killDate {
    while ([self isRunning]) {
        if ([[NSDate date] laterDate:killDate] != killDate) {
            NSLog(@"Error: task took too long. killing.");
            [self terminate];
        }
        [NSThread sleepForTimeInterval:1.0];
    }
}

@end
