//
//  TRVSXcode.m
//  ClangFormat
//
//  Created by Travis Jeffery on 1/9/14.
//  Copyright (c) 2014 Travis Jeffery. All rights reserved.
//

#import "TRVSXcode.h"

@implementation TRVSXcode

+ (id)currentEditor {
  if ([[self windowController]
          isKindOfClass:NSClassFromString(@"IDEWorkspaceWindowController")]) {
    IDEWorkspaceWindowController *workspaceController =
        (IDEWorkspaceWindowController *)[self windowController];
    IDEEditorArea *editorArea = [workspaceController editorArea];
    IDEEditorContext *editorContext = [editorArea lastActiveEditorContext];
    return [editorContext editor];
  }
  return nil;
}

+ (IDESourceCodeDocument *)sourceCodeDocument {
  if ([[self currentEditor]
          isKindOfClass:NSClassFromString(@"IDESourceCodeEditor")]) {
    return [[self currentEditor] sourceCodeDocument];
  }

  if ([[self currentEditor]
          isKindOfClass:NSClassFromString(@"IDESourceCodeComparisonEditor")] &&
      [[[self currentEditor] primaryDocument]
          isKindOfClass:NSClassFromString(@"IDESourceCodeDocument")]) {
    return (IDESourceCodeDocument *)[[self currentEditor] primaryDocument];
  }

  return nil;
}

+ (NSTextView *)textView {
  if ([[self currentEditor]
          isKindOfClass:NSClassFromString(@"IDESourceCodeEditor")]) {
    return [[self currentEditor] textView];
  }

  if ([[self currentEditor]
          isKindOfClass:NSClassFromString(@"IDESourceCodeComparisonEditor")]) {
    return [[self currentEditor] keyTextView];
  }

  return nil;
}

+ (BOOL)textViewHasSelection {
  return [[self textView] selectedRange].length > 0;
}

+ (NSRange)wholeRangeOfTextView {
  return NSMakeRange(0, [[[self textView] textStorage] length]);
}

+ (NSArray *)selectedFileNavigableItems {
  if (![[self windowController]
          isKindOfClass:NSClassFromString(@"IDEWorkspaceWindowController")])
    return nil;

  IDEWorkspaceWindowController *workspaceController =
      (IDEWorkspaceWindowController *)[self windowController];
  IDEWorkspaceTabController *workspaceTabController =
      [workspaceController activeWorkspaceTabController];
  IDENavigatorArea *navigatorArea = [workspaceTabController navigatorArea];
  id currentNavigator = [navigatorArea currentNavigator];

  if (![currentNavigator
          isKindOfClass:NSClassFromString(@"IDEStructureNavigator")])
    return nil;

  NSMutableArray *array = [NSMutableArray array];

  [[currentNavigator selectedObjects]
      enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
          if (![obj isKindOfClass:NSClassFromString(@"IDEFileNavigableItem")])
            return;

          IDEFileNavigableItem *fileNavigableItem = obj;
          NSString *uti = fileNavigableItem.documentType.identifier;
          if ([[NSWorkspace sharedWorkspace]
                            type:uti
                  conformsToType:(NSString *)kUTTypeSourceCode]) {
            [array addObject:fileNavigableItem];
          }
      }];

  return array;
}

+ (NSWindowController *)windowController {
  return [[NSApp keyWindow] windowController];
}

@end
