---
layout: post
title: "Unit Testing a Bash Script with shUnit2"
date: 2017-07-07
author: Alex Harvey
tags: bash shunit2
---

According to the [docs](http://ssb.stsci.edu/testing/shunit2/shunit2.html), shUnit2:

> ...is a xUnit unit test framework for Bourne based shell scripts, and it is designed to work in a similar manner to JUnit, PyUnit, etc.. If you have ever had the desire to write a unit test for a shell script, shUnit2 can do the job.

In this post, I introduce the subject of unit testing shell scripts using Kate Ward’s shUnit2 unit testing framework, and show how I have used it to solve some testing problems.

{:toc}

## Installing shUnit2

### Install on a Mac

To install on a Macbook, run:

```text
▶ brew install shunit2
```

The following files are installed:

```text
▶ find /usr/local/bin/shunit2 /usr/local/Cellar/shunit2
/usr/local/bin/shunit2
/usr/local/Cellar/shunit2
/usr/local/Cellar/shunit2/2.1.6
/usr/local/Cellar/shunit2/2.1.6/.brew
/usr/local/Cellar/shunit2/2.1.6/.brew/shunit2.rb
/usr/local/Cellar/shunit2/2.1.6/bin
/usr/local/Cellar/shunit2/2.1.6/bin/shunit2
/usr/local/Cellar/shunit2/2.1.6/INSTALL_RECEIPT.json
```

### Install on CentOS/RHEL

Installing on an RPM-based system like RHEL causes some additional useful files to be installed:

```text
# yum -y install shunit2
```

And:

```text
# rpm -ql shunit2
/usr/share/doc/shunit2-2.1.6
/usr/share/doc/shunit2-2.1.6/CHANGES-2.1.txt
/usr/share/doc/shunit2-2.1.6/LGPL-2.1
/usr/share/doc/shunit2-2.1.6/README.txt
/usr/share/doc/shunit2-2.1.6/RELEASE_NOTES-2.1.6.txt
/usr/share/doc/shunit2-2.1.6/TODO.txt
/usr/share/doc/shunit2-2.1.6/coding_standards.txt
/usr/share/doc/shunit2-2.1.6/contributors.txt
/usr/share/doc/shunit2-2.1.6/design_doc.txt
/usr/share/doc/shunit2-2.1.6/examples
/usr/share/doc/shunit2-2.1.6/examples/equality_test.sh
/usr/share/doc/shunit2-2.1.6/examples/lineno_test.sh
/usr/share/doc/shunit2-2.1.6/examples/math.inc
/usr/share/doc/shunit2-2.1.6/examples/math_test.sh
/usr/share/doc/shunit2-2.1.6/examples/mkdir_test.sh
/usr/share/doc/shunit2-2.1.6/examples/party_test.sh
/usr/share/doc/shunit2-2.1.6/shunit2.txt
/usr/share/shunit2
/usr/share/shunit2/shunit2
/usr/share/shunit2/shunit2_test_helpers
```

Files of note include:

- /usr/share/shunit2/shunit2: The 1,048 line /bin/sh script itself.
- /usr/share/shunit2/shunit2_test_helpers: 177 lines of helper functions. You probably do not need these but it is useful to know they are here.
- /usr/share/doc/shunit2-2.1.6/shunit2.txt: A copy of the documentation.
- /usr/share/doc/shunit2-2.1.6/examples: A directory containing some example unit tests to help you get started.

The examples bundled in the RPM are worth looking at – in fact, all of the examples are easy to understand and I recommend reviewing each of them, but I will begin by looking at the last one, party_test.sh.

### Getting shUnit2 2.1.7-pre and my patch

Some of the examples below require a patch that I have written which is, at the time of writing, not merged. Until it is merged, this patched version can be obtained from [here](https://github.com/alex-harvey-z3q/shunit2/tree/Issue_54/protect_internal_commands_from_stubbing).

If that patch has been merged, then version 2.1.7-pre can be obtained from [here](https://github.com/kward/shunit2).

## Our first test – Party like it’s 1999

```bash
#! /bin/sh
# file: examples/party_test.sh

testEquality()
{
  assertEquals 1 1
}

testPartyLikeItIs1999()
{
  year=`date '+%Y'`
  assertEquals "It's not 1999 :-(" \
      '1999' "${year}"
}

# load shunit2
. /usr/share/shunit2/shunit2
```

It is worth thinking about what it is doing before moving on. I proceed immediately to run the test:

```text
▶ bash /usr/share/doc/shunit2-2.1.6/examples/party_test.sh
testEquality
testPartyLikeItIs1999
ASSERT:It's not 1999 :-( expected:<1999> but was:<2017>

Ran 2 tests.

FAILED (failures=1)
```

So 1 still equals 1 and it’s not 1999.

## Anatomy of a test script

At a high level, the scripts that test your shell scripts can be divided into three sections:

- A set up section
- A test cases section
- The call to the shunit2 test runner

In the set up section, we might defind setUp and tearDown functions, or define stubs or mocks. (The example testPartyLikeItIs1999 has no set up section.) In the test cases section, we define functions that start with test; these are interpreted by shUnit2 as test cases. And then finally, the call to the shunit2 test runner is just one line, which is always: `. shunit2`.

In the test cases section, we typically source the script-under-test into the current shell.

## Our second example – prips

### The prips.sh shell script

This second example tests a function I wrote to emulate the Ubuntu prips command on CentOS and Red Hat Linux. The code for this example is available here for anyone who wants to play with it.

The shell code in question is:

```bash
#!/usr/bin/env bash

cidr="$1"

usage() {
  [ ! -z "$1" ] && echo $1
  cat <<EOF
Print all IPs in a CIDR range, similar to the Ubuntu prips utility.
This script assumes that the Red Hat version of ipcalc is available.
Usage: $0 <cidr> [-h]
Example: $0 192.168.0.3/28
EOF
  exit 1
}
[ -h == "$1" ] && usage
[ ! -z "$2" ] && usage 'You may only pass one CIDR'
[ -z "$cidr" ] && usage 'You must pass a CIDR'
echo $cidr | egrep -q "^(?:[0-9]+\.){3}[0-9]+/[0-9]+$" || \
  usage "$cidr is not a valid CIDR"

# range is bounded by network (-n) & broadcast (-b) addresses.
lo=$(ipcalc -n $cidr | cut -f2 -d=)
hi=$(ipcalc -b $cidr | cut -f2 -d=)

IFS=. read a b c d <<< "$lo"
IFS=. read e f g h <<< "$hi"

eval "echo {$a..$e}.{$b..$f}.{$c..$g}.{$d..$h}"
```

In this example I introduce stubbing of system commands in order to test this script on Mac OS X.

The problem here is that the ipcalc command is a completely different program on Mac OS X, relative to the one on CentOS and Red Hat linux. But I do my development on Mac OS X, and I therefore need to be able to run my tests on that platform.

### About the eval statement

In case the reader is confused about what the eval statement does, that code is logically equivalent to four nested for loops:

```bash
#eval "echo {$a..$e}.{$b..$f}.{$c..$g}.{$d..$h}"
result=''
for ((i=$a; i<=$e; i++)); do
  for ((j=$b; j<=$f; j++)); do
    for ((k=$c; k<=$g; k++)); do
      for ((l=$d; l<=$h; l++)); do
        result+=" $i.$j.$k.$l"
      done
    done
  done
done
echo $result
```

But it is much faster and more concise to use the eval and expansion. I will use my tests to prove this too.

## The test cases

### White-box testing

The objective of all unit testing is to prove that code is correct. Here, I want to ensure that every logical pathway through the code is tested (“branch coverage”), and that every statement in the code is covered (“statement coverage”). I also want test for a representative set of input data to ensure that all realistic cases have been considered (“data flow coverage”).

### The code

Hopefully the code speaks for itself, so here I introduce the tests I have written to test this code:

```bash
#!/usr/bin/env bash

# Fake the output of the ipcalc.
ipcalc() {
  case "$*" in
  "-n 192.168.0.2/28")
    echo NETWORK=192.168.0.0
    ;;
  "-b 192.168.0.2/28")
    echo BROADCAST=192.168.0.15
    ;;
  "-n 10.45.0.0/16")
    echo NETWORK=10.45.0.0
    ;;
  "-b 10.45.0.0/16")
    echo BROADCAST=10.45.255.255
  esac
}

test_minus_h() {
  first_line=$(. ./prips.sh -h | head -1)
  assertEquals "Print all IPs in a CIDR range, similar to the Ubuntu \
prips utility." "$first_line"
}

test_missing_args() {
  first_line=$(. ./prips.sh | head -1)
  assertEquals 'You must pass a CIDR' "$first_line"
}

test_too_many_args() {
  first_line=$(. ./prips.sh 192.168.0.2/28 192.168.0.2/30 | head -1)
  assertEquals 'You may only pass one CIDR' "$first_line"
}

test_bad_input() {
  first_line=$(. ./prips.sh bad_input | head -1)
  assertEquals 'bad_input is not a valid CIDR' "$first_line"
}

test_a_little_cidr() {
  response=$(. ./prips.sh 192.168.0.2/28)
  expected="192.168.0.0 192.168.0.1 192.168.0.2 192.168.0.3 192.168.0.4 \
192.168.0.5 192.168.0.6 192.168.0.7 192.168.0.8 192.168.0.9 192.168.0.10 \
192.168.0.11 192.168.0.12 192.168.0.13 192.168.0.14 192.168.0.15"
  assertEquals "$expected" "$response"
}

test_a_big_cidr() {
  number_of_ips=$(. ./prips.sh 10.45.0.0/16 | wc -w)
  assertEquals 65536 "$number_of_ips"
}

. shunit2
```

### Stubbing the ipcalc command

Quoting Martin Fowler (who quotes Gerard Meszaros), “stubs”:

> provide canned answers to calls made during the test, usually not responding at all to anything outside what’s programmed in for the test.

What I like so much about unit testing in Bash with shUnit2 is just how easy it is to create stubs. Whether we need to stub an external system command like ipcalc or a shell built-in like read – we can stub it by defining a shell function in the tests script, which will take the place of the real command when called; this is a basic feature of the shell.

(Of course, we must be careful that shUnit2 itself does not try to use this command/built-in; more on that below.)

So, here, I have stubbed the Linux ipcalc command, and programmed it to respond with canned response to expected inputs:

```bash
ipcalc() {
  case "$*" in
  "-n 192.168.0.2/28")
    echo NETWORK=192.168.0.0
    ;;
  "-b 192.168.0.2/28")
    echo BROADCAST=192.168.0.15
    ;;
  "-n 10.45.0.0/16")
    echo NETWORK=10.45.0.0
    ;;
  "-b 10.45.0.0/16")
    echo BROADCAST=10.45.255.255
  esac
}
```

Now, when my tests execute, instead of the script failing, because Mac OS X is not supported, the script gets to “think” it’s running on a Linux platform, because the ipcalc command will return Linux output when called.

### The assertEquals function

shUnit2 provides a few assert functions, but assertEquals is the one most often required:

```text
assertEquals [message] expected actual
```

Asserts that expected and actual are equal to one another. The expected and actual values can be either strings or integer values as both will be treated as strings. The message is optional, and must be quoted.

See the rest of the functions [here](http://ssb.stsci.edu/testing/shunit2/shunit2.html#asserts) in the docs.

### Running the tests

```text
▶ bash examples/test_prips.sh
test_minus_h
test_missing_args
test_too_many_args
test_bad_input
test_a_little_cidr
test_a_big_cidr

Ran 6 tests.

OK
```

Now, everything is passing. But what would happen if I removed the stub? Let’s see:

```text
▶ bash examples/test_prips.sh
test_minus_h
test_missing_args
test_too_many_args
test_bad_input
test_a_little_cidr
ASSERT:expected:<192.168.0.0 192.168.0.1 192.168.0.2 192.168.0.3 192.168.0.4 192.168.0.5 192.168.0.6 192.168.0.7 192.168.0.8 192.168.0.9 192.168.0.10 192.168.0.11 192.168.0.12 192.168.0.13 192.168.0.14 192.168.0.15> but was:<{Address: 192..Address: 192}.168.0.{2 11000000.10101000.00000000.0000 0010..2 }>
test_a_big_cidr
ASSERT:expected:<65536> but was:<6>

Ran 6 tests.

FAILED (failures=2)
```

Yep, that looks about right, because the ipcalc command on Mac OS X is an entirely different program to the one on Linux.

Now what if I want to test that the nested for loop implementation is also correct? I refactor the prips.sh script and run the tests again:

```text
▶ time bash examples/test_prips.sh
test_minus_h
test_missing_args
test_too_many_args
test_bad_input
test_a_little_cidr
test_a_big_cidr

Ran 6 tests.

OK

real    0m3.888s
user    0m3.656s
sys     0m0.253s
```

I timed it, too, to show the test_a_big_cidr (actually a /16 CIDR) took ~ 4 seconds to be calculated. Using the original code I get:

```text
real    0m0.343s
user    0m0.250s
sys     0m0.114s
```

_To be continued..._
