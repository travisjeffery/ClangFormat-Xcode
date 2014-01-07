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

#pragma mark - Actions

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

  NSMenu *formatMenu =
      [[NSMenu alloc] initWithTitle:NSLocalizedString(@"Clang Format", nil)];

    [[self styles] enumerateObjectsUsingBlock:^(NSString *format, NSUInteger idx, BOOL *stop)
    {
      NSMenuItem *menuItem =
          [[NSMenuItem alloc] initWithTitle:format
                                     action:@selector(formatWithStyle:)
                              keyEquivalent:@""];
      [menuItem setTarget:self];
      [formatMenu addItem:menuItem];
    }];

    [actionMenuItem setSubmenu:formatMenu];
}

- (void)formatWithStyle:(NSMenuItem *)menuItem {
  NSTask *task = [[NSTask alloc] init];
  [task setLaunchPath:[self.bundle pathForResource:@"clang-format" ofType:nil]];
  NSArray *arguments = @[
    @"-i",
    [NSString stringWithFormat:@"--style=%@", menuItem.title],
    [[self documentURL] path]
  ];
  [task setArguments:arguments];
  [task launch];
}

#pragma mark - Private

- (NSArray *)styles {
  return @[ @"LLVM", @"Google", @"Chromium", @"Mozilla", @"WebKit" ];
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
