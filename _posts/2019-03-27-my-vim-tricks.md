---
layout: post
title: "My Vim Cookbook"
date: 2019-03-27
author: Alex Harvey
tags: vim
---

This is a list of my favourite productivity-enhancing vim tricks.

## Fix inconsistent cases

- Problem

You have variables, functions, etc in a file and some of them are in the incorrect case. Suppose the variable should be `FooBar` everywhere but has been inserted as variations of `Foobar`, `foobar` etc.

- Solution

```
:%s/\cfoobar/FooBar/gc
```

- Explanation

Use `\c` to search for a string case-insensitive in vim regular expressions.

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

1. Use visual mode to select the lines foo and bar.
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
