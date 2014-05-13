//
//  TRVSXMLDictionary.m
//  TRVSXMLDictionary
//
//  Created by Travis Jeffery on 5/13/14.
//
//

#import "TRVSXMLDictionary.h"

NSString *const TRVSXMLDictionaryTextKey = @"text";

@interface TRVSXMLDictionary ()<NSXMLParserDelegate>

@property(nonatomic, strong) NSMutableArray *stack;
@property(nonatomic, strong) NSMutableString *text;
@property(nonatomic, copy) NSData *data;
@property(nonatomic, strong) NSError *error;

@end

@implementation TRVSXMLDictionary

+ (NSDictionary *)dictionaryUsingData:(NSData *)data {
  return [[[self alloc] initWithData:data] dictionary];
}

- (instancetype)initWithData:(NSData *)data {
  if (self = [super init]) {
    _data = [data copy];
    _stack = [[NSMutableArray alloc]
        initWithObjects:[[NSMutableDictionary alloc] init], nil];
    _text = [[NSMutableString alloc] init];
  }
  return self;
}

- (NSDictionary *)dictionary {
  NSXMLParser *parser = [[NSXMLParser alloc] initWithData:self.data];
  parser.delegate = self;
  if ([parser parse]) {
    return self.stack.firstObject;
  } else {
    return nil;
  }
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser
    didStartElement:(NSString *)elementName
       namespaceURI:(NSString *)namespaceURI
      qualifiedName:(NSString *)qName
         attributes:(NSDictionary *)attributeDict {
  NSMutableDictionary *parent = self.stack.lastObject;
  NSMutableDictionary *child =
      [[NSMutableDictionary alloc] initWithDictionary:attributeDict];
  id value = parent[elementName];
  if (value) {
    NSMutableArray *array = nil;
    if ([value isKindOfClass:[NSArray class]]) {
      array = value;
    } else {
      array = [[NSMutableArray alloc] initWithObjects:value, nil];
      parent[elementName] = array;
    }
    [array addObject:child];
  } else {
    parent[elementName] = child;
  }
  [self.stack addObject:child];
}

- (void)parser:(NSXMLParser *)parser
    didEndElement:(NSString *)elementName
     namespaceURI:(NSString *)namespaceURI
    qualifiedName:(NSString *)qName {
  NSMutableDictionary *dict = self.stack.lastObject;
  if (self.text.length > 0) {
    dict[TRVSXMLDictionaryTextKey] = self.text;
    self.text = [[NSMutableString alloc] init];
  }
  [self.stack removeLastObject];
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
  [self.text appendString:string];
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
  
 self.error = parseError;
}

@end
