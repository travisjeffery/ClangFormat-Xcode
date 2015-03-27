//
//  TRVSCodeFragment.h
//  ClangFormat
//
//  Created by Travis Jeffery on 1/9/14.
//  Copyright (c) 2014 Travis Jeffery. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TRVSCodeFragment;

@interface TRVSCodeFragmentBuilder : NSObject

- (TRVSCodeFragment *)build;

@property (nonatomic, copy) NSString *string;
@property (nonatomic, copy) NSString *formattedString;
@property (nonatomic) NSRange textRange;
@property (nonatomic, strong) NSURL *fileURL;

@end

@interface TRVSCodeFragment : NSObject

+ (instancetype)fragmentUsingBlock:(void (^)(TRVSCodeFragmentBuilder *builder))block;

- (void)formatWithStyle:(NSString *)style
    usingClangFormatAtLaunchPath:(NSString *)launchPath
                       lineRange:(NSRange)lineRange
                           block:(void (^)(NSString *formattedString,
                                           NSError *error))block;

@property (nonatomic, copy) NSString *string;
@property (nonatomic, copy) NSString *formattedString;
@property (nonatomic) NSRange textRangePreFormat;
@property (nonatomic) NSRange textRangePostFormat;
@property (nonatomic) NSRange rangeToReplace;
@property (nonatomic, strong) NSURL *fileURL;
@property (nonatomic, strong) NSError *error;

@end
