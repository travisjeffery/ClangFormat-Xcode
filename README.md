# ClangFormat-Xcode

An Xcode plug-in to format your code using Clang's format tools, by [@travisjeffery](https://twitter.com/travisjeffery).

With [clang-format](http://clang.llvm.org/docs/ClangFormat.html) you can use Clang to format your code to styles such as LLVM, Google, Chromium, Mozilla, WebKit, or your own configuration.

![demo](https://raw.github.com/travisjeffery/ClangFormat-Xcode/master/README/clangformat-xcode-demo.gif)

## Installation:

Install via [Alcatraz](https://github.com/mneorr/Alcatraz).

OR

Clone this repo, build and run ClangFormat, restart Xcode.

### Using your own style configuration

By using Clang Format > File in the plug-in menu, Clang will look for the nearest `.clang-format` file from the input file. Most likely, you'll have a .clang-format file at the root of your project.

[Here are the options for .clang-format and how they're configured](http://clang.llvm.org/docs/ClangFormatStyleOptions.html).

If one of the built-in styles is close to what you want, you can bootstrap your own configuration with:

`./bin/clang-format -style=llvm -dump-config > .clang-format`

For example, this .clang-format is similar to the [Linux Kernel style](https://www.kernel.org/doc/Documentation/CodingStyle):

```
BasedOnStyle: LLVM
IndentWidth: 8
UseTab: Always
BreakBeforeBraces: Linux
AllowShortIfStatementsOnASingleLine: false
IndentCaseLabels: false
```

And this is similar to Visual Studio's style:

```
UseTab: Never
IndentWidth: 4
BreakBeforeBraces: Allman
AllowShortIfStatementsOnASingleLine: false
IndentCaseLabels: false
ColumnLimit: 0
```