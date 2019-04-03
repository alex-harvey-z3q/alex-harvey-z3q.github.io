---
layout: post
title: "My sed and AWK Cookbook"
date: 2019-04-02
author: Alex Harvey
tags: sed awk
---

This is a list of my favourite productivity-enhancing sed & AWK one-liners.

- ToC
{:toc}

## Edit files in place

### In general

- Problem

You want to replace all instances of a pattern in a file in place without saving a backup.

- Solution using sed (Mac OS X)

```text
sed -i '' 's/SEARCH/REPLACE/g'
```

- Solution using sed (Linux)

```text
sed -i 's/SEARCH/REPLACE/g'
```

### Remove trailing whitespaces

```text
sed -i 's/  *$//'
```

## Print all lines between two patterns

### Print all lines between two patterns, inclusive, patterns may recur

- Problem

Suppose you have these lines in a file:

```text
aaa
PATTERN1
bbb
ccc
PATTERN2
ddd
PATTERN1
eee
fff
PATTERN2
ggg
```

You want to return these lines:

```text
PATTERN1
bbb
ccc
PATTERN2
PATTERN1
eee
fff
PATTERN2
```

- Solution using sed

```text
sed -n '/PATTERN1/,/PATTERN2/p'
```

- Solution using AWK

```text
awk '/PATTERN1/,/PATTERN2/'
```

- Reference

On Stack Overflow [here](https://stackoverflow.com/a/38978201/3787051) and [here](https://stackoverflow.com/a/38972737/3787051).

### Print all lines between two patterns, inclusive, first match only if patterns recur

Suppose you have these lines in a file:

```text
aaa
PATTERN1
bbb
ccc
PATTERN2
ddd
PATTERN1
eee
fff
PATTERN2
ggg
```

You want to return these lines:

```text
PATTERN1
bbb
ccc
PATTERN2
```

- Solution using sed

```text
sed -n '/PATTERN1/,/PATTERN2/p;/PATTERN2/q'
```

- Solution using AWK

```text
awk '/PATTERN1/,/PATTERN2/;/PATTERN2/{exit}'
```

### Print all lines between two patterns, exclusive, patterns may recur

- Problem

Suppose you have these lines in a file:

```text
aaa
PATTERN1
bbb
ccc
PATTERN2
ddd
PATTERN1
eee
fff
PATTERN2
ggg
```

You want to return these lines:

```text
bbb
ccc
eee
fff
```

- Solution using sed

```text
sed -n '/PATTERN1/,/PATTERN2/{//!p;}'
```

- Solution using AWK

```text
awk '/PATTERN1/,/PATTERN2/{if(/PATTERN2|PATTERN1/)next;print}'
```
