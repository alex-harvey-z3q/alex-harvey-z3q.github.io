---
layout: post
title: "How to write an AWS CLI script, Part I: Patterns"
date: 2021-03-15
author: Alex Harvey
tags: bash aws shunit2
---

This article presents a pattern for writing an testing AWS CLI scripts.

- ToC
{:toc}

## Introduction

I have now written many AWS CLI scripts in Bash, and have, over time, adapted programming patterns that, I think, all AWS CLI scripts _should_ follow. This post documents my patterns and I hope that others will also adopt them.

I also hope to show that Bash is a fine language for automating AWS via the AWS CLI. I think there is misplaced prejudice against Bash in favour of Python and Boto3, Golang, and so on. There is a sense that these others are "real" programming languages, despite that they complicate the development and testing in some ways, and, I think, often, for no real gain.

If operators are going to use the AWS CLI to communicate with AWS, then why write automation in a different language?

In the first part of this blog series, I introduce _all_ of the Bash programming patterns needed to write a complex AWS CLI shell script. Along the way I present two real life examples. And in Part II, I will look at how to unit test these scripts using shunit2.

## Patterns

### Structure of a script

Before getting into the nuts and bolts of Bash programming techniques, I want to firstly look at how to organise a script. I have found that every script _should_ have the following five or six sections:

- a `usage` function
- a `get_opts` function (rarely ommitted)
- a `validate_opts` function (sometimes omitted)
- functions that implement the script's logic
- a `main` function
- and a `guard` clause.

In the following subsections, I explain what all of these are, and why we need them.

#### `usage` function

Every program or script should have a usage function as a bare minimum level of documentation. The usage function tells or reminds the user - who is often also the author! - how to actually use the script. It says what the script does, what its command line arguments are, and it halts further execution when it is called.

The Bash special variable `$0` should be used for the script name. For example:

```bash
usage() {
  echo "Usage: $0 [-h] [-s STACK_NAME]"
  exit 1
}
```

#### `get_opts` function

In order to handle command line arguments, it is very likely that a script also needs a `get_opts` function, whose purpose is to call the Bash built-in `getops`. In the case of a very simple script that does not accept arguments or perhaps accepts just a single argument, this function may not be required. But most of the time, it is.

##### Example calling getopts

The `getopts` command should be used most of the time unless the script is very simple. Here is an example of a `get_opts` function that calls `getopts`:

```bash
get_opts() {
  local opt OPTARG OPTIND
  while getopts "hs:" opt ; do
    case "$opt" in
      h) usage ;;
      s) stack_name="$OPTARG" ;;
      \?) echo "ERROR: Invalid option -$OPTARG"
          usage ;;
    esac
  done
  shift $((OPTIND-1))
}
```

Notice that I have localised the `$OPTARG` and `$OPTIND` variables. This is important, aside from being in general good style. Failure to localise these can lead to odd behaviour during unit testing. More on that later. For now, just remember that it is good style to localise all local variables, and especially important to localise these ones.

