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
@property (nonatomic) NSRange range;
@property (nonatomic) NSRange lineRange;
@property (nonatomic, strong) NSURL *fileURL;

@end

@interface TRVSCodeFragment : NSObject

+ (instancetype)fragmentUsingBlock:
        (void (^)(TRVSCodeFragmentBuilder *builder))block;

- (void)formatWithStyle:(NSString *)style
    usingClangFormatAtLaunchPath:(NSString *)launchPath
                           block:(void (^)(NSArray *replacements,
                                           NSError *error))block;

@property (nonatomic, copy) NSString *string;
@property (nonatomic) NSRange range;
@property (nonatomic) NSRange lineRange;
@property (nonatomic) NSArray *replacements;
@property (nonatomic, strong) NSURL *fileURL;
@property (nonatomic, strong) NSError *error;

@end
