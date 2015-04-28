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
    dispatch_once(&onceToken, ^{
      sharedPlugin = [[self alloc] initWithBundle:plugin];
    });
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

  NSNumber *useSystemClangFormat =
      [self.preferences objectForKey:[self useSystemClangFormatPreferencesKey]]
          ?: [NSNumber numberWithBool:NO];
  self.formatter.useSystemClangFormat = [useSystemClangFormat boolValue];

  self.formatter.executablePath =
      [self.bundle pathForResource:@"clang-format" ofType:@""];

  [NSDocument settrvs_formatOnSave:[self formatOnSave]];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(applicationDidFinishLaunching:)
             name:NSApplicationDidFinishLaunchingNotification
           object:nil];

  return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  [self addMenuItemsToMenu];

  [[NSNotificationCenter defaultCenter]
      removeObserver:self
                name:NSApplicationDidFinishLaunchingNotification
              object:nil];
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
  [self addUseSystemClangFormatMenuItem];
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
}

- (void)addSeparatorToFormatMenu {
  [self.formatMenu addItem:[NSMenuItem separatorItem]];
}

- (void)addStyleMenuItemsToFormatMenu {
  [[self styles] enumerateObjectsUsingBlock:^(NSString *format, NSUInteger idx,
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

- (void)addUseSystemClangFormatMenuItem {
  NSString *title = [self useSystemClangFormat]
                        ? NSLocalizedString(@"Use Bundled ClangFormat", nil)
                        : NSLocalizedString(@"Use System ClangFormat", nil);
  NSMenuItem *useSystemClangFormatMenuItem =
      [[NSMenuItem alloc] initWithTitle:title
                                 action:@selector(toggleUseSystemClangFormat)
                          keyEquivalent:@""];
  [useSystemClangFormatMenuItem setTarget:self];
  [self.formatMenu addItem:useSystemClangFormatMenuItem];
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

- (void)toggleUseSystemClangFormat {
  BOOL useSystemClangFormat = ![self useSystemClangFormat];

  [self.preferences setObject:@(useSystemClangFormat)
                       forKey:[self useSystemClangFormatPreferencesKey]];
  [self.preferences synchronize];

  self.formatter.useSystemClangFormat = useSystemClangFormat;

  [self prepareFormatMenu];
}

- (BOOL)useSystemClangFormat {
  return [[self.preferences
      objectForKey:[self useSystemClangFormatPreferencesKey]] boolValue];
}

- (NSString *)formatOnSavePreferencesKey {
  return
      [self.bundle.bundleIdentifier stringByAppendingString:@".formatOnSave"];
}

- (NSString *)stylePreferencesKey {
  return [self.bundle.bundleIdentifier stringByAppendingString:@".format"];
}

- (NSString *)useSystemClangFormatPreferencesKey {
  return [self.bundle.bundleIdentifier
      stringByAppendingString:@".useSystemClangFormat"];
}

- (NSArray *)styles {
  return @[ @"LLVM", @"Google", @"Chromium", @"Mozilla", @"WebKit", @"File" ];
}

@end
