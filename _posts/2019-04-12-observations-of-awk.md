---
layout: post
title: "Observations of AWK"
date: 2019-04-12
author: Alex Harvey
tags: awk
---

This post summarises observations that interested me when I spent a few hours on a weekend skim reading the [GNU AWK manual](www.gnu.org/software/gawk/manual/).

* ToC
{:toc}

## How AWK got its name

The name AWK comes from the initials of its designers: Alfred V. Aho, Peter J. Weinberger, and Brian W. Kernighan. It was written in 1977.

## The basic function of AWK

The basic function of AWK is to search for lines that contain certain patterns and perform "actions" on them. AWK is not a procedural programming language therefore, but a _data driven_ language.

An AWK program is just a list of "rules" that consist of a "pattern" and an "action" to perform on lines that match the pattern. Lines are also known as "records" and each line or record is automatically split up into "fields". An AWK program looks like this:

```text
/pattern1/ { action1 }
/pattern2/ { action2 }
```

## AWK's special variables

Some of these I knew and some I didn't and all seem useful:

- `$0` - the current record.
- `$1`, `$2` etc - field 1, field 2 etc.
- `NF` - the number of fields in the current record.
- `FS` - the field separator. The default value is " " although AWK treats that field separator to mean "whitespace" characters, including TABs and newlines. Note that the field separator can be a regular expession.
- `OFS` - the output field separator. Default value is " ".
- `IGNORECASE` - set to 1 if you want to ignore case. Default is 0.
- `FIELDWIDTHS` - allows the specification of fixed width fields.
- `FPAT` - allows specification of the contents of fields.

Full list is [here](https://www.gnu.org/software/gawk/manual/html_node/User_002dmodified.html#User_002dmodified) and [here](https://www.gnu.org/software/gawk/manual/html_node/Auto_002dset.html#Auto_002dset).

## Including libraries

It is possible to split up larger AWK programs into smaller ones, but only using GNU AWK or gawk. Here is an example. Create two files, foo.awk and bar.awk:

```awk
# foo.awk
BEGIN {
  print "I, foo."
}
```

And:

```awk
# bar.awk
@include "foo"
BEGIN {
  print "I, bar."
}
```

Then if I run bar.awk:

```text
▶ gawk -f bar.awk
I, foo.
I, bar.
```

A path name instead of a file name can also be passed to @include. See also the `AWKPATH` environment variable.

## Fixed width data

This is something I wished I'd known many times years ago as a sysadmin. Suppose I have the output from `ls -l`:

```text
▶ ls -l
total 21
drwxrwxr-x+ 53 root  admin  1696 24 Mar 23:19 Applications/
drwxr-xr-x+ 67 root  wheel  2144 17 Oct 17:15 Library/
drwxr-xr-x   2 root  wheel    64 28 Jul  2018 Network/
drwxr-xr-x@  4 root  wheel   128  4 Jul  2018 System/
```

What if I want to print the date and the file name? Typically, we do something like this:

```text
▶ ls -l | awk 'NR > 1 {print $6, $7, $8, $9}'
24 Mar 23:19 Applications/
17 Oct 17:15 Library/
28 Jul 2018 Network/
4 Jul 2018 System/
```

That's ugly because I am forced to treat 2 logical fields as if they are 4, and also the text is misaligned in the output. But you can instead treat this as fixed-width data and tell AWK the field widths:

```text
▶ ls -l | awk 'BEGIN {FIELDWIDTHS = "11 2 5 6 5 12 100"} NR > 1 {print $6, $7}'
24 Mar 23:19  Applications/
17 Oct 17:15  Library/
28 Jul  2018  Network/
 4 Jul  2018  System/
```

Especially useful for solving the problem of spaces in the file names!

(Full disclosure: ls -l dynamically adjusts its field widths. It was fun anyway.)

## Specifying the field pattern

Using the `FPAT` special variable, it is possible to tell AWK what a field contains. This can be useful if you have CSV data such as exported by MS Excel like this:

```text
Robbins,Arnold,"1234 A Pretty Street, NE",MyTown,MyState,12345-6789,USA
```

Suppose I want the 3rd field. I can get it this way:

```text
▶ echo 'Robbins,Arnold,"1234 A Pretty Street, NE",MyTown,MyState,12345-6789,USA' | \
    awk 'BEGIN {FPAT = "([^,]+)|(\"[^\"]+\")"} {print $3}'
"1234 A Pretty Street, NE"
```

## AWK has its own I/O redirection

I had not been aware that it is possible _within_ an AWK program to redirect the output. For example:

```text
▶ awk -F: '{print $1, $5 >> "/tmp/logfile"}' /etc/passwd
```

This prints out the 1st and 5th fields of the /etc/passwd file and appends them to a file /tmp/logfile.

Many of the other Shell features are also there, e.g. pipes, redirecting STDERR to STDOUT etc.

## AWK's control statements are just like C

Nearly every control statement in AWK, if/else, for loops, while/do loops etc are identical in syntax to those in C.

## Functions

### Built-ins

These are documented [here](https://www.gnu.org/software/gawk/manual/html_node/Built_002din.html#Built_002din).

### User-defined

Here is an example of a user-defined function, called myprint(), that takes a number and prints it in a specific format:

```awk
function myprint(num) {
  printf "%6.3g\n", num
}
```

## Summary

I covered off my favourite learnings of skimming the AWK manual one evening. This post covers a brief list of AWK features that I expect I'm going to find useful at some time or other!
