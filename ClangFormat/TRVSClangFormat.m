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

static TRVSClangFormat *sharedPlugin;

@interface TRVSClangFormat ()

@property(nonatomic, strong) NSBundle *bundle;
@property(nonatomic, strong) NSMenu *formatMenu;
@property(nonatomic, strong) TRVSPreferences *preferences;
@property(nonatomic, strong) TRVSFormatter *formatter;

@end

@implementation TRVSClangFormat

+ (void)pluginDidLoad:(NSBundle *)plugin {
  static id sharedPlugin = nil;
  static dispatch_once_t onceToken;
  NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary]
      [@"CFBundleName"];
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
  self.formatter = [[TRVSFormatter alloc]
       initWithStyle:style
      executablePath:[self.bundle pathForResource:@"clang-format" ofType:@""]];

  [self addMenuItemsToMenu];

  return self;
}

#pragma mark - Actions

- (void)setStyleToUseFromMenuItem:(NSMenuItem *)menuItem {
  [self.preferences setObject:menuItem.title forKey:[self stylePreferencesKey]];
  [self.preferences synchronize];

  self.formatter.style = menuItem.title;

  [self.formatMenu removeAllItems];
  [self addStyleMenuItemsToSubmenu];
}

#pragma mark - Private

- (void)addStyleMenuItemsToSubmenu {
  NSMenuItem *formatActiveFileItem = [[NSMenuItem alloc]
      initWithTitle:NSLocalizedString(@"Format active file", nil)
             action:@selector(formatActiveFile)
      keyEquivalent:@""];
  [formatActiveFileItem setTarget:self.formatter];
  [self.formatMenu addItem:formatActiveFileItem];

  NSMenuItem *formatSelectedCharacters = [[NSMenuItem alloc]
      initWithTitle:NSLocalizedString(@"Format selected characters", nil)
             action:@selector(formatSelectedCharacters)
      keyEquivalent:@""];
  [formatSelectedCharacters setTarget:self.formatter];
  [self.formatMenu addItem:formatSelectedCharacters];

  NSMenuItem *formatSelectedFilesItem = [[NSMenuItem alloc]
      initWithTitle:NSLocalizedString(@"Format selected files", nil)
             action:@selector(formatSelectedFiles)
      keyEquivalent:@""];
  [formatSelectedFilesItem setTarget:self.formatter];
  [self.formatMenu addItem:formatSelectedFilesItem];

  [self.formatMenu addItem:[NSMenuItem separatorItem]];

  NSMenuItem *styleMenuItem =
      [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Format style:", nil)
                                 action:NULL
                          keyEquivalent:@""];
  [self.formatMenu addItem:styleMenuItem];

  [[self styles] enumerateObjectsUsingBlock:^(NSString *format, NSUInteger idx, BOOL *stop)
  {
    [self addMenuItemWithStyle:format];
  }];
}

- (void)addMenuItemWithStyle:(NSString *)style {
  if ([style isEqualToString:self.formatter.style])
    style = [style stringByAppendingString:@" 👈"];

  NSMenuItem *menuItem =
      [[NSMenuItem alloc] initWithTitle:style
                                 action:@selector(setStyleToUseFromMenuItem:)
                          keyEquivalent:@""];
  [menuItem setTarget:self];
  [self.formatMenu addItem:menuItem];
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
  [self addStyleMenuItemsToSubmenu];
  [actionMenuItem setSubmenu:self.formatMenu];
}

- (NSString *)stylePreferencesKey {
  return [self.bundle.bundleIdentifier stringByAppendingString:@".format"];
}

- (NSArray *)styles {
  return @[ @"LLVM", @"Google", @"Chromium", @"Mozilla", @"WebKit", @"File" ];
}

@end
