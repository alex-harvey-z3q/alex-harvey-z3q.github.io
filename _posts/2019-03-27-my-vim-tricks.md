---
layout: post
title: "My Vim Cookbook"
date: 2019-03-27
author: Alex Harvey
tags: vim
---

This is a list of my favourite productivity-enhancing vim tricks.

#### Table of contents

1. [Enter visual mode](#enter-visual-mode)
2. [Fix inconsistent cases](#fix-inconsistent-cases)
3. [Sort lines in a file](#sort-lines-in-a-file)
4. [auto-indent some code](#auto-indent-some-code)
5. [auto-indent a JSON document using jq](#auto-indent-a-json-document-using-jq)

## Enter visual mode

- Problem

You don't know how to enter visual mode in vim. E.g. select the lines foo and baz in the following:

```json
{
  "Foo": "Bar",
  "Baz": "Qux"
}
```

That's important because the other recipes in this article mostly rely on Vim visual mode.

- Solution

Move the cursor to line 2. `SHIFT-V`. `j` (to move down one line). `:`. Vim enters command mode with the beginning of a command set to `:'<,'>`. Now enter the rest of the command e.g. `:'<,'>s/: /:/` (remove the space after the colons).

- Reference

See the [Vim manual](http://vimdoc.sourceforge.net/htmldoc/visual.html).

## Fix inconsistent cases

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

## Sort lines in a file

- Problem 1

You have some lines in a file that you'd like ordered alphabetically, e.g.

```json
{
  "Foo": "Bar",
  "Baz": "Qux"
}
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

## auto-indent some code

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

Enter visual mode and select the block of code. Press `=`. The code is now indented as:

```bash
while true ; do
  echo "hello world"
done
```

## auto-indent a JSON document using jq

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
