//
//  TRVSPreferences.m
//  ClangFormat
//
//  Created by Travis Jeffery on 1/9/14.
//  Copyright (c) 2014 Travis Jeffery. All rights reserved.
//

#import "TRVSPreferences.h"

@interface TRVSPreferences ()

@property (nonatomic, copy) NSString *applicationID;

@end

@implementation TRVSPreferences

#pragma mark - Designated Initializer

- (instancetype)initWithApplicationID:(NSString *)applicationID {
  self = [super init];

  if (self) {
    self.applicationID = applicationID;
  }

  return self;
}

- (id)objectForKey:(NSString *)key {
  CFPropertyListRef value =
      CFPreferencesCopyValue((__bridge CFStringRef)key,
                             (__bridge CFStringRef)self.applicationID,
                             kCFPreferencesCurrentUser,
                             kCFPreferencesAnyHost);

  id object = nil;

  if (value != NULL) {
    object = (__bridge id)value;
    CFRelease(value);
  }

  return object;
}

- (void)setObject:(id)object forKey:(NSString *)key {
  CFPreferencesSetValue((__bridge CFStringRef)key,
                        (__bridge CFPropertyListRef)object,
                        (__bridge CFStringRef)self.applicationID,
                        kCFPreferencesCurrentUser,
                        kCFPreferencesAnyHost);
}

- (BOOL)synchronize {
  return CFPreferencesSynchronize((__bridge CFStringRef)self.applicationID,
                                  kCFPreferencesCurrentUser,
                                  kCFPreferencesAnyHost);
}

@end
