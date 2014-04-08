//
//  ClangFormat.m
//  ClangFormat
//
//  Created by Travis Jeffery on 1/7/14.
//    Copyright (c) 2014 Travis Jeffery. All rights reserved.
//

#import "TRVSClangFormat.h"
#import "TRVSPreferences.h"
#import "TRVSFormatter.h"
#import "NSDocument+TRVSClangFormat.h"

static TRVSClangFormat *sharedPlugin;

@interface TRVSClangFormat ()

@property (nonatomic, strong) NSBundle *bundle;
@property (nonatomic, strong) NSMenu *formatMenu;
@property (nonatomic, strong) TRVSPreferences *preferences;
@property (nonatomic, strong) TRVSFormatter *formatter;

@end

@implementation TRVSClangFormat

+ (void)pluginDidLoad:(NSBundle *)plugin {
  static id sharedPlugin = nil;
  static dispatch_once_t onceToken;
  NSString *currentApplicationName =
      [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
  if ([currentApplicationName isEqual:@"Xcode"]) {
    dispatch_once(&onceToken,
                  ^{ sharedPlugin = [[self alloc] initWithBundle:plugin]; });
  }
}

- (id)initWithBundle:(NSBundle *)plugin {
  if (!(self = [super init]))
    return nil;

  self.bundle = plugin;
  self.preferences = [[TRVSPreferences alloc]
      initWithApplicationID:self.bundle.bundleIdentifier];
  NSString *style = [self.preferences objectForKey:[self stylePreferencesKey]]
                            ?: [[self styles] firstObject];
  self.formatter = [TRVSFormatter sharedFormatter];
  self.formatter.style = style;
  self.formatter.executablePath =
      [self.bundle pathForResource:@"clang-format" ofType:@""];

  [NSDocument settrvs_formatOnSave:[self formatOnSave]];

  [self addMenuItemsToMenu];

  return self;
}

#pragma mark - Actions

- (void)setStyleToUseFromMenuItem:(NSMenuItem *)menuItem {
  [self.preferences setObject:menuItem.title forKey:[self stylePreferencesKey]];
  [self.preferences synchronize];

  self.formatter.style = menuItem.title;

  [self prepareFormatMenu];
}

#pragma mark - Private

- (void)prepareFormatMenu {
  [self.formatMenu removeAllItems];
  [self addMenuItemsToFormatMenu];
}

- (void)addMenuItemsToFormatMenu {
  [self addActioningMenuItemsToFormatMenu];
  [self addSeparatorToFormatMenu];
  [self addStyleMenuItemsToFormatMenu];
  [self addSeparatorToFormatMenu];
  [self addFormatOnSaveMenuItem];
}

- (void)addActioningMenuItemsToFormatMenu {
  NSMenuItem *formatActiveFileItem = [[NSMenuItem alloc]
      initWithTitle:NSLocalizedString(@"Format File in Focus", nil)
             action:@selector(formatActiveFile)
      keyEquivalent:@""];
  [formatActiveFileItem setTarget:self.formatter];
  [self.formatMenu addItem:formatActiveFileItem];

  NSMenuItem *formatSelectedCharacters = [[NSMenuItem alloc]
      initWithTitle:NSLocalizedString(@"Format Selected Text", nil)
             action:@selector(formatSelectedCharacters)
      keyEquivalent:@""];
  [formatSelectedCharacters setTarget:self.formatter];
  [self.formatMenu addItem:formatSelectedCharacters];

  NSMenuItem *formatSelectedFilesItem = [[NSMenuItem alloc]
      initWithTitle:NSLocalizedString(@"Format Selected Files", nil)
             action:@selector(formatSelectedFiles)
      keyEquivalent:@""];
  [formatSelectedFilesItem setTarget:self.formatter];
  [self.formatMenu addItem:formatSelectedFilesItem];

  NSMenuItem *deleteLineItem =
      [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Delete Line", nil)
                                 action:@selector(deleteLine)
                          keyEquivalent:@""];
  [deleteLineItem setTarget:self.formatter];
  [self.formatMenu addItem:deleteLineItem];
}

- (void)addSeparatorToFormatMenu {
  [self.formatMenu addItem:[NSMenuItem separatorItem]];
}

- (void)addStyleMenuItemsToFormatMenu {
  [[self styles] enumerateObjectsUsingBlock:^(NSString *format,
                                              NSUInteger idx,
                                              BOOL *stop) {
      [self addMenuItemWithStyle:format];
  }];
}

- (void)addMenuItemWithStyle:(NSString *)style {
  NSMenuItem *menuItem =
      [[NSMenuItem alloc] initWithTitle:style
                                 action:@selector(setStyleToUseFromMenuItem:)
                          keyEquivalent:@""];
  [menuItem setTarget:self];

  if ([style isEqualToString:self.formatter.style])
    menuItem.state = NSOnState;

  [self.formatMenu addItem:menuItem];
}

- (void)addFormatOnSaveMenuItem {
  NSString *title = NSLocalizedString(@"Enable Format on Save", nil);
  if ([self formatOnSave])
    title = NSLocalizedString(@"Disable Format on Save", nil);

  NSMenuItem *toggleFormatOnSaveMenuItem =
      [[NSMenuItem alloc] initWithTitle:title
                                 action:@selector(toggleFormatOnSave)
                          keyEquivalent:@""];
  [toggleFormatOnSaveMenuItem setTarget:self];
  [self.formatMenu addItem:toggleFormatOnSaveMenuItem];
}

- (void)addMenuItemsToMenu {
  NSMenuItem *menuItem = [[NSApp mainMenu] itemWithTitle:@"Edit"];
  if (!menuItem)
    return;

  [[menuItem submenu] addItem:[NSMenuItem separatorItem]];

  NSMenuItem *actionMenuItem =
      [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Clang Format", nil)
                                 action:NULL
                          keyEquivalent:@""];
  [[menuItem submenu] addItem:actionMenuItem];

  self.formatMenu =
      [[NSMenu alloc] initWithTitle:NSLocalizedString(@"Clang Format", nil)];
  [self addMenuItemsToFormatMenu];
  [actionMenuItem setSubmenu:self.formatMenu];
}

- (void)toggleFormatOnSave {
  BOOL formatOnSave = ![self formatOnSave];

  [self.preferences setObject:@(formatOnSave)
                       forKey:[self formatOnSavePreferencesKey]];
  [self.preferences synchronize];

  [NSDocument settrvs_formatOnSave:formatOnSave];

  [self prepareFormatMenu];
}

- (BOOL)formatOnSave {
  return [[self.preferences
      objectForKey:[self formatOnSavePreferencesKey]] boolValue];
}

- (NSString *)formatOnSavePreferencesKey {
  return
      [self.bundle.bundleIdentifier stringByAppendingString:@".formatOnSave"];
}

- (NSString *)stylePreferencesKey {
  return [self.bundle.bundleIdentifier stringByAppendingString:@".format"];
}

- (NSArray *)styles {
  return @[ @"LLVM", @"Google", @"Chromium", @"Mozilla", @"WebKit", @"File" ];
}

@end
