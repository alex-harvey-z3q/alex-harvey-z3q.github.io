---
layout: post
title: "Generating Markdown from source code using ERB"
date: 2018-11-09
author: Alex Harvey
tags: markdown
---

As a maintainer of code bases, the problem of code duplication in project documentation arises frequently. An app's usage message is often useful in the project's README; usage examples sometimes duplicate unit tests; comments that document parameters often reappear in the docs.

Solutions like Javadoc, YARD etc for generating documentation from source code have been around for decades, but these tools are task-specific and can't be used in any general way to keep a project's Markdown up to date.

Inspired by the [Liquid](https://shopify.github.io/liquid/) template engine, I wanted a solution that allowed me to just interpolate arbitrary dynamic content in my Markdown files. I couldn't find anything, however, and I have settled for now on a custom solution that involves just a few lines of Ruby and then the ERB template language.

This post shows how I set it up.

## Example project

By way of example, imagine a project that contains shell scripts that build Cloudformation stacks. Each script has Markdown documentation with, amongst other things, a script "usage" section, and a sections that documents the Cloudformation parameters. The scripts change a lot, and updating this documentation in two places quickly becomes unmaintainable.

Thus, I have a create stack shell script:

~~~ bash
#!/usr/bin/env bash

usage() {
  echo "$0 [-h] {create|update} STACK_NAME"
  exit 1
}

[ "$1" == "-h" ] && usage
[ $# -ne 2 ] && usage

mode=$1 ; stack_name=$2

aws cloudformation "${mode}-stack" \
  --stack-name    "$stack_name" \
  --template-body file://cloudformation.yaml \
  --parameters    file://parameters.json
~~~

And a Cloudformation template with parameters in it like:

~~~ yaml
Parameters:
  KeyName:
    Description: Name of an existing EC2 KeyPair to enable SSH access to the instance
    Type: AWS::EC2::KeyPair::KeyName
    ConstraintDescription: must be the name of an existing EC2 KeyPair.
  InstanceType:
    Description: WebServer EC2 instance type
    Type: String
    Default: t2.small
    AllowedValues: ['t1.micro','t2.nano','t2.micro','t2.small','t2.medium']
~~~

Now imagine I have some docs in a file docs/EC2_STACK.md. This file has a "usage" section that repeats the script's usage message and a "parameters" section that repeats information in the Cloudformation template.

## ERB Solution

### docs.rb

The first thing I did was to write a very simple Ruby script that renders ERB source files. It is just this:

~~~ ruby
require 'erb'

docs_map = JSON.parse('docs.json')

docs_map.each do |src,dst|
  template = File.read(src)
  renderer = ERB.new(template, nil, '-')
  File.write(dst, renderer.result())
end
~~~

The docs.json file that it loads then contains this map:

~~~ json
{
  "docs/EC2_STACK.erb": "docs/EC2_STACK.md",
  "docs/OTHER_STACK.erb": "docs/OTHER_STACK.md"
}
~~~

Notice that this file maps ERB source files onto destination Markdown files, and that the script just reads these files in a loop and renders them with the Ruby ERB library.

### ERB code

My ERB templates are mostly just Markdown source with ERB interpolations in them. So, to solve the "usage" problem I have some code like this:

~~~ erb
## Usage

To run the script:

```text
<%# Get the usage from the script's help message -%>
<% usage = %x{bash create-stack.sh -h} -%>
<%= usage %>
```
~~~

And to self-document the parameters I have another block like this:

~~~ erb
### Parameters

The parameters are in `parameters.json`. The parameters are:

<%# Use description fields in the Cloudformation templates as documentation here. -%>
<% require 'yaml' -%>
<% params = YAML.load_file('cloudformation.yaml')['Parameters'] -%>
<% params.each do |param,data| -%>
#### <%= param %>

<%= data['Description'] %>.

<% end -%>
### Full working example
...
~~~

These are just two simple examples, and I imagine I will find many ways to use this method to avoid duplication in docs.

### Make task

Then I created a Make task in my Makefile to regenerate the docs when I type "make docs":

~~~ bash
.PHONY: docs
docs:
  ruby docs.rb
~~~

### Dependencies

There are no dependencies other than a system Ruby; the ERB library is in the Ruby stdlib. I tested the code on Ruby 2.4.1 that I have on my MacBook Pro, but I believe it should work on any system that has a Ruby installed.

## Further thoughts

I quite like this solution, although it is not perfect. When I set it all up in my current project, I was able to remove 150 lines or so of duplication immediately. The Markdown source, I find, is already more readable, as it directs the reader to the single sources of truth, rather than documented copies of them. And the Ruby code is clean and simple and introduces no serious maintenance burden.

I originally intended to use Python and Jinja2, because Python is a popular and easy language, but in the end I found benefits in the ERB templating that outweighed other considerations. While both Jinja2 and ERB are excellent for generating website markup, the ability to use all of Ruby's language features in the templates - especially its Perl-like string manipulation features - made it much better-suited to tasks like scraping comments from source code.

Eventually, of course, I imagine I'll end up copy/pasting this Ruby source into other projects, which is not ideal. At the moment, though, I can't convince myself that turning this into an actual library makes sense when it's only 7 lines!

Well, that's all I have, and I hope others find it useful.
