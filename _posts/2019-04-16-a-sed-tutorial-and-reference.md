---
layout: post
title: "A sed tutorial and reference"
date: 2019-04-16
author: Alex Harvey
tags: sed bash
---

I enjoyed reading the GNU AWK manual so much that I decided to read the [GNU sed manual](https://www.gnu.org/software/sed/manual/sed.html) too. Full disclaimer. sed is harder. Much harder!

This post began as a companion to my earlier post, [Observations of AWK](https://alexharv074.github.io/2019/04/12/observations-of-awk.html), and ended up as a full tutorial and reference.

* ToC
{:toc}

## Conventions

Throughout this post, I use `sed` in examples for a script that should work in any version of sed, such as the BSD sed that ships with Mac OS X; and I use `gsed` where GNU sed is actually required.<sup>1</sup> All sed scripts are unquoted unless single or double quotes are reqired to protect characters from interpretation by the shell.

## Scope and target audience

In this post, I cover most of the features of GNU sed, nearly all of its commands, but not regular expressions, only the command-line options I consider useful, and my treatment of branching and flow control is cursory. The target audience is a Bash programmer who knows the basics of sed and wants to learn the rest.

## What is sed

Sed stands for **s**tream **ed**itor. It is used to perform transformations on an input stream, either a file or input from a pipeline. It was written in 1973-4 by Lee E. McMahon and first appeared in Unix version 7.

## When to use sed

According to the [sed FAQ](http://sed.sourceforge.net/sedfaq6.html#s6.3), you should use sed when you need a small, fast program to modify words, lines, or blocks of lines in a text file. Conversely, you should _not_ use sed if `grep`, `tr`, `awk`, or `perl` do the job better. Use the right tool for the job. Note that almost any sed one-liner can be rewritten as a Perl one-liner, although the question of Bash idiom and performance should be considered. That is, these have the same effect:

```text
perl -pi -e 's/FOO/BAR/' FILE
```

and:

```text
sed -i 's/FOO/BAR/' FILE
```

But the sed version may be more idiomatic, easier to remember, easier to read and write - and also faster.

## Command-line options

### Command-line options summary

GNU sed has a lot of command-line options. Most of them I have never used, and after carefully reading the manual, the following table lists the only ones I consider useful.

|Option|Explanation|
|======|===========|
|`--debug`|(GNU sed only.) Print the input sed program in canonical form, and annotate program execution.|
|`-e SCRIPT`|Add the commands in `SCRIPT` to the set of commands to be run while processing the input.|
|`-f SCRIPTFILE`|Add the commands contained in the file `SCRIPTFILE` to the set of commands to be run while processing the input.|
|`-i[SUFFIX]`|This option specifies that files are to be edited in-place. GNU sed does this by creating a temporary file and sending output to this file rather than to the standard output. If a `SUFFIX` is supplied, a filename with this extension is created as a backup.|
|`-n`|By default, sed prints out the pattern space at the end of each cycle through the script. This disables automatic printing, and sed only produces output when explicitly told to via the `p` command.|
|`-r`, `-E`|Use extended regular expressions rather than basic regular expressions.|

For the remainder of the command-line options, see [the manual](https://www.gnu.org/software/sed/manual/sed.html#Command_002dLine-Options).

### Note about -e

I see shell scripts everywhere that specify the `-e` option, and, I think, most of the time unnecessarily, and probably because almost no one understands what the `-e` option is really for. Perhaps this is because the documentation is not all that clear. The man page says:

> **-e script**<br>
> **--expression=script**
>
>    Add the commands in script to the set of commands to be run while processing the input.

In fact, the following commands are identical:

```text
sed -e 's/foo/bar/; s/baz/qux/'
sed 's/foo/bar/; s/baz/qux/'
sed -e s/foo/bar/ -e s/baz/qux
sed '
  s/foo/bar/
  s/baz/qux/
  '
```

So, most of the time, you do not actually need to specify `-e`. In particular, there is never a good reason to specify just one `-e`; such code can and should always be refactored to remove the redundant `-e`. Use of `-e` makes sense when splitting up a command into multiple sections via multiple `-e` improves readability.

### Note about -i

The `-i` option allows editing of files in-place.

Be aware that in GNU sed only, the suffix passed to `-i` is optional. In BSD sed, to avoid a backup file being created, it is necessary to explicitly pass an empty string to `-i`. Thus:

_BSD sed_

```text
▶ sed -i '' s/aa/bb/ FILE
```

Is the same on BSD as:

_GNU sed_

```text
▶ gsed -i s/aa/bb/ FILE
```

## The structure of a sed script

### The structure of a command

All sed _commands_ have the following basic structure:

```
[ADDR]X[OPTIONS]
```

Where:

- `[ADDR]` is an optional [address specification](#address-specifications)
- `X` is a single-letter [command](#sed-commands)
- `[OPTIONS]` are optional options (or flags) accepted by the command.

The single-letter commands are called _functions_ in the BSD manual. `[ADDR]` is an optional address specification. If `[ADDR]` is specified, the command `X` will be executed only for lines matching `[ADDR]`. `[ADDR]` can be a single line number, a regular expression, or a range of lines. There is more on this [below](#address-specifications).

### The structure of a script

A sed _script_ is a sequence of commands:

```
[ADDR1]X[XOPTIONS]
[ADDR2]Y[YOPTIONS]
[ADDR3]Z[ZOPTIONS]
```

Note that instead of single-letter sed commands, commands can be _grouped_ instead, using `{ X; Y; Z }`:

```
[ADDR]{X[XOPTIONS];Y[YOPTIONS];Z[ZOPTIONS]}
```

### Example 1

The first example is one of the most familiar:

```text
gsed -i s/alexander/alex/g /etc/passwd
```

In that case, the optional `[ADDR]` is not used, the `s///` command follows, with a regexp `alexander`, a replacement `alex` and for `[OPTIONS]`, `g`. This script replaces all occurences of the string `alexander` with `alex`.

### Example 2

Another example:

```text
gsed -i 1,1000d /var/log/messages
```

Here the `[ADDR]` is `1,1000`, which specifies lines 1 to 1000; the single-letter command is `d` (delete); and there are no `[OPTIONS]`. This script would delete the first 1000 lines from a log file.

### Example 3

An example with a block:

```text
▶ sed -n '/roo/{p;p;q;}' /etc/passwd
root:*:0:0:System Administrator:/var/root:/bin/sh
root:*:0:0:System Administrator:/var/root:/bin/sh
```

This time the `[ADDR]` is `/roo/` meaning any line matching `/roo/`, and instead of a command there is a block `{p;p;q;}` - print, print, quit. So this script finds the first line matching `/roo/`, prints it twice, and then exits.

## Under the hood

So what is sed doing under the hood?

Sed operates by performing a _cycle_ on each line of a file: first, it reads one line from the input stream, removes any trailing newline, and places it in the pattern space (see [below](#the-pattern-space-and-hold-space)). The commands are then executed. The optional `[ADDR]` (address specification) is a kind of conditional; the command is only executed if the condition is verified before the command is to be executed.

When the end of the script is reached, unless the `-n` option is in use, the contents of pattern space are printed out to the output stream, adding back the trailing newline if it was removed. Then the next cycle starts for the next input line.

## The pattern space and hold space

Sed maintains two buffers: the _pattern space_ and the _hold space_. Both are initially empty.

The pattern space buffers each line that is read in from the input stream, although the `N` command can grow the pattern space by additional input lines. Unless special commands like `D` are used, the pattern space is deleted between cycles.

The hold space, on the other hand, keeps its data between cycles. I'll have more to say about the hold space (see [below](#using-the-hold-space)), but, for now, just remember that there are two buffers and remember their names.

## Sed commands

### Overview

Understanding sed, in my opinion, requires learning _nearly all_ of its single-letter commands. The GNU sed manual groups the commands in this way:

- `s///` - the "s" command.
- `q`, `d`, `p`, `n` - "commonly-used" commands.
- `y///`, `a`, `i`, `c`, `=`, `l`, `r`, `w`, `d`, `n`, `P`, `h`, `H`, `g`, `G`, `x` - "less frequently-used" commands.
- `:`, `b`, `t` - "commands for sed gurus".
- `e`, `F`, `Q`, `R`, `T`, `v`, `W`, `z` - GNU sed extensions.

A troubling implication of this breakdown, of course, is that learning GNU sed at all beyond the "commonly-used" commands - and it is beyond these that the difficulty lies - might be a waste of time, in the sense that any sed program requiring the others could be better written in AWK or Perl.

In this post, however, I have used a different breakdown:

- `=`, `a`, `c`, `d`, `e`, `i`, `l`, `n`, `p`, `q`, `Q`, `s///`, `y///`, `z` - "easy to use" commands, and I have included discussion and examples of their usage in this section.
- `:`, `b`, `h`, `H`, `g`, `G`, `P`, `t`, `T`, `x` - commands for multiline techniques, the hold space, branching, and flow control, all are for sed gurus, and with examples in subsequent sections.
- `F`, `r`, `R`, `v`, `w`, `W` - commands that are mostly GNU extensions and that I don't regard as sufficiently useful to discuss in this post.

Finally, it can be seen that sed is a tiny language. As initimidating as all of its cryptic commands are, it is actually easy to learn.

### Sed command cheat sheet

This section presents a cheat sheet, and when I say "cheat sheet", I mean every command in sed in alphabetical order, mostly lifted word for word from the docs.

|Command|Description|
|=======|===========|
|[`a\` (append)](#the-i-a-and-c-commands-insert-append-change)|Append text after a line.|
|[`TEXT`](#the-i-a-and-c-commands-insert-append-change)||
|[`a TEXT`](#the-i-a-and-c-commands-insert-append-change)|Append text after a line (alternative syntax).|
|[`b LABEL` (branch)](#the--b-t-and-t-commands)|Branch unconditionally to label. The label may be omitted, in which case the next cycle is started.|
|[`c\` (change)](#the-i-a-and-c-commands-insert-append-change))|Replace lines with text.|
|[`TEXT`](#the-i-a-and-c-commands-insert-append-change)||
|[`c TEXT`](#the-i-a-and-c-commands-insert-append-change)|Replace (change) lines with text (alternative syntax).|
|[`d` (delete)](#the-d-command-delete)|Delete the pattern space; immediately start next cycle.|
|[`D`](#the-h-h-hold-g-g-get-and-x-exchange-commands)|If pattern space contains newlines, delete text in the pattern space up to the first newline, and restart cycle with the resultant pattern space, without reading a new line of input. If pattern space contains no newline, start a normal new cycle as if the `d` command was issued.|
|[`e` (exec)](#the-e-command-exec)|Executes the command that is found in pattern space and replaces the pattern space with the output; a trailing newline is suppressed.|
|[`e COMMAND`](#the-e-command-exec)|Executes `COMMAND` and sends its output to the output stream. The command can run across multiple lines, all but the last ending with a back-slash.|
|`F` (filename)|Print the file name of the current input file (with a trailing newline).|
|[`g` (get)](#the-h-h-hold-g-g-get-and-x-exchange-commands)|Replace the contents of the pattern space with the contents of the hold space.|
|[`G`](#the-h-h-hold-g-g-get-and-x-exchange-commands)|Append a newline to the contents of the pattern space, and then append the contents of the hold space to that of the pattern space.|
|[`h` (hold)](#the-h-h-hold-g-g-get-and-x-exchange-commands)|Replace the contents of the hold space with the contents of the pattern space.|
|[`H`](#the-h-h-hold-g-g-get-and-x-exchange-commands)|Append a newline to the contents of the hold space, and then append the contents of the pattern space to that of the hold space.|
|[`i\` (insert)](#the-i-a-and-c-commands-insert-append-change)|insert text before a line.| <!-- `] -->
|[`TEXT`](#the-i-a-and-c-commands-insert-append-change)||
|[`i TEXT`](#the-i-a-and-c-commands-insert-append-change)|Insert text before a line (alternative syntax).|
|[`l`](#the-l-command)|Print the pattern space in an unambiguous form. This is useful for debugging and revealing unprintable characters.|
|[`n` (next)](#the-n-command-next)|If auto-print is not disabled, print the pattern space, then, regardless, replace the pattern space with the next line of input. If there is no more input then sed exits without processing any more commands.|
|[`N`](#the-d-g-h-n-and-p-commands)|Add a newline to the pattern space, then append the next line of input to the pattern space. If there is no more input then sed exits without processing any more commands.|
|[`p` (print)](#the-p-command-print)|Print the pattern space.|
|[`P`](#the-d-g-h-n-and-p-commands)|Print the pattern space, up to the first newline.|
|[`q[EXITCODE]` (quit)](#the-q-and-q-commands-quit)|Exit sed without processing any more commands or input.|
|[`Q[EXITCODE]`](#the-q-and-q-commands-quit)|This command is the same as `q`, but will not print the contents of pattern space. Like `q`, it provides the ability to return an exit code of `EXITCODE` to the caller.|
|`r FILENAME` (read)|Reads file `FILENAME`.|
|`R FILENAME`|Queue a line of `FILENAME` to be read and inserted into the output stream at the end of the current cycle, or when the next input line is read.|
|[`s/REGEXP/REPLACEMENT/[FLAGS]` (substitute)](#the-s-command-substitute)|Match the regular expression `REGEXP` against the content of the pattern space. If found, replace matched string with `REPLACEMENT`.|
|[`t LABEL` (test)](#the--b-t-and-t-commands)|Branch to `LABEL` only if there has been a successful substitution since the last input line was read or conditional branch was taken. The label may be omitted, in which case the next cycle is started.|
|[`T LABEL`](#the--b-t-and-t-commands)|Branch to `LABEL` only if there have been no successful substitutions since the last input line was read or conditional branch was taken. The label may be omitted, in which case the next cycle is started.|
|`v [VERSION]` (version)|This command does nothing, but makes sed fail if GNU sed extensions are not supported, or if the requested version is not available.|
|`w FILENAME` (write)|Write the pattern space to `FILENAME`.|
|`W FILENAME`|Write to the given `FILENAME` the portion of the pattern space up to the first newline.|
|[`x` (exchange)](#the-h-h-hold-g-g-get-and-x-exchange-commands)|Exchange the contents of the hold and pattern spaces.|
|[`y/SRC/DST/`](#the-y-command)|Transliterate any characters in the pattern space which match any of the `SRC` with the corresponding character in `DST`.|
|[`z` (zap)](#the-z-command-zap)|This command empties the content of pattern space.|
|[`=`](#the--command)|Print the current input line number (with a trailing newline).|
|[`: LABEL`](#the--b-t-and-t-commands)|Specify the location of label for branch commands (`b`, `t`, `T`).|

### The s command (substitute)

#### Overview

[Some](https://stackoverflow.com/questions/12833714/the-concept-of-hold-space-and-pattern-space-in-sed#comment25463630_12833714) say the `s` and `p` commands are the only commands that sed should ever be used for. I disagree with those people but I thought I should mention it.

The `s` command has the form:

```text
s/REGEXP/REPLACEMENT/[FLAGS]
```

The `s` command attempts to match the pattern space against the supplied regular expression `REGEXP`; if the match is successful, then the portion of the pattern space that matched is replaced with `REPLACEMENT`.

#### Using a different delimiter

If the regular expression itself contains the `/` character, it is typical to use a different delimiter. Sed accepts any character as a replacement delimiter. For example:

```text
▶ gsed -i 's!/bin/bash!/bin/tcsh!' /etc/passwd
```

Which would change everyone's shell to `tcsh`, because, why not?

#### Back references

The replacement can contain back references, `\1`, `\2` .. `\9`. (If you need 10 or more back references, you should consider using Perl<sup>2</sup>.)

For example:

```text
▶ echo 'James Bond' | sed -E 's/(.*) (.*)/The name is \2, \1 \2./'
The name is Bond, James Bond.
```

#### Back reference &

Also, the replacement can contain unescaped `&` characters which reference the whole matched portion of the pattern space.

For example, double all spaces:

```text
▶ echo "a b c" | sed 's/ /&&/g'
a  b  c
```

#### Case conversions (GNU only)

In GNU sed there are extensions for converting text to upper and lower case:

|code|description|
|====|===========|
|`\L`|Turn the replacement to lowercase until a `\U` or `\E` is found.|
|`\l`|Turn the next character to lowercase.|
|`\U`|Turn the replacement to uppercase until a `\L` or `\E` is found.|
|`\u`|Turn the next character to uppercase.|
|`\E`|Stop case conversion started by `\L` or `\U`.|

For example, convert all instances of a string to uppercase:

```text
▶ echo foobarfoobazfooqux | gsed -E 's/(foo)/\U\1\E/g'
FOObarFOObazFOOqux
```

For another example, convert only the first letter of a string to uppercase:

```text
▶ echo foobarfoobazfooqux | gsed -E 's/(foo)/\u\1/g'
FoobarFoobazFooqux
```

#### Flags

Here is the full list of flags accepted by `s///`:

|flag|description|
|====|===========|
|`g`|Apply the replacement to all matches to the regexp, not just the first.|
|`NUMBER`|Only replace the `NUMBER`th match of the regexp. In GNU sed, if `g` and `NUMBER` are combined, ignore matches before the `NUMBER`th, and then match and replace all matches from the `NUMBER`th on.
|`p`|If the substitution was made, then print the new pattern space.|
|`w FILENAME`|If the substitution was made, then write out the result to the named file. As a GNU sed extension, two special values of filename are supported: `/dev/stderr`, which writes the result to the standard error, and `/dev/stdout`, which writes to the standard output.|
|`e`|This command allows one to pipe input from a shell command into pattern space. If a substitution was made, the command that is found in pattern space is executed and pattern space is replaced with its output. A trailing newline is suppressed; results are undefined if the command to be executed contains a NUL character. This is a GNU sed extension.|
|`I`, `i`|The `I` modifier to regular expression matching is a GNU extension which makes sed match regexp in a case-insensitive manner.|
|`M`, `m`|The `M` modifier to regular expression matching is a GNU sed extension which directs GNU sed to match the regular expression in multi-line mode. The modifier causes `^` and `$` to match respectively (in addition to the normal behavior) the empty string after a newline, and the empty string before a newline.|

#### Example 1

Here are some examples. Replace all instances of a pattern from the second onwards:

```text
▶ echo "a=b=c=d" | gsed 's/=/ /2g'
a=b c d
```

#### Example 2

Print only lines where replacements are made:

```text
▶ sed -n s/roo/kangaroo/p /etc/passwd
kangaroot:*:0:0:System Administrator:/var/root:/bin/sh
daemon:*:1:1:System Services:/var/kangaroot:/usr/bin/false
_cvmskangaroot:*:212:212:CVMS Root:/var/empty:/usr/bin/false
```

### The q and Q commands (quit)

The `q` and `Q` commands are useful if for whatever reason you want sed to quit and stop printing. Some examples:

Emulate the head command:

```text
▶ seq 10 | sed 3q
1
2
3
```

The difference between `q` and `Q` is that `q` prints the line then quits, whereas `Q` quits without printing. Here's an example of `Q`:

Print all lines between (the first instance of) 2 patterns, exclusive of the patterns:

```text
▶ seq 10 | gsed '0,/3/d;/7/Q'
4
5
6
```

### The d command (delete)

The `d` command deletes the pattern space, and also immediately begins the next cycle.

Some examples:

Delete all lines in a file matching a pattern:

```text
gsed -i '/PATTERN/d' FILE
```

Delete the first 10 lines in a file:

```text
gsed -i '1,10d' FILE
```

There is more on the `d` command in relation to its branching behaviour [below](#branching-and-flow-control).

### The p command (print)

The `p` command prints out the pattern space to STDOUT. The `p` command is mostly only used in conjunction with the `-n` option to sed, because, otherwise, printing each line is sed's default behaviour.

Using `p` and `-n` is another way to emulate the head command. Print only lines 1 to 3:

```text
sed -n 1,3p
```

### The n command (next)

The `n` command behaves differently depending on whether `-n` is enabled:

- If `-n` is specified, just replace the pattern space with the next line of input.
- If `-n` is not specified, print the pattern space, then replace it with the next line of input.

Some examples. Emulate `grep -A2 3`:

```text
▶ seq 10 | sed -n '/3/{p;n;p;n;p;}'
3
4
5
```

Print only the line after a line matching 3:

```text
▶ seq 10 | sed -n '/3/{n;p;}'
4
```

Perform a substitution only every 3rd line:

```text
▶ seq 6 | sed 'n;n;s/./x/'
1
2
x
4
5
x
```

### The y command

The `y/SRC/DST/` is occasionally used and occasionally useful. It transliterates characters in the pattern space which match any of the `SRC` with the corresponding character in `DST`. For example, convert all upper case characters to lower case:

```text
▶ uc='ABCDEFGHIJKLMNOPQRSTUVWXYZ'
▶ lc='abcdefghijklmnopqrstuvwxyz'
▶ echo 'Hello WoRLD' | sed "y/$uc/$lc/"
hello world
```

### The i, a and c commands (insert, append, change)

Using `i`, `a` and `c` we can insert before, append after, and replace (change) lines matching patterns or otherwise satisfying a condition. For example, given a file:

```text
aa
bb
XX
ee
```

Replace `XX` with the missing lines of the pattern, aa, bb, cc, dd, ee.

```text
▶ gsed -e '/XX/c\' -e "cc\ndd" FILE
aa
bb
cc
dd
ee
```

### The l command

The `l` command prints text in an unambiguous way, revealing hidden and unprintable characters:

```text
▶ sed -n l FILE
aa$
bb$
XX\032$
ee\033$
```

Compare to:

```text
▶ cat FILE
aa
bb
XX
ee
```

Using a GNU extension a line wrap can also be specified:

```text
▶ gsed -n l72 FILE
```

### The = command

The `=` command can be used to print the line numbers. A bit like an alternative to `cat -n`:

```text
▶ cat FILE | sed =
1
aa
2
bb
3
XX
4
ee
```

### The z command (zap)

While not often required, it's also not terribly complicated. The `z` (zap) command, in GNU sed only, can be used as a more reliable and efficient alternative to `s/.*//`, to simply empty the pattern space.

### The e command (exec)

While I don't necessarily recommend doing this, the GNU sed `e` command can be used to pipe the pattern space into an external Unix command. For example, print lines after a replacement, piping the response into the Unix column command:

```text
▶ gsed -nE 's/^roo(.*)/echo "kangaroo\1" | column -t -s:/ep' /etc/passwd
kangaroot  *  0  0  System Administrator  /var/root  /bin/sh
```

Meanwhile, the `e` command with an optional command following it simply executes that command and sends it output into the output stream. I'll update this post if I ever find a use for it!

## Grouping commands

### Brace notation

Commands can be grouped in a block as in other programming languages.

For example, perform substitution then print the second input line:

```text
▶ seq 3 | gsed -n '2{s/2/X/;p}'
X
```

Or a real life example, suppose I have a script:

```bash
#!/usr/bin/env bash

myfunction() {
  local foo=$1
  echo "${foo}\n"
}

myfunction foo
myfunction foo
```

And I want to update the name of the variable foo, but only inside the function myfunction only, and print the new version of the function after the substitutions. I can do this:

```text
▶ gsed -n '/^myfunction()/,/^}/{s/foo/bar/g; p}' FILE
myfunction() {
  local bar=$1
  echo "${bar}\n"
}
```

Which is a bit more readable written out like this:

```text
/^myfunction()/,/^}/ {  # for lines in the range /^myfunction()/ to /^}/
  s/foo/bar/g   # substitute foo with bar
  p             # print the pattern space
}
```

### A note about semi-colons

Grouped sed commands can be separated on a single line by the semi-colon `;` or separated on multiple lines where the semi-colon is not required. That is:

```text
1d
3d
5d
```

Is the same as:

```text
1d;3d;5d
```

Is the same as:

```text
sed -e 1d -e 3d -e 5d
```

Be aware that BSD sed and GNU sed have different syntactic requirements inside a block. This script:

```text
▶ seq 6 | gsed '{1d;3d;5d}'
2
4
6
```

Works fine, but in BSD sed, an error is emitted:

```text
▶ seq 6 | sed '{1d;3d;5d}'
sed: 1: "{1d;3d;5d}": extra characters at the end of d command
```

To write code that works in both GNU and BSD sed, terminate the last character in a group with a semi-colon, if followed by a closing brace:

```text
▶ seq 6 | sed '{1d;3d;5d;}'
2
4
6
```

### A note about comments

As already seen in passing, sed scripts can be commented using `#` as in most other languages.

## Address specifications

This section lists all the ways you can select lines in sed.

### Select by number

One way is to simply specify the actual line number you want in a file. For example, delete the second line from a file:

```text
▶ gsed -i 2d FILE
```

### Select the last line

The last line is specified as `$`, as in Vim. Delete the last line in a file:

```text
▶ gsed -i '$d' FILE
```

### Select every second, third etc line

A GNU extension, for the sake of completeness, allows you to select consecutive lines. For example, print even numbered lines:

```text
▶ seq 10 | gsed -n 0~2p
2
4
6
8
10
```

Print odd numbered lines:

```text
▶ seq 10 | gsed -n 1~2p
1
3
5
7
9
```

Print every third line:

```text
▶ seq 10 | gsed -n 0~3p
3
6
9
```

### Select lines matching a pattern

To select lines matching a pattern, use `/regexp/`. For example, print lines beginning with 1:

```text
▶ seq 100 | sed -n '/^1/p'
1
10
11
12
13
14
15
16
17
18
19
100
```

To select by a pattern using a different delimiter, use `\%regexp%`, `\!regexp!`. For example, find all files in `/usr/local` matching `/usr/local/Cellar`:

```text
▶ find /usr/local | gsed -n '\!/usr/local/Cellar!p'
```

### Select lines by range

Lines can be selected by a range. For example, to print the first 3 lines of a stream:

```text
▶ seq 10 | sed -n 1,3p
1
2
3
```

To select from the 8th to end of file:

```text
▶ seq 10 | sed -n '8,$p'
8
9
10
```

To select between two patterns inclusive of the patterns:

```text
▶ seq 10 | sed -n /6/,/8/p
6
7
8
```

### Select from a line or pattern to an offset

In GNU sed only, it is also possible to select an offset. For example, to select the next 2 lines after a line matching a pattern:

```text
▶ seq 10 | gsed -n /5/,+2p
5
6
7
```

### Select from a line to the next line divisible by N

Not that I have any idea why a feature like this would exist, it is also possible to select from a line matching a pattern to a line number divisible by N. For example:

```text
▶ seq 30 | gsed -n /5/,~3p
5
6
15
16
17
18
25
26
27
```

### Negation !

Appending the `!` character to the end of an address specification (before the command letter) negates the sense of the match. That is, if the `!` character follows an address or an address range, then only lines which do not match the addresses will be selected.

For example, delete all lines other than the last one:

```text
▶ seq 5 | sed '$!d'
5
```

Exclude all lines between two patterns:

```text
▶ seq 6 | sed -n '/3/,/4/!p'
1
2
5
6
```

## Using the hold space

### The h, H (hold), g, G (get), and x (exchange) commands

If you have made it this far, congratulations! But be warned, beyond this point is seriously into the territory of where you should consider other programming languages, most of the time.

Recall that sed has two buffers, the pattern space and the hold space. Both are initially empty. The following commands manipulate the hold space:

|command|description|
|=======|===========|
|`h`|Replace the contents of the hold space with the contents of the pattern space.|
|`H`|Append a newline to the contents of the hold space, and then append the contents of the pattern space to that of the hold space.|
|`g`|Replace the contents of the pattern space with the contents of the hold space.|
|`G`|Append a newline to the contents of the pattern space, and then append the contents of the hold space to that of the pattern space.|
|`x`|Exchange the contents of the hold and pattern spaces.|

There is also more on the `H` and `G` commands in the [multiline](#multiline-techniques) section below.

### Example 1

This is a classic sed one-liner, to double-space a file. It's very simple:

```text
sed G
```

Because the hold space is initially empty, the `G` command appends a newline followed by the contents of hold buffer to pattern space. Thus, this one character script just adds a newline before every line.

### Example 2

One example is from the O'Reilly sed and AWK book. Suppose we have a file:

```text
1
2
11
22
111
222
```

And we want to reverse the order of the lines beginning with 1 and the lines beginning with 2. This script will do it:

```text
/1/{
  h  # if the line matches 1, replace the hold space with the pattern space.
  d  # delete, immediately begin next cycle.
}
/2/{
  G  # if it matches 2, append a newline then the hold space.
}
```

Testing:

```text
▶ data="1
2
11
22
111
222"
▶ gsed '/1/{h;d};/2/G' <<< $data
2
1
22
11
222
111
```

## Multiline techniques

### The D, G, H, N and P commands

Multiple lines can be processed using the capital letter commands `D`, `G`, `H`, `N`, `P`. These are all similar to their corresponding lowercase commands `d`, `g`, `h`, `n`, `p` except that they also respect newlines in the strings, allowing manipulation of multiline patterns in the pattern and hold spaces.

They operate as follows:

|command|description|
|=======|===========|
|`D`|deletes line from the pattern space until the first newline, and restarts the cycle.|
|`G`|appends line from the hold space to the pattern space, with a newline before it.|
|`H`|appends line from the pattern space to the hold space, with a newline before it.|
|`N`|appends line from the input file to the pattern space.|
|`P`|prints line from the pattern space until the first newline.|

### Example 1

Here is a contrived example from the docs to illustrate `N` and `D`:

```text
N   # Append a newline and the next line to the existing pattern space. If pattern space is 1, it
    #   becomes 1 + \n + next line.
l   # Print pattern space in an unambiguous form, i.e. reveal data and also newlines.
D   # Delete from the pattern space but only up until the first newline.
```

Testing:

```text
▶ seq 5 | gsed -n 'N;l;D'
1\n2$
2\n3$
3\n4$
4\n5$
```

### Example 2

Print paragraphs only if they match a pattern. A paragraph here is a sequence of lines that aren't empty. This script is a solution:

```text
/./{
  H       # Add a newline then the pattern space to the hold space.
  $!d     # If last line of file: delete and begin next cycle
          # Else: do nothing (continue processing below commands).
}
x         # Swap the pattern space and hold space.
/para2/b  # If the line matches /para2/: branch i.e. immediately begin next cycle.
d         # delete (empty) the pattern space so that nothing will print.
```

Testing:

```text
▶ data="para1
I am the
first para.

para2
I am the second
para.

para3
I am the third
para."
▶ gsed '/./{H; $!d}; x; /para2/b; d' <<< $data

para2
I am the second
para.
```

### Example 3

Delete preceding line and line matching a pattern:

```text
1{
  /PATTERN/d  # Special case needed for line 1. Delete if it contains PATTERN.
              # Also begins next cycle.
}
$!N         # Append next line. $!N stops exit w/o printing at EOF.
/PATTERN/d  # If pattern space contains PATTERN, d & begin next cycle.
P           # If we get to here, there is no PATTERN. Print to first newline.
D           # Delete to first newline.
```

## Branching and flow control

### The :, b, t and T commands

Seriously, don't do this. But if you really want to, read on.

The following table lists all of sed's flow control contructs:

|command|description|
|=======|===========|
|`: LABEL`|Specify the location of label for branch commands `b`, `t`, and `T`.|
|`d` (delete)|Deletes (clears) the current pattern space, and restart the program cycle without processing the rest of the commands and without printing the pattern space.|
|`D`|delete the contents of the pattern space up to the first newline, and restart the program cycle without processing the rest of the commands and without printing the pattern space.|
|`[ADDR]X`|Addresses and regular expressions can be used as an if/then conditional: If `[ADDR]` matches the current pattern space, execute the command(s). For example: The command `/^#/d` means: if the current pattern matches the regular expression `/^#/` (a line starting with a hash), then execute the `d` command: delete the line without printing it, and restart the program cycle immediately.|
|`[ADDR]{X;X;X}`||
|`/REGEXP/X`||
|`/REGEXP/{X;X;X}`||
|`b [LABEL]`|branch unconditionally, that is: always jump to a label, skipping or repeating other commands, without restarting a new cycle. Without a label, `b` is more like `break`; it just unconditionally starts a new cycle. Combined with an address, the branch can be conditionally executed on matched lines.|
|`t`|branch conditionally, that is: jump to a label, only if a `s///` command has succeeded since the last input line was read or another conditional branch was taken.|
|`T`|similar but opposite to the `t` command: branch only if there has been no successful substitutions since the last input line was read.|

Note well that some of the basic commands like `d` and `D` also have side effects that alter the program flow. This can be confusing at first. Notice also that an address specification is like an if/then and that `s///` in conjunction with `t` and `T` also can conditionally control flow.

But some examples will have to suffice.

### Example 1

This is a classic sed script that sets up a sliding window to emulate tail -5. It illustrates use of `N` and `D`, and also a loop using `:` and `b`.:

```
:a        # Define the label "a".
  N       # Append a newline and the next line to the existing pattern space. If pattern space is 1,
          #   it becomes 1 + \n + next line.
  1,5ba   # If still within the range 1,5: goto label a.
D         # Else: Delete from the pattern space but only up until the first newline.
```

In this way, the script maintains a stable buffer of the last 5 lines throughout all cycles. Also, and confusingly, the script depends on a GNU-specific feature of the `N` command, as documented [here](https://www.gnu.org/software/sed/manual/sed.html#Limitations):

> Most versions of sed exit without printing anything when the `N` command is issued on the last line of a file. GNU sed prints pattern space before exiting unless of course the `-n` command switch has been specified. This choice is by design.

Testing:

```text
▶ seq 200 | gsed ':a N; 1,5ba; D'
196
197
198
199
200
```

Note that the script doesn't work if POSIX-conforming behaviour is requested:

```text
▶ seq 200 | gsed --posix ':a N; 1,5ba; D'
```

(No output.)

### Example 2

Another classic example illustrating branching and the `P` command: Append a line to the previous one if it starts with "=":

```text
:a          # Define the label "a".
  $!N       # If not the last line of the file: Append a newline and the next line to the existing
            #   pattern space.
  s/\n=/ /  # Replace the string \n= with a space.
  ta        # If the previous s/// succeeded: goto a.
P           # Print from the beginning of pattern space to the first newline.
D           # Delete the bit that was just printed, i.e. from the beginning of pattern space to
            #   the first newline.
```

Testing:

```text
▶ data="To be, or not to be:
=that is the question:
Whether ‘tis nobler in
=the mind to suffer
The slings and arrows
=of outrageous fortune,
Or to take arms against
=a sea of troubles,
And by opposing end them?"
▶ gsed ':a; $!N; s/\n=/ /; ta; P; D' <<< $data
To be, or not to be: that is the question:
Whether ‘tis nobler in the mind to suffer
The slings and arrows of outrageous fortune,
Or to take arms against a sea of troubles,
And by opposing end them?
```

This code is further explained [here](https://catonmat.net/sed-one-liners-explained-part-one).

### Example 3

Implementing `s///3g` on BSD or other non-GNU sed. This illustrates use of `t` again.

```text
:a              # Define the label "a".
  s/foo/bar/3   # Replace the 3rd occurrence of foo with bar.
  ta            # Branch if and only if the previous s/// replaced something.
```

Testing:

```text
▶ sed -e :a -e s/foo/bar/3 -e ta <<< foofoofoofoofoo
foofoobarbarbar
```

Note that BSD sed, unlike GNU sed, requires each label to be line-break terminated thus the requirement to use `-e`.

This version also makes it easier to understand how it works:

```text
▶ sed -n -e :a -e s/foo/bar/3p -e ta <<< foofoofoofoofoo
foofoobarfoofoo
foofoobarbarfoo
foofoobarbarbar
```

## The GNU sed debugger

GNU sed has a debugger, activated by running the script with `--debug`.

### Example program

Suppose I want to debug this very simple script:

```text
▶ seq 5 | gsed '/2/{h;d};/4/x'
1
3
2
5
```

### Debugger output

With the debugger on, I see this:

```text
SED PROGRAM:
  /2/ {
    h
    d
  }
  /4/ {
    x
  }
INPUT:   'STDIN' line 1
PATTERN: 1
COMMAND: /2/ {
COMMAND: }
COMMAND: /4/ {
COMMAND: }
END-OF-CYCLE:
1
INPUT:   'STDIN' line 2
PATTERN: 2
COMMAND: /2/ {
COMMAND:   h
HOLD:    2
COMMAND:   d
END-OF-CYCLE:
INPUT:   'STDIN' line 3
PATTERN: 3
COMMAND:   /2/ {
COMMAND:   }
COMMAND:   /4/ {
COMMAND:   }
END-OF-CYCLE:
3
INPUT:   'STDIN' line 4
PATTERN: 4
COMMAND:   /2/ {
COMMAND:   }
COMMAND:   /4/ {
COMMAND:     x
PATTERN: 2
HOLD:    4
COMMAND:   }
END-OF-CYCLE:
2
INPUT:   'STDIN' line 5
PATTERN: 5
COMMAND:   /2/ {
COMMAND:   }
COMMAND:   /4/ {
COMMAND:   }
END-OF-CYCLE:
5
```

As can be seen, the debugger tells us everything that happens in each cycle.

At the beginning, we are told what the sed program itself is:

```text
SED PROGRAM:
  /2/ {
    h
    d
  }
  /4/ {
    x
    p
  }
```

### Cycle 1

In cycle 1 (i.e. the first line):

```text
INPUT:   'STDIN' line 1
PATTERN: 1
COMMAND: /2/ {
COMMAND: }
COMMAND: /4/ {
COMMAND: }
END-OF-CYCLE:
1
```

We have:

- `INPUT:   'STDIN' line 1` tells us the file name (`STDIN`) and line number.
- `PATTERN: 1` tells us the (new) contents of the pattern space.
- `COMMAND: /2/ {` is a regexp that does not match the pattern space.
- `COMMAND: }` sed has moved ahead to find the closing brace.
- `COMMAND: /4/ {` is another regexp that does not match the pattern space.
- `COMMAND: }` sed has again moved ahead to find the closing brace.
- `END-OF-CYCLE:` shows us what actually gets printed (if anything) at the end of the cycle.
- `1` is the actual output from the sed script.

### Cycle 2

Cycle 2 is more interesting:

```text
INPUT:   'STDIN' line 2
PATTERN: 2
COMMAND: /2/ {
COMMAND:   h
HOLD:    2
COMMAND:   d
END-OF-CYCLE:
```

This time:

- `INPUT:   'STDIN' line 2` tells us the file name (`STDIN`) and line number again.
- `PATTERN: 2` again tells us the new contents of the pattern space.
- `COMMAND: /2/ {` is a command that this time does match the pattern space.
- `COMMAND:   h` is the hold command.
- `HOLD:    2` shows us the new contents of the hold space.
- `COMMAND:   d` deletes the pattern space - and branches to immediately end this cycle.
- `END-OF-CYCLE:` shows us nothing being printed at the end of this cycle.

### Cycle 3

Cycle 3 is more or less the same as cycle 1:

```text
INPUT:   'STDIN' line 4
PATTERN: 4
COMMAND:   /2/ {
COMMAND:   }
COMMAND:   /4/ {
COMMAND:     x
PATTERN: 2
HOLD:    4
COMMAND:   }
END-OF-CYCLE:
2
```

### Cycle 4

Cycle 4 is also interesting.

- `INPUT:   'STDIN' line 4` we are on line 4.
- `PATTERN: 4` the pattern space is now 4.
- `COMMAND:   /2/ {` a command that does not match.
- `COMMAND:   }` closing brace.
- `COMMAND:   /4/ {` a command that does match the pattern space.
- `COMMAND:     x` exchanges pattern space and hold space:
- `PATTERN: 2` the new pattern space.
- `HOLD:    4` the new hold space.
- `COMMAND:   }` closing brace.
- `END-OF-CYCLE:` shows us what is printed at the end of the cycle.
- `2`

### Cycle 5

Cycle 5 is more or less the same as cycles 1 and 3:

```text
INPUT:   'STDIN' line 5
PATTERN: 5
COMMAND:   /2/ {
COMMAND:   }
COMMAND:   /4/ {
COMMAND:   }
END-OF-CYCLE:
5
```

## Exit status

An exit status of zero indicates success, and a nonzero value indicates failure. GNU sed returns the following exit status error values:

|exit status|description|
|===========|===========|
|`0`|Successful completion.|
|`1`|Invalid command, invalid syntax, invalid regular expression or a GNU sed extension command used with `--posix`.|
|`2`|One or more of the input file specified on the command line could not be opened (e.g. if a file is not found, or read permission is denied). Processing continued with other files.|
|`4`|An I/O error, or a serious processing error during runtime, GNU sed aborted immediately.|

Also, the `q` and `Q` commands, via a GNU extension, can be used to exit with a custom exit status:

```text
▶ seq 10 | gsed Q42 ; echo $?
42
```

## Summary

This completes an almost complete overview of the GNU sed programming language. I have covered most of sed's features and illustrated them with examples, with the exception of regular expressions, which I regarded as documented elsewhere and not strictly speaking a feature of the sed language. I have omitted some of the command line options, undocumented behaviours, some of the most advanced commands, and my treatment of branching and flow control is cursory.

Please let me know if you find any errors or have any suggestions for improvement!

## See also

- [GNU sed manual](www.gnu.org/software/sed/manual/sed.html).
- [sed & AWK, 2nd ed](https://docstore.mik.ua/orelly/unix2.1/sedawk/index.htm) O'Reilly.
- [sed FAQ](http://sed.sourceforge.net/sedfaq.html).
- [Sed One-liners Explained, Part I: File Spacing, Numbering and Text Conversion and Substitution](https://catonmat.net/sed-one-liners-explained-part-one).
- [Useful One-line Scripts for Sed](http://sed.sourceforge.net/sed1line.txt).
- [Sed - An Introduction and Tutorial by Bruce Barnett](http://www.grymoire.com/Unix/Sed.html) (similar scope to the present post).

<sup>1</sup> Be aware that I am only familiar with the BSD version of sed that ships on Mac OS X, and GNU sed 4.6. All code in this post is tested on one of these two implementations.<br>
<sup>2</sup> For example,

```text
▶ echo "ABCDEFGHIJKLMNOPQRSTUVWXYZ" | perl -pe 's/(.)(.)(.)(.)(.)(.)(.)(.)(.)(.)(.).*/${10}/'
J
```
