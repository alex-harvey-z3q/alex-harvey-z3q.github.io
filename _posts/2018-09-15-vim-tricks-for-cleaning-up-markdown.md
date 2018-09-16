---
layout: post
title: "Vim tricks for cleaning up Markdown"
date: 2018-09-15
author: Alex Harvey
tags: vim markdown
---

This post is a collection of vim regular expressions for cleaning up Markdown files for compliance with [mdl](https://github.com/markdownlint/markdownlint).

## Insert a blank line after headings

Convert all occurrences of:

~~~ text
## Some header
Some not blank line
~~~

To:

~~~ text
## Some header

Some not blank line
~~~

Vim:

~~~ text
:%s/^#\(.*\)\n\([^\n]\)/#\1^M^M\2/g
~~~

## Insert a blank line after fenced code blocks

Convert all occurrences of:

``` text
~~~
Some not blank line
```

To:

``` text
~~~

Some not blank line
```

Vim:

~~~ text
:%s/^\~\~\~\n\([^\n]\)/\~\~\~^M^M\1/g
~~~

