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

### Insert a line after each instance of a pattern

- Problem 1

You want to insert a line `foo` after a pattern `PATTERN` in a file.

- Solution using GNU sed

```text
sed -i '/PATTERN/a foo'
```

If you need to also insert say 2 leading newlines:

```text
sed -i '/PATTERN/a \ \ foo'
```

- Problem 2

You want to insert a line "`  foo`" with 2 leading spaces after a pattern `PATTERN` in a file.

- Solution using GNU sed

```text
sed -i '/PATTERN/a \ \ foo'
```

### Insert a line before each instance of a pattern

- Problem

You want to insert a line `foo` before a pattern `PATTERN` in a file.

- Solution using GNU sed

```text
sed -i '/PATTERN/i foo'
```

### Insert a line after the last instance of a pattern

- Problem

You want to insert a line `foo` after the _last_ instance of a pattern `PATTERN` in a file.

- Solution

```text
sed -i '1h;1!H;$!d;x;s/.*PATTERN[^\n]*/&\nfoo/'
```

- Reference

See [Stack Overflow](https://stackoverflow.com/a/37911473/3787051).

## Print a line or range of lines

### Print the nth line in a file

- Problem

You want to print the nth line in a file, for example the 11th.

- Solution using sed

```text
sed -n 11p
```

### Print all lines between the nth and mth, inclusive

- Problem

Suppose you want to print the 4th to 11th lines inclusive in a file.

- Solution using sed

```text
sed -n 4,11p
```

### Print all lines from the nth to the end of file, inclusive

- Problem

Suppose you want to print all lines from the 4th to the end of file.

- Solution using sed

```text
sed -n '4,$p'
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

### Print all lines between two patterns, exclusive, first match only if patterns recur

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
```

- Solution using GNU sed

```text
gsed '0,/PATTERN1/d;/PATTERN2/Q'
```

- Solution using AWK

```text
awk '/PATTERN1/{f=1;next}/PATTERN2/{exit}f'
```

- Reference

On Stack Overflow [here](https://stackoverflow.com/a/55220428/3787051) and [here](https://stackoverflow.com/a/55222083/3787051).
