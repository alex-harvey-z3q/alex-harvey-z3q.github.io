---
layout: post
title: "Introducing programmatic editing of Hiera YAML files"
date: 2016-09-11
author: Alex Harvey
tags: puppet hiera ruamel
---

* Table of contents
{:toc}

## Introduction
If you have ever maintained a complicated, multi-team deployment of Hiera, you have probably seen data keys repeated in flagrant violation of the Don’t Repeat Yourself principle.

To an extent, this is avoidable. It is possible to declare variables in Hiera and look them up from elsewhere in Hiera by calling the hiera function from within Hiera. It is also possible to define [aliases](https://docs.puppet.com/hiera/3.2/variables.html#the-alias-lookup-function) in order to look up complex data from elsewhere within Hiera.

Meanwhile, the hiera_hash function can eliminate the need to repeat Hash keys at multiple levels of the hierarchy, although Puppet 3’s automatic parameter lookup will not return merged hash lookups.

On the other hand, many Puppet users don’t know about these features, and even when they do, tight project deadlines tempt the best of us to take shortcuts.

## Bulk updating of Hiera data
The problem that arises can be stated as follows: Given many Hiera files, possibly in separate Git repos and maintained in separate teams, how would you update a similar block of Hiera data in all of these files?

I spent several hours on a Friday afternoon writing a simple Ruby script to double-check that I’d manually updated ~ 10 YAML files with changes to what were essentially the same data keys, and I wondered if there is a better way.

## Python and ruamel.yaml
To my surprise, I discovered that it is simply impossible to programmatically update human-edited YAML files in Ruby because its parser cannot preserve commenting and formatting.

Mike Pastore states in his comment at [Ruby-Forums.com](https://www.ruby-forum.com/topic/6877080):

> Most YAML libraries I’ve worked with don’t preserve formatting or comments. Some quick research turns up only one that does—and it’s for Python (ruamel.yaml). In my experience, YAML is great for human-friendly, machine-readable configuration files and not much else. It loses its allure the second you bring machine-writeability into the picture.

So to the Ruby community: someone needs to write a YAML parser that preserves commenting and formatting!

In the meantime, all power to Anthon van der Neut, who has forked the PyYAML project and solved a good 80% of the problem of preserving the commenting and formatting. He also proved to be incredibly helpful in answering questions about the parser on Stack Overflow, and in responding to bug reports.

## hiera-bulk-edit.py
I realised that a script that could execute snippets of arbitrary Python code on the YAML files in memory would provide a powerful and flexible interface for bulk editing of Hiera files. In the remainder of the post, I’ll show how various data editing – and viewing – problems can be solved using my new tool.

## Installing the script
To install the script, just clone my Git repository and install the Python dependencies with PIP:

~~~ text
$ git clone https://github.com/alexharv074/hiera-bulk-edit
$ cd hiera-bulk-edit
$ pip install -r requirements.txt 
~~~
And if you wish, copy it to some place like /usr/local/bin.

## What it does
### Usage
~~~ text
$ hiera-bulk-edit.py <paths> <code_file>.py
~~~
The script loops through the files specified in paths, and for each of these, loads the contents into a Python ruamel.ordereddict structure, which the user may regard as a normal dictionary (which is Python’s equivalent of a Ruby Hash). The Python code in code_file.py is then executed on that structure, and the modified structure is written back to disk.

Note that Bash Globbing and Brace Expansion are supported in paths.

The reader will also note some variables of importance:

### hiera
The YAML data is stored in a dictionary called hiera.

### f
The file name of the file that is currently being edited is stored in f.

## Recipes
### Adding a key
Here we add (or over-write) all keys `['foo']['bar']` in all files specified in paths.

~~~ python
try:
  if 'foo' not in hiera:
    hiera['foo'] = {}
 
  hiera['foo']['bar'] = {
    'key1': 'val1',
    'key2': 'val2',
  }
 
except:
  e = sys.exc_info()[0]
  print "Got %s when updating %s" % (e, f)
~~~
### Deleting the key again

~~~ python
del hiera['foo']['bar']
del hiera['foo']
~~~
### Viewing a key
It is also possible to view keys as they appears in all files. In this example I use the clint project to also colour the output green, to make it easier to see:

~~~ python
from clint.textui import puts, colored, indent
 
if 'profile::base::users' in hiera and 'ec2-user' in hiera['profile::base::users']
and 'ssh_keys' in hiera['profile::base::users']['ec2-user']:
  try:
    print "In %s:" % f
    puts(colored.green("hiera['profile::base::users']['ec2-user']:"))
    with indent(4):
      puts(
        colored.green(
          ruamel.yaml.round_trip_dump(hiera['profile::base::users']['ec2-user'])
        )
      )
 
  except:
    e = sys.exc_info()[0]
    print "Got %s when updating %s" % (e, f)
~~~
### Sorting all keys alphabetically

~~~ python
# http://stackoverflow.com/questions/39307956/insert-a-key-using-ruamel/39308307#39308307
 
if hasattr(hiera, '_yaml_comment'):
    yaml_comment = hiera._yaml_comment
 
hiera = ruamel.yaml.comments.CommentedMap(
    sorted(
        hiera.items(), key=lambda t: t[0]
    )
)
 
if hasattr(hiera, '_yaml_comment'):
    hiera._yaml_comment = yaml_comment
~~~
### Add a key with formatting

~~~ python
# http://stackoverflow.com/questions/39262556/preserve-quotes-and-also-add-data-with-quotes-in-ruamel
 
from ruamel.yaml.scalarstring import SingleQuotedScalarString, DoubleQuotedScalarStr
ing
 
hiera['foo'] = SingleQuotedScalarString('bar')
hiera['bar'] = DoubleQuotedScalarString('baz')
~~~
