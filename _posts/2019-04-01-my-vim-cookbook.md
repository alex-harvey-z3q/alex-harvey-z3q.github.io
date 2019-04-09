---
layout: post
title: "My Vim Cookbook"
date: 2019-04-01
author: Alex Harvey
tags: vim
---

This is a list of my favourite productivity-enhancing vim tricks.

#### Table of contents

1. [Preface](#preface)
    * [How to enter Vim visual mode](#how-to-enter-vim-visual-mode)
    * [A note about tab-completion in commands](#a-note-about-tab-completion-in-commands)
2. [Cookbook](#cookbook)
    * [Align equals signs](#align-equals-signs)
    * [Auto-indent JSON code using jq](#auto-indent-json-code-using-jq)
    * [Auto-indent code using visual mode and equals](#auto-indent-code-using-visual-mode-and-equals)
    * [Bulk edit files using Vimscript](#bulk-edit-files-using-vimscript)
    * [Convert a space separated string to newline separated string](#convert-a-space-separated-string-to-newline-separated-string)
    * [Copy some lines to the clipboard](#copy-some-lines-to-the-clipboard)
    * [Delete lines matching](#delete-lines-matching)
    * [Fix inconsistent cases](#fix-inconsistent-cases)
    * [Sort lines in a file](#sort-lines-in-a-file)

## Preface

Some info that is useful to know while reading all of the Vim tricks below.

### How to enter Vim visual mode

If you don't know how to enter visual mode in vim. E.g. select the lines foo and baz in the following:

```json
{
  "Foo": "Bar",
  "Baz": "Qux"
}
```

Move the cursor to line 2. `SHIFT-V`. `j` (to move down one line). `:`. Vim enters command mode with the beginning of a command set to `:'<,'>`. Now enter the rest of the command e.g. `:'<,'>s/: /:/` (remove the space after the colons).

- Reference

See the [Vim manual](http://vimdoc.sourceforge.net/htmldoc/visual.html).

### A note about tab-completion in commands

Be aware in all of these tips that Bash tab-completion works inside the Vim command mode. E.g. suppose you are using the pbcopy tip. You can go into visual mode, select the text and then:

```
:'<,'> ! pbc<TAB>
```

It will auto-complete as:

```
:'<,'> ! pbcopy
```

## Cookbook

### Align equals signs

- Problem

You have some code like this:

```js
$ = jQuery.sub()
Survey = App.Survey
Sidebar = App.Sidebar
Main = App.Main
```

And you want the equals signs to align like this:

```js
$       = jQuery.sub()
Survey  = App.Survey
Sidebar = App.Sidebar
Main    = App.Main
```

- Solution

Enter visual mode and then:

```
:'<,'> ! column -t | sed -e 's/ = /=/'
```

- Reference

My [answer](https://stackoverflow.com/a/51462785/3787051) on Stack Overflow.

### Auto-indent JSON code using jq

- Problem

You are editing a badly indented JSON document. Vim's built-in auto-indent feature (`=`) isn't adequate to fully correct the indenting. You want to use `jq .` instead.

- Solution 1

Indent the whole file:

```
:% ! jq .
```

- Solution 2

You want a different indentation e.g. 4 spaces instead of 2:

```
:% ! jq --indent 4 .
```

- Reference

See the [jq manual](https://stedolan.github.io/jq/manual/) for other options.

### Auto-indent code using visual mode and equals

- Problem

You have some code in any language that's not indented properly, e.g.

```bash
while true ; do
echo "hello world"
done
```

And you want it indented like this:

```bash
while true ; do
  echo "hello world"
done
```

- Solution

Enter visual mode and select the block of code. Press `=`.

### Bulk edit files using Vimscript

- Problem

You have some similar files e.g. JSON files and they all need to be edited in a similar way. You thought about writing a sed, AWK, or Perl one-liner and can't think of a way. But the changes can be specified as a sequence of repeatable steps inside Vim.

Suppose you have this content in a file:

```text
aaa
bbb
ccc
bbb
ccc
eee
```

You need to add a missing line `ddd` after the second occurrence of `ccc`. Suppose you also need to make this change in all files matching an extended glob pattern `**/*.txt`.

- Solution 1 - using built-in functions

In a file /tmp/script.vim create the following Vimscript:

```vim
function! AddLine()
  call search("bbb")
  call search("bbb")
  let l:foundline = search("ccc")
  call append(l:foundline, "ddd")
  wq!
endfunction
```

Then execute that script on all of your files:

```text
▶ for i in **/*.txt ; do vim -u /tmp/script.vim -c 'call AddLine()' $i ; done
```

- Solution 2 - using normal mode

In a file /tmp/script.vim create the following Vimscript:

```vim
function! AddLine()
  normal /bbb^Mn/ccc^Moddd^[
  wq!
endfunction
```

Note that `^M` is a newline and `^[` is ESC. To enter these press CTRL-v then CTRL-M (^M) and CTRL-v then ESC (^[).

- Further explanation

The -u option tells Vim to load from a custom vimrc file and -c tells vim to execute that command on startup. The function AddLine() meanwhile calls `wq!` ensuring that vim starts, runs the function, and then saves and exits. This is repeated for each file in the for loop.

In the normal mode version of the function, the characters following the normal command are the literal keystrokes you would press inside Vim, in order.

### Convert a space separated string to newline separated string

- Problem

You have text in a file like:

```text
foo bar baz
```

You want it changed to:

```text
foo
bar
baz
```

- Solution

Select the line or lines in visual mode then:

```text
:'<,'>s/ /^M/g
```

### Copy some lines to the clipboard

- Problem

You have some lines in a file and you want them moved to the clipboard. For some reason, selecting them and doing a copy is too hard or not possible. You'd rather get them in visual mode.

- Solution (Mac OS X)

Select the lines in visual mode and then:

```
:'<,'> ! pbcopy
```

### Delete lines matching

- Problem

You have a bunch of lines matching a pattern PATTERN in a file. You want them all deleted.

- Solution

```
:%g/PATTERN/d
```

### Fix inconsistent cases

- Problem

You have variables, functions, etc in a file and some of them are in the incorrect case. Suppose the variable should be `FooBar` everywhere but has been inserted as variations of `Foobar`, `foobar` etc.

- Solution

```
:%s/\cfoobar/FooBar/gc
```

- Explanation

Use `\c` to search for a string case-insensitive in vim regular expressions.

- Reference

From [this]() Stack Overflow post.

### Record a macro

- Problem

You want to define a Vim Macro, to automate repeated steps within Vim.

Suppose you want a Macro to insert a Ruby debugging line:

```ruby
require 'pry'; binding.pry
```

You want the Macro to be played back when you hit `@a`.

- Solution

In normal mode:

```
qa
```

Vim displays that the Macro is recording. Now actually insert the text into the file. That is `o` to enter edit mode on the next line, type the Ruby code, and ESC to exit back to normal mode. Then press `q` to end recording.

To view the code of the Macro:

```
:reg a
"a   orequire 'pry'; binding.pry^M^[
```

To playback the Macro, `@a`.

### Sort lines in a file

- Problem 1

You have some lines in a file that you'd like ordered alphabetically, e.g.

```yaml
---
Foo: Bar
Baz: Qux
```

- Solution

1. Use visual mode to select the lines foo and baz.
2. Then:

```
:'<,'> ! sort
```

- Problem 2

Just sort the entire file.

- Solution 2

```
:% ! sort
```
