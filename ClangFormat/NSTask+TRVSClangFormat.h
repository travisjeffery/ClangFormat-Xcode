//
//  NSTask+TRVSClangFormat.h
//  ClangFormat
//
//  Created by Seth Delackner on 5/16/14.
//  Copyright (c) 2014 Travis Jeffery. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSTask (TRVSClangFormat)

- (void) killIfNotDoneBy:(NSDate *) killDate;

@end
