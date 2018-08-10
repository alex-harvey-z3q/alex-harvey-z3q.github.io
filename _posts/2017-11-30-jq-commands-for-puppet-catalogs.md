---
layout: post
title: "JQ commands for Puppet catalogs"
date: 2017-11-30
author: Alex Harvey
tags: puppet catalog jq
---

This is a page dedicated to useful JQ commands for querying a compiled Puppet catalog.

* Table of Contents
{:toc}

## General note about Puppet 3 v Puppet 4/5 catalogs
In Puppet 4 the catalog structure changed a little, and it is important to be aware that the crucial resources key is in the top level in Puppet 4/5, whereas it’s nested under the data key in Puppet 3.

All commands below are for Puppet 4/5.

## List all file resources by title
~~~ text
$ jq '.resources[] | select(.type == "File") | .title' < catalog.json
~~~
## Select a file resource based on title
~~~ text
$ jq '.resources[] | select((.type == "File") and (.title=="sources.list.d"))' < catalog.json
~~~
## Select all files resource based on title that contains a string
~~~ text
$ jq '.resources[] | select((.title | contains("/home")) and (.type == "File")) | .title' < catalog.json
~~~
## List all the classes in a catalog
Similar to listing resources:

~~~ text
$ jq '.resources[] | select(.type=="Class") | .title' < catalog.json
~~~
## List all defined types in a catalog
~~~ text
$ jq -r '.resources[] | select(.type | contains("::")) | [.type, .title] | @csv' < catalog.json
~~~
## List all resource types in a catalog
~~~ text
$ jq '.resources[] | .type' < catalog.json | sort -u
~~~
## Debugging a catalog dependency issue
Example error message
~~~ text
1) rspec should compile into a catalogue without dependency cycles
   Failure/Error: is_expected.to compile.with_all_deps
     error during compilation: Could not retrieve dependency 'File[/etc/apt/sources.list.d]' of Exec[apt_update]
   # ./spec/hosts/role_default_spec.rb:25:in `block (2 levels) in <top (required)>'
~~~
Rspec doesn’t tell us which resources are involved so we need some magic to figure this out.

## Change the Rspec to generate the catalog file
Comment out this so writing out of the catalog file proceeds:

~~~ ruby
it 'should compile and write out a catalog file' do
  # is_expected.to compile.with_all_deps
  File.write(
    'catalogs/default_default_vagrant_vagrant.json',
    PSON.pretty_generate(catalogue)
  )
end
~~~
## Find these resources in the catalogs along with their locations in the manifests
Find the File resource
~~~ text
$ jq 'resources[] |
>       select((.type == "File") and (.title=="sources.list.d")) |
>       {"type": .type, "title": .title, "parameters": .parameters}' < catalog.json
{
  "type": "File",
  "title": "sources.list.d",
  "parameters": {
    "path": "/etc/apt/sources.list.d/",
    "ensure": "directory",
    "owner": "root",
    "group": "root",
    "purge": false,
    "recurse": false,
    "notify": "Exec[apt_update]"
  }
}
~~~
Now find the Exec resource
~~~ text
$ jq '.resources[] |
>    select((.type == "Exec") and (.title=="apt_update")) |
>    {"type": .type, "title": .title, "file": .file, "line": .line, "parameters": .parameters}' \
>      < catalog.json
{
  "type": "Exec",
  "title": "apt_update",
  "file": "/path/to/manifests/apt.pp",
  "line": 30,
  "parameters": {
    "command": "/usr/local/sbin/apt_update",
    "logoutput": "on_failure",
    "refreshonly": false,
    "subscribe": "File[/etc/apt/sources.list.d]",
    "require": [
      "File[/etc/apt/apt.conf.d/99auth]",
      "File[/usr/local/sbin/apt_update]"
    ]
  }
}
~~~
So we can see the bug and know which file to edit to fix it.
