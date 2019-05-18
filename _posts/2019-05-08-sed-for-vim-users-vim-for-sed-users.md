---
layout: post
title: "Vim for sed users"
date: 2019-05-08
author: Alex Harvey
tags: sed vim
published: false
---

This post explores feature overlap between vim and sed.

## Overview

Both vim and sed have a common ancestor, the ancient Unix text editor, ed. Both programs vim and sed have both inherited most of ed's features and thus they have many features in common with each other. Often, the commands are identical in both programs, and sometimes only similar. In this article, I am going to go through all of this feature overlap.

## :[range]g/re/command-list

The vim `[range]g/re/command-list` command allows the vim user to run commands on a range of lines or all lines in much the same way as most sed scripts. In the following table, vim commands and their equivalents in sed are shown.

|Description|vim|sed|
|===========|===|===|
|Delete all lines matching a pattern|`:g/pattern/d`|`/pattern/d`|
|Print lines matching a pattern|`:g/pattern/p`|`/pattern/p`|
|Perform substitution on all lines matching a pattern|`:g/pattern/s/foo/bar/`|`/pattern/s/foo/bar/`|
|Execute multiple commands on all lines matching a pattern|`:g/pattern/ s/foo/bar/ | s/baz/qux/`|`/pattern/{s/foo/bar/;s/baz/qux/}`|
|Delete the first 3 lines|`:1,3d`|`1,3d`|
|Delete line 8 to the end of the file|`:8,$d`|`8,$d`|
|Delete lines matching a pattern within a range|`:5,10g/pattern/d`|`5,10{/pattern/d}`|
|Perform a substitution on line 42|`:42s/foo/bar/`|`42s/foo/bar/`|
|Delete all lines NOT matching a pattern|`:g!/pattern/d` or `:v/pattern/d`|`!/pattern/d`|
