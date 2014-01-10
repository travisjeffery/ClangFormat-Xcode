//
//  TRVSCodeFragment.h
//  ClangFormat
//
//  Created by Travis Jeffery on 1/9/14.
//  Copyright (c) 2014 Travis Jeffery. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TRVSCodeFragment : NSObject

- (void)formatWithStyle:(NSString *)style
    usingClangFormatAtLaunchPath:(NSString *)launchPath;

@property(nonatomic, copy) NSString *string;
@property(nonatomic, copy) NSString *formattedString;
@property(nonatomic) NSRange range;
@property(nonatomic, strong) NSURL *fileURL;

@end