How to use `getopts` is of course beyond the scope of this article, but see [here](https://sookocheff.com/post/bash/parsing-bash-script-arguments-with-shopts/) for a good tutorial on `getopts`.

##### Example not calling getopts

Occasionally, use of the `getops` command is overkill, and you may wish to implement your `get_opts` function without it. Here is an example that rewrites the above without `getopts`:

```bash
get_opts() {
  [ "$1" == "-h" ] && usage

  if [ "$1" == "-s" ] ; then
    stack_name="$2"
    return
  fi

  usage
}
```

##### Calling the get_opts function

Notice that the `getopts` built-in operates on the script's special `$@` variable. In order for this to be available inside a Bash function, you need to pass it around, like this:

```bash
get_opts "$@"
```

This line would normally be in the `main` function. More below.

#### `validate_opts` function

A safe, well written script usually also has some input validation - sanity checking to ensure that the inputs passed into it are safe or sane, and helpful feedback to the user if they are not. If the input validation requirement is very simple, the validation logic could be done inside the `get_opts` function. But often, it makes sense to do this in a separate function. Here is an example:

```bash
validate_opts() {
  if [ -z "$stack_name" ] ; then
    echo "You must pass a stack_name with -s"
    usage
  fi
}
```

#### section to implement logic

Most of your script will be actual implementation. After defining a `usage`, `get_opts` and `validate_opts` function, the middle section of an AWS CLI script is made up of the functions that actually do the work. These are expected to be either called by other functions or by the `main` function. See the next subsection.

#### `main` function

Every script, for reasons of consistency, testability and readability, should have a `main` function. The `main` function should present the high level logic of the program in a human-readable form. Of course, the `main` function will only be readable if you have given your functions good names, so make sure you do give them good names, and keep in mind the readability of the `main` function when naming things. For example:

```bash
main() {
  get_opts "$@"
  validate_opts
  describe_instances_in_stack
}
```

It is hopefully clear, without any further implementation detail, that this is the `main` function of a script that runs `describe-instances` on all the instances in a CloudFormation stack.

#### guard clause

Finally, there is one more section in a script that is often overlooked, but also important. Every script should have a [guard clause](http://wiki.c2.com/?GuardClause). A guard clause - in general - is a piece of code that prevents code from actually running. In our case, a guard clause is used to prevent the `main` function from running if the script is sourced into the running shell, as opposed to executed. This is needed to make the script and its functions testable.

The guard clause always looks like this:

```bash
if [ "$0" == "${BASH_SOURCE[0]}" ] ; then
  main "$@"
fi
```

Notice here once again that we pass `$@` to `main` so that `main` can then pass it to `get_opts`.

#### all together

Putting all of this together, here is a full script example. In this example, the script lists all EC2 instances that are inside a CloudFormation stack.

```bash
#/usr/bin/env bash

usage() {
  echo "Usage: $0 [-h] [-s STACK_NAME]"
  exit 1
}

get_opts() {
  local opt OPTARG OPTIND
  while getopts "hvs:" opt ; do
    case "$opt" in
      h) usage ;;
      s) stack_name="$OPTARG" ;;
      \?) echo "ERROR: Invalid option -$OPTARG"
          usage ;;
    esac
  done
  shift $((OPTIND-1))
}

validate_opts() {
  if [ -z "$stack_name" ] ; then
    echo "You must pass a stack_name with -s"
    usage
  fi
}

list_stack_resources() {
  local resource_type="AWS::EC2::Instance"
  local query=\
'StackResourceSummaries[?ResourceType==`'"$resource_type"'`].PhysicalResourceId'

  aws cloudformation list-stack-resources \
    --stack-name "$stack_name" \
    --query "$query"
}

describe_instances_in_stack() {
  local instance_id
  list_stack_resources | while read -r instance_id ; do
    aws ec2 describe-instances --instance-id \
      "$instance_id" --output "table"
  done
}

main() {
  export AWS_DEFAULT_OUTPUT="text"
  get_opts "$@"
  validate_opts
  describe_instances_in_stack
}

if [ "$0" == "${BASH_SOURCE[0]}" ] ; then
  main "$@"
fi
```

### Default output

To avoid sending `--output text` to commands in an AWS CLI script, as shown in the example above, it makes sense to set the environment variable `AWS_DEFAULT_OUTPUT`. This can be done in the `main` function:

```bash
main() {
  export AWS_DEFAULT_OUTPUT="text"
  get_opts "$@"
  validate_opts
  describe_instances_in_stack
}
```

### Globals and locals

Note that Bash functions cannot return values, so it is proper to use global variables to share data throughout the script. But variables that are internal to a function should be localised using `local`. Here is a function that correctly mixes globals and locals:

```bash
describe_key_pair() {
  local filter="Name=key-name,Values=$key_name"
  aws ec2 describe-key-pairs --filters "$filter"
}
```

Here, `$key_name` is a global variable - and also the input to this function - whereas `$filter` is a local variable. The global is expected to be defined elsewhere in the program before this function is called, whereas `$filter` exists only within the scope of this particular function.

#### Testing a function with globals

To test a function that depends on a global variable, do this:

```text
▶ key_name=default ; describe_key_pair
{
  "KeyPairs": [
    {
      "KeyPairId": "key-0607ce5fb02240a92",
      "KeyFingerprint": "70:e2:fa:b1:97:e3:68:5f:6a:63:93:17:09:5a:43:29:60:94:53:ab",
      "KeyName": "default",
      "Tags": []
    }
  ]
}
```

### Calling the AWS CLI

Simple calls to the AWS CLI that wrap a single AWS CLI subcommand should be named after the subcommand. The do-one-thing-well principle suggests to me that there should be one Bash function for every call to the AWS CLI. A very simple example might be:

```bash
describe_instances() {
  aws ec2 describe-instances
}
```

### Filters, queries and jp

A treatment of AWS CLI filters and its JMESpath query language is beyond the scope of this article. However, it needs to be said that writing AWS CLI scripts requires you to fully understand both of these topics. The AWS documentation on this [here](https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-filter.html) is quite good, and there are also many good JMESpath tutorials out there. 

Note that testing your JMESpath queries can be done using the [`jp`](https://github.com/jmespath/jp) command line utility. I recommend installing that and becoming familiar with it.

### Reading a single value from AWS CLI command output

Often, you will need to set variables in your script based on responses from AWS CLI commands. Suppose you have an EC2 key pair name, and you need the key pair ID. The AWS CLI returns JSON that looks like this:

```json
{
  "KeyPairs": [
    {
      "KeyPairId": "key-09e9f9a9f6632d54e",
      "KeyFingerprint": "af:ef:61:07:42:f8:33:0a:e4:d6:89:cb:2b:bb:3a:2e:21:fb:16:19",
      "KeyName": "alex",
      "Tags": []
    },
    {
      "KeyPairId": "key-0607ce5fb02240a92",
      "KeyFingerprint": "70:e2:fa:b1:97:e3:68:5f:6a:63:93:17:09:5a:43:29:60:94:53:ab",
      "KeyName": "default",
      "Tags": []
    }
  ]
}
```

If I want the key pair ID given the key name, here are two ways of doing that:

#### Pattern A - using read -r

The `read -r` command is always needed (see below) to read more than one value on a single line. But it also can be used to read just one value, as here:

```bash
get_key_pair_id() {
  read -r key_pair_id <<< "$(
    aws ec2 describe-key-pairs
      --filters "Name=key-name,Values=$key_name" \
      --query "KeyPairs[].KeyPairId"
  )"
}
```

#### Pattern B - use variable assignment

The second way to write this same function is:

```bash
get_key_pair_id() {
  key_pair_id="$(
    aws ec2 describe-key-pairs \
      --filters "Name=key-name,Values=$key_name" \
      --query "KeyPairs[].KeyPairId"
  )"
}
```

Which one should you use? This second pattern is probably more familiar to Bash users, however the first is more flexiable, because, as mentioned, it can also be used to read more than one value at a time. Perhaps it makes sense to use the first pattern if you will not need the second pattern at all in your script, but use the second pattern for consistency if you need both.

### Reading multiple values from AWS CLI command

But what if you need to read both the KeyPairId _and_ the fingerprint? Many a naive Bash programmer might do something like this:

```bash
get_key_details() {
  key_pair_id="$(aws ec2 describe-key-pairs --query "KeyPairs[].KeyPairId" ...)"
  key_fingerprint="$(aws ec2 describe-key-pairs --query "KeyPairs[].KeyFingerprint" ...)"
}
```

But that is both expensive and messy. It is not necessary to call the same command twice to read two values. Instead, we do this:

```bash
get_key_details() {
  read -r key_pair_id key_fingerprint <<< "$(
    aws ec2 describe-key-pairs \
      --filters "Name=key-name,Values=$key_name" \
      --query "KeyPairs[].[KeyPairId, KeyFingerprint]"
  )"
}
```

This combines 2 patterns that need to memorised:

- Reading multiple variables in a single command in Bash, e.g. see Stack Overflow [here](https://stackoverflow.com/a/1952480/3787051).
- Multi-select lists in JMESpath, e.g. docs [here](https://jmespath.org/examples.html#filters-and-multiselect-lists).

### Iteration

#### Pattern A - using while loops

Suppose I have these additional key pairs with the word "runner" in them and I want to delete them all:

```json
{
  "KeyPairs": [
    {
      "KeyPairId": "key-09e9f9a9f6632d54e",
      "KeyFingerprint": "af:ef:61:07:42:f8:33:0a:e4:d6:89:cb:2b:bb:3a:2e:21:fb:16:19",
      "KeyName": "alex",
      "Tags": []
    },
    {
      "KeyPairId": "key-0607ce5fb02240a92",
      "KeyFingerprint": "70:e2:fa:b1:97:e3:68:5f:6a:63:93:17:09:5a:43:29:60:94:53:ab",
      "KeyName": "default",
      "Tags": []
    },
    {
      "KeyPairId": "key-068c8e5fa546a4ddc",
      "KeyFingerprint": "2a:a9:63:3a:e5:eb:f6:81:75:f2:86:90:75:6c:07:8a",
      "KeyName": "runner-3szwaqc8-runner-1571372115-8810afca",
      "Tags": []
    },
    {
      "KeyPairId": "key-08db2361f992f0aef",
      "KeyFingerprint": "2f:c0:e7:6c:4c:68:2a:12:21:07:c2:3a:d7:c0:df:0f",
      "KeyName": "runner-devbsxdv-runner-1571318225-c715842e",
      "Tags": []
    }
  ]
}
```

I will need to _iterate_ through the list of key pairs and delete all the ones that match "runner". But first, we need to know how to iterate. Let us begin by creating a function that performs the query on key name. Here is that function:

```bash
describe_key_pairs() {
  local filter="*runner*"
  aws ec2 describe-key-pairs \
    --filters "Name=key-name,Values=$filter" \
    --query "KeyPairs[].[KeyPairId]"
}
```

This returns:

```text
▶ describe_key_pairs
key-068c8e5fa546a4ddc
key-08db2361f992f0aef
```

Notice this time that the returned values are on separate lines. I have achieved this by coercing the key pair ID to a list in the query (see where I have `[KeyPairId]`). When converted to the text output format, these then appear one per line.

Next, I need a function that actually iterates. In my example, this will be the delete function. Here it is:

```bash
delete_key_pairs() {
  local key_pair_id
  describe_key_pairs | \
  while read -r key_pair_id ; do
    aws ec2 delete-key-pair \
      --key-pair-id "$key_pair_id"
  done
}
```

#### Pattern B - using arrays and for loops

If I wanted to instead use an array and for loops for my iteration - say I need to keep these key pairs in the array for some reason for later - then I can refactor to do that this way:

```bash
describe_key_pairs() {
  local filter="*runner*"
  aws ec2 describe-key-pairs \
    --filters "Name=key-name,Values=$filter" \
    --query "KeyPairs[].KeyPairId"
}

delete_key_pairs() {
  local key_pair_ids key_pair_id
  read -r -a key_pair_ids <<< "$(describe_key_pairs)"
  for key_pair_id in "${key_pair_ids[@]}" ; do
    aws ec2 delete-key-pair \
      --key-pair-id "$key_pair_id"
  done
}
```

### Complete example

By way of providing a complete example, let's put all of this together in a script that deletes key pairs that match a pattern supplied by the user.

```bash
#!/usr/bin/env bash

usage() {
  echo "Usage: $0 [-h] PATTERN"
  exit 1
}

get_opts() {
  [ "$1" == "-h" ] && usage
  pattern="$1"
}

describe_key_pairs() {
  local filter="*$pattern*"
  aws ec2 describe-key-pairs \
    --filters "Name=key-name,Values=$filter" \
    --query "KeyPairs[].[KeyPairId]"
}

delete_key_pairs() {
  local key_pair_id
  describe_key_pairs | \
  while read -r key_pair_id ; do
    aws ec2 delete-key-pair \
      --key-pair-id "$key_pair_id"
  done
}

main() {
  export AWS_DEFAULT_OUTPUT="text"
  get_opts "$@"
  delete_key_pairs
}

if [ "$0" == "${BASH_SOURCE[0]}" ] ; then
  main "$@"
fi
```

## Concluding remarks

So, in this post, I have documented _all_ of the Bash programming patterns that, in my opinion, are needed to write a useful AWS CLI script. I have also, in the course of presenting the patterns, shown them in the context of two complete examples of AWS CLI scripts. Stay with me for the second part, where I'll show how to unit test these scripts.
