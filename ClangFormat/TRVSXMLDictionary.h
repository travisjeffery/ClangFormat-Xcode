//
//  TRVSXMLDictionary.h
//  TRVSXMLDictionary
//
//  Created by Travis Jeffery on 5/13/14.
//
//

#import <Foundation/Foundation.h>

extern NSString *const TRVSXMLDictionaryTextKey;

@interface TRVSXMLDictionary : NSObject

+ (NSDictionary *)dictionaryUsingData:(NSData *)data;

@end
