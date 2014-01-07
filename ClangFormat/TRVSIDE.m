//
//  TRVSIDE.m
//  ClangFormat
//
//  Created by Travis Jeffery on 1/7/14.
//  Copyright (c) 2014 Travis Jeffery. All rights reserved.
//

#import "TRVSIDE.h"

@implementation TRVSIDE

+ (id)currentEditor {
  NSWindowController *currentWindowController =
      [[NSApp keyWindow] windowController];
  if ([currentWindowController
          isKindOfClass:NSClassFromString(@"IDEWorkspaceWindowController")]) {
    IDEWorkspaceWindowController *workspaceController =
        (IDEWorkspaceWindowController *)currentWindowController;
    IDEEditorArea *editorArea = [workspaceController editorArea];
    IDEEditorContext *editorContext = [editorArea lastActiveEditorContext];
    return [editorContext editor];
  }
  return nil;
}

+ (IDEWorkspaceDocument *)workspaceDocument {
  NSWindowController *currentWindowController =
      [[NSApp keyWindow] windowController];
  id document = [currentWindowController document];
  if (currentWindowController &&
      [document isKindOfClass:NSClassFromString(@"IDEWorkspaceDocument")]) {
    return (IDEWorkspaceDocument *)document;
  }
  return nil;
}

+ (IDESourceCodeDocument *)sourceCodeDocument {
  if ([[self currentEditor]
          isKindOfClass:NSClassFromString(@"IDESourceCodeEditor")]) {
    IDESourceCodeEditor *editor = [self currentEditor];
    return editor.sourceCodeDocument;
  }

  if ([[self currentEditor]
          isKindOfClass:NSClassFromString(@"IDESourceCodeComparisonEditor")]) {
    IDESourceCodeComparisonEditor *editor = [self currentEditor];
    if ([[editor primaryDocument]
            isKindOfClass:NSClassFromString(@"IDESourceCodeDocument")]) {
      IDESourceCodeDocument *document =
          (IDESourceCodeDocument *)editor.primaryDocument;
      return document;
    }
  }

  return nil;
}

+ (NSTextView *)textView {
  if ([[self currentEditor]
          isKindOfClass:NSClassFromString(@"IDESourceCodeEditor")]) {
    IDESourceCodeEditor *editor = [self currentEditor];
    return editor.textView;
  }

  if ([[self currentEditor]
          isKindOfClass:NSClassFromString(@"IDESourceCodeComparisonEditor")]) {
    IDESourceCodeComparisonEditor *editor = [self currentEditor];
    return editor.keyTextView;
  }

  return nil;
}

+ (BOOL)hasSelection {
  return [[self textView] selectedRange].length > 0;
}

+ (void)replaceTextWithString:(NSString *)string {
  NSTextView *textView = [self textView];
  NSRect visibleRect = [textView visibleRect];
  NSRange selectedRange = NSMakeRange([textView selectedRange].location, 0);
  [textView insertText:string
      replacementRange:NSMakeRange(0, [[textView textStorage] length])];
  [textView scrollRectToVisible:visibleRect];
  [textView setSelectedRange:selectedRange];
}

@end
