//
//  ClangFormat.m
//  ClangFormat
//
//  Created by Travis Jeffery on 1/7/14.
//    Copyright (c) 2014 Travis Jeffery. All rights reserved.
//

#import "TRVSClangFormat.h"
#import "TRVSIDE.h"

static TRVSClangFormat *sharedPlugin;

@interface TRVSClangFormat ()

@property(nonatomic, strong) NSBundle *bundle;
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) NSMenu *formatMenu;
@property(nonatomic, copy) NSString *style;

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
  
  NSLog(@"bundle id %@", self.bundle.bundleIdentifier);

  [self setupMenuItems];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(windowDidUpdate:)
             name:NSWindowDidUpdateNotification
           object:nil];

  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Notifications

- (void)windowDidUpdate:(NSNotification *)notification {
  id window = notification.object;
  if ([window isKindOfClass:[NSWindow class]] && [window isMainWindow]) {
    self.window = window;
  }
}

- (void)didReadToEndOfFile:(NSNotification *)notification {
  NSData *data =
      [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem];
  NSString *string =
      [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  [TRVSIDE replaceTextWithString:string];
  [[NSNotificationCenter defaultCenter]
      removeObserver:self
                name:NSFileHandleReadToEndOfFileCompletionNotification
              object:[notification object]];
}

#pragma mark - Actions

- (void)formatActiveFile:(NSMenuItem *)menuItem {
  [self formatWithStyle:self.style];
}

- (void)formatSelectedFiles:(id)sender {
}

- (void)setDefaultFormatWithMenuItem:(NSMenuItem *)menuItem {
  CFPreferencesSetValue((__bridge CFStringRef)([self styleKey]),
                        (__bridge CFPropertyListRef)(menuItem.title),
                        (__bridge CFStringRef)(self.bundle.bundleIdentifier),
                        kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
  CFPreferencesSynchronize(CFSTR("com.travisjeffery.ClangFormat"),
                           kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
  _style = [menuItem.title copy];
  [self.formatMenu removeAllItems];
  [self addFormatMenuItemsToFormatMenu];
}

#pragma mark - Private

- (void)addFormatMenuItemsToFormatMenu {
  NSMenuItem *formatActiveFileItem = [[NSMenuItem alloc]
      initWithTitle:NSLocalizedString(@"Format active file", nil)
             action:@selector(formatActiveFile:)
      keyEquivalent:@""];
  [formatActiveFileItem setTarget:self];
  [self.formatMenu addItem:formatActiveFileItem];

  NSMenuItem *formatSelectedFilesItem = [[NSMenuItem alloc]
      initWithTitle:NSLocalizedString(@"Format selected files", nil)
             action:@selector(formatSelectedFiles:)
      keyEquivalent:@""];
  [formatSelectedFilesItem setTarget:self];
//  [self.formatMenu addItem:formatSelectedFilesItem];

  [self.formatMenu addItem:[NSMenuItem separatorItem]];

  [[self styles] enumerateObjectsUsingBlock:^(NSString *format, NSUInteger idx, BOOL *stop)
   {
    if ([format isEqualToString:[self style]])
      format = [format stringByAppendingString:@" 👈"];

    NSMenuItem *menuItem = [[NSMenuItem alloc]
        initWithTitle:format
               action:@selector(setDefaultFormatWithMenuItem:)
        keyEquivalent:@""];
    [menuItem setTarget:self];
    [self.formatMenu addItem:menuItem];
  }];
}

- (void)setupMenuItems {
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
  [self addFormatMenuItemsToFormatMenu];
  [actionMenuItem setSubmenu:self.formatMenu];
}

- (void)formatWithStyle:(NSString *)style {
  NSTask *task = [[NSTask alloc] init];
  [task setLaunchPath:[self.bundle pathForResource:@"clang-format" ofType:nil]];
  [task setArguments:[self taskArgumentsWithStyle:style]];
  
  NSPipe *pipe = [NSPipe pipe];
  [task setStandardOutput:pipe];
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(didReadToEndOfFile:)
             name:NSFileHandleReadToEndOfFileCompletionNotification
           object:[pipe fileHandleForReading]];
  [[pipe fileHandleForReading] readToEndOfFileInBackgroundAndNotify];
  
  [task launch];
}

- (NSString *)style {
  if (_style)
    return _style;

  CFPropertyListRef value =
      CFPreferencesCopyValue((__bridge CFStringRef)([self styleKey]),
                             (__bridge CFStringRef)(self.bundle.bundleIdentifier),
                             kCFPreferencesCurrentUser, kCFPreferencesAnyHost);

  if (value != NULL) {
    _style = (__bridge NSString *)(value);
    CFRelease(value);
  } else {
    _style = [[[self styles] firstObject] copy];
  }

  return _style;
}

- (NSString *)styleKey {
  return [self.bundle.bundleIdentifier stringByAppendingString:@".format"];
}

- (NSArray *)styles {
  return @[ @"LLVM", @"Google", @"Chromium", @"Mozilla", @"WebKit", @"File" ];
}

- (NSArray *)taskArgumentsWithStyle:(NSString *)style {
  NSMutableArray *arguments = [[NSMutableArray alloc] init];
  [arguments addObject:[NSString stringWithFormat:@"--style=%@", style]];
  [arguments addObject:[[self documentURL] path]];
  [arguments addObjectsFromArray:[self linesArguments]];
  return arguments;
}

- (NSArray *)linesArguments {
  NSMutableArray *arguments = [[NSMutableArray alloc] init];
  if (![TRVSIDE hasSelection])
    return arguments;

  NSArray *selectedRanges = [[TRVSIDE textView] selectedRanges];
  DVTSourceTextStorage *textStorage =
      [[TRVSIDE sourceCodeDocument] textStorage];

  [selectedRanges enumerateObjectsUsingBlock:^(NSValue *rangeValue, NSUInteger idx, BOOL *stop)
  {
    NSRange lineRange =
        [textStorage lineRangeForCharacterRange:[rangeValue rangeValue]];
    [arguments
        addObject:[NSString stringWithFormat:
                                @"--lines=%lu:%lu", lineRange.location + 1,
                                lineRange.location + lineRange.length]];
  }];

  return arguments;
}

- (NSURL *)documentURL {
  __block NSURL *URL = nil;
  NSArray *windows = [NSClassFromString(@"IDEWorkspaceWindowController")
      workspaceWindowControllers];
  [windows enumerateObjectsUsingBlock:^(id workspaceWindowController, NSUInteger idx, BOOL *stop)
  {
    if ([workspaceWindowController workspaceWindow] == self.window ||
        windows.count == 1) {
      NSDocument *document =
          [[workspaceWindowController editorArea] primaryEditorDocument];
      URL = [document fileURL];
    }
  }];
  return URL;
}

@end
