---
layout: post
title: "My sed and AWK Cookbook"
date: 2019-04-02
author: Alex Harvey
tags: sed awk
published: false
---

This is a list of my favourite productivity-enhancing sed & AWK one-liners.<sup>1</sup>

- ToC
{:toc}

## Edit files in place

- Problem

You want to replace all instances of a pattern in a file in place without saving a backup.

- Solution using sed (Mac OS X)

```text
sed -i '' 's/SEARCH/REPLACE/g'
```

- Solution using sed (Linux)

```text
gsed -i 's/SEARCH/REPLACE/g' FILE
```

## Inserting lines before or after patterns

### After each instance of a pattern

- Problem

You want to insert a line `foo` after a pattern `PATTERN` in a file.

- Solution using sed

```text
gsed -i '/PATTERN/a foo' FILE
```

If you need to also insert say 2 leading newlines:

```text
gsed -i -e '/PATTERN/a\' -e '  foo' FILE
```

### Before each instance of a pattern

You want to insert a line `foo` before a pattern `PATTERN` in a file.

- Solution using sed

```text
gsed -i '/PATTERN/i foo' FILE
```

### After the last instance of a pattern

- Problem

You want to insert a line `foo` after the _last_ instance of a pattern `PATTERN` in a file.

- Solution

```text
sed -i '1h; 1!H; $!d; x; s/.*PATTERN[^\n]*/&\nfoo/' FILE
```

- Reference

See [Stack Overflow](https://stackoverflow.com/a/37911473/3787051).

## Print a line N lines before or after matching a pattern

### Print a line N lines after matching a pattern

For N=1:

```text
gsed -n '/PATTERN/{n;p}' FILE
```

For N=2:

```text
gsed -n '/PATTERN/{n;n;p}' FILE
```

### Print a line N lines before matching a pattern

For N=1:

```text
sed '$!N; /.*\n.*PATTERN/P; D' FILE
```

For N=2:

```text
sed '1N; $!N; /.*\n.*\n.*PATTERN/P; D' FILE
```

For N=3:

```text
sed '1{N;N};$!N;/.*\n.*\n.*\n.*pattern/P;D'
```

For N=4:

```text
sed '1{N;N;N}; $!N; /.*\n.*\n.*\n.*\n.*PATTERN/P; D' FILE
```

See [Stack Overflow](https://unix.stackexchange.com/a/283489/231569).

## Print a line or range of lines

### Print the nth line in a file

For example, the 11th line of a file:

```text
sed -n 11p
```

### Print all lines between the nth and mth, inclusive

The 4th to 11th lines inclusive in a file:

```text
sed -n 4,11p
```

### Print all lines from the nth to the end of file, inclusive

The 4th line to the end of file:

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
PATTERN1
hhh
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
PATTERN1
hhh
```

- Solution using sed

```text
sed -n '/PATTERN1/,/PATTERN2/p' FILE
```

- Solution using AWK

```text
awk '/PATTERN1/,/PATTERN2/' FILE
```

- Reference

On Stack Overflow [here](https://stackoverflow.com/a/38978201/3787051) and [here](https://stackoverflow.com/a/38972737/3787051).

### Print all lines between two patterns, inclusive, first match only if patterns recur

Suppose you only want to return these lines:

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
awk '/PATTERN1/,/PATTERN2/;/PATTERN2/{exit}' FILE
```

### Print all lines between two patterns, exclusive, patterns may recur

Suppose you only want to return these lines:

```text
bbb
ccc
eee
fff
```

- Solution using sed

```text
gsed -n '/PATTERN1/,/PATTERN2/{//!p}' FILE
```

- Solution using AWK

```text
awk '/PATTERN1/,/PATTERN2/{if(/PATTERN2|PATTERN1/)next;print}' FILE
```

### Print all lines between two patterns, exclusive, first match only if patterns recur

Suppose you only want to return these lines:

```text
bbb
ccc
```

- Solution using GNU sed

```text
gsed '0,/PATTERN1/d;/PATTERN2/Q' FILE
```

- Solution using AWK

```text
awk '/PATTERN1/{f=1;next}/PATTERN2/{exit}f' FILE
```

- Reference

On Stack Overflow [here](https://stackoverflow.com/a/55220428/3787051) and [here](https://stackoverflow.com/a/55222083/3787051).

## Remove trailing whitespaces in a file

```text
gsed -i 's/  *$//' FILE
```

## Search for a pattern within a function or block

Problem you want to search or "grep" for a pattern, but only within a function or block of code.

Suppose you have some text:

```text
aaa
bbb
function() {
  ccc
  ddd
  PATTERN
  eee
  fff
}
ggg
PATTERN
hhh
```

- Solution using sed

```text
sed -n '/^function/,/^}/{/PATTERN/p;}' FILE
```

---

<sup>1</sup> Note that many of these one-liners are [auto-generated](https://github.com/alexharv074/alexharv074.github.io/blob/master/erb/2019-04-02-my-sed-and-awk-cookbook.md.erb#L9-L24) from [unit test](https://github.com/alexharv074/alexharv074.github.io/blob/master/shunit2/sed_and_awk_cookbook.sh) code.
