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

The basic function of AWK is to search files for lines that match patterns. When a line matches one of the patterns, AWK performs specified actions on that line. AWK continues to process input lines in this way until it reaches the end of the input files. AWK programs therefore are not procedural, but _data driven_ - that is you describe the data and then what you want done with it.

An AWK program is a list of "rules" that specify "patterns" and "actions" to perform on the lines that match the pattern. Lines are known as "records" and the lines are automatically split into "fields".

An AWK program looks like this:

```text
/pattern1/ { action1 }
/pattern2/ { action2 }
```

For example, print the first and fifth field of all lines in /etc/passwd that match /roo/:

```bash
awk -F: '/roo/ {print $1, $5}' /etc/passwd
```

## AWK's variables

AWK provides a number of built-in variables that programs can use to get information. Other variables can be set as well to control how AWK processes data.

|variable|description|
|========|===========|
|`ARGC`, `ARGV`|The command-line arguments available to awk programs are stored in an array called ARGV. ARGC is the number of command-line arguments present.|
|`FIELDWIDTHS`|allows the specification of fixed width fields.|
|`FPAT`|allows specification of the contents of fields.|
|`FS`|the field separator. The default value is " " although AWK treats that field separator to mean "whitespace" characters, including TABs and newlines. Note that the field separator can be a regular expession.|
|`IGNORECASE`|set to 1 if you want to ignore case. Default is 0.|
|`NF`|the number of fields in the current record.|
|`NR`|The current record number in the current file. E.g. to emulate `cat -n` try `awk '{print NR, $0}'`.|
|`OFS`|the output field separator. Default value is " ".|
|`ORS`|the output record separator. Default value is "\n".|

Note that the `$` sign is used to refer to an AWK _field_. It does not indicate a _variable_, as in Bash and some other languages. Thus, $1 refers to the first field, $2 to the second, and so on. If the _variable_ `f` equals 1, then `$f` is `$1` is the first field. Thus, `$NF` is the last field.

For more info:

- User-modified variables are [here](https://www.gnu.org/software/gawk/manual/html_node/User_002dmodified.html#User_002dmodified)
- Auto-set variables are [here](https://www.gnu.org/software/gawk/manual/html_node/Auto_002dset.html#Auto_002dset).

## BEGIN/END

The `BEGIN` and `END` are special rules for supplying startup and cleanup actions for AWK programs. A `BEGIN` rule is executed once only, before the first input record is read. Likewise, an `END` rule is executed once only, after all the input is read. For example:

```awk
BEGIN {
  print "Counting lines that contain 'li'"
}
/li/ { ++n }
END {
  print "'li' appears in", n, "records."
}
```

## Using getline

AWK has a special built-in command called getline that can be used to explicitly read records from input. Calling it sets `$0`, `NF`, `FNR`, `NR`, and `RT`. This example emulates `grep -A1 foo`:

```awk
/foo/ {
  print; getline; print
}
```

## I/O redirection

It is possible _within_ an AWK program to redirect the output. For example:

```text
▶ awk -F: '{print $1, $5 >> "/tmp/logfile"}' /etc/passwd
```

This prints out the 1st and 5th fields of the /etc/passwd file and appends them to a file /tmp/logfile.

Most of the other Shell I/O controls are also there, e.g. pipes, redirecting STDERR to STDOUT etc.

## Control statements

Nearly all of AWK's control statements are identical in syntax to those in C.

### For loop

Print the first 3 fields of every record:

```awk
{
  for (i = 1; i <= 3; i++)
    print $i
}
```

### While loop

Do the same using a while loop:

```awk
{
  i = 1
  while (i <= 3) {
    print $i
    i++
  }
}
```

### If/else statement

Odd or even numbers:

```awk
if (x % 2 == 0)
  print "x is even"
else
  print "x is odd"
```

## Functions

### Built-ins

Some of the built-in functions that are useful. For the full list see the docs [here](https://www.gnu.org/software/gawk/manual/html_node/Built_002din.html#Built_002din).

#### gensub (GAWK only)

Usage: gensub(regexp, replacement, how [, target]) #

Search the target string target for matches of the regular expression regexp. If how is a string beginning with ‘g’ or ‘G’ (short for “global”), then replace all matches of regexp with replacement. Otherwise, how is treated as a number indicating which match of regexp to replace. If no target is supplied, use $0. It returns the modified string as the result of the function and the original target string is not changed. For example:

```text
▶ echo a b c a b c | gawk '{print gensub(/a/, "AA", 2)}'
a b c AA b c
```

#### gsub

Usage: gsub(regexp, replacement [, target])

Search target for all of the longest, leftmost, nonoverlapping matching substrings it can find and replace them with replacement. The ‘g’ in gsub() stands for “global,” which means replace everywhere. For example:

```text
▶ echo a b c a b c | awk '{gsub(/a/, "AA"); print}'
AA b c AA b c
```

#### split

Usage: split(string, array [, fieldsep [, seps ] ])

Divide string into pieces separated by fieldsep and store the pieces in array and the separator strings in the seps array. Example:

```text
▶ echo cul-de-sac | awk '{split($0, a, "-"); print a[3]}'
sac
```

#### substr

Usage: substr(string, start [, length ])

Return a length-character-long substring of string, starting at character number start. The first character of a string is character number one.

```text
▶ echo cul-de-sac | awk '{print substr($0, 8, 3)}'
sac
```

### User-defined

It is also possible to define your own functions. Here is an example of a user-defined function, called myprint(), that takes a number and prints it in a specific format:

```awk
function myprint(num) {
  printf "%6.3g\n", num
}
```

## Including libraries

It is possible to split up larger AWK programs into smaller ones, but only using GNU AWK or gawk. Here is an example. Create two files, foo.awk and bar.awk:

```ruby
# foo.awk
BEGIN {
  print "I, foo."
}
```

And:

```ruby
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

This is something I wished I'd known many times years ago as a sysadmin.

Suppose I have the output from ls -l:

```text
▶ ls -l
total 21
drwxrwxr-x+ 53 root  admin  1696 24 Mar 23:19 Applications/
drwxr-xr-x+ 67 root  wheel  2144 17 Oct 17:15 Library/
drwxr-xr-x   2 root  wheel    64 28 Jul  2018 Network/
drwxr-xr-x@  4 root  wheel   128  4 Jul  2018 System/
```

What if I want to print the date and the file name? Typically, I would do something like this:

```text
▶ ls -l | awk 'NR > 1 {print $6, $7, $8, $9}'
24 Mar 23:19 Applications/
17 Oct 17:15 Library/
28 Jul 2018 Network/
4 Jul 2018 System/
```

That's ugly because I am forced to treat 2 logical fields as if they are 4, and also the text is misaligned in the output. But I can instead treat this as fixed-width data and tell AWK the field widths:

```text
▶ ls -l | awk 'BEGIN {FIELDWIDTHS = "11 2 5 6 5 12 100"} NR > 1 {print $6, $7}'
24 Mar 23:19  Applications/
17 Oct 17:15  Library/
28 Jul  2018  Network/
 4 Jul  2018  System/
```

Full disclosure: ls -l dynamically adjusts its field widths. It was fun anyway.

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

## Summary

I covered off my favourite learnings of skimming the AWK manual one evening. This post covers a brief list of AWK features that I expect I'm going to find useful at some time or other!
