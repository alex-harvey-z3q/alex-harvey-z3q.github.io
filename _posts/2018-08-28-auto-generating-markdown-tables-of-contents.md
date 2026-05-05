---
layout: post
title: "Auto-generating Markdown tables of contents"
date: 2018-08-28
author: Alex Harvey
tags: markdown
---

I recently spent some time automating the generation of Markdown tables-of-contents for compatibility with my open source projects in Github and also Gitlab Cloud. In the process, I reviewed a number of auto table-of-contents options by Markdown flavour and version, which I will document here.

**Update:** Thanks to GitHub user [@madpipeline](https://github.com/madpipeline), who pointed out that Gitlab Markdown now supports built-in table of contents syntax in Markdown files and other supported places.

## Github Markdown

Github uses Github Flavoured Markdown (GFM), which is based on the CommonMark spec. GFM is documented [here](https://github.github.com/gfm/#what-is-github-flavored-markdown-). As such, a table of contents is something you are expected to write yourself in Markdown, using [inline links](https://github.github.com/gfm/#example-487).

For example:

~~~ text
#### Table of contents

1. [Section 1](#section-1)
2. [Section 2](#section-2)
    - [Subsection a](#subsection-a)
    - [Subsection b](#subsection-b)
~~~

There are tools out there to auto-generate tables of contents e.g. [markdown-toc](https://github.com/jonschlinkert/markdown-toc), but I wanted something simpler and I wrote my own Ruby script to do it. My script is [mdtoc.rb](https://github.com/alex-harvey-z3q/markdown_toc/blob/master/mdtoc.rb).

To use it (on a Mac):

~~~ text
gen_markdown_toc.rb FILE.md | pbcopy
~~~

Then copy the generated text in your Markdown file where you want the table of contents to appear.

## Gitlab Markdown

Gitlab Flavoured Markdown is based on CommonMark and Github Flavoured Markdown, with additional extensions specific to Gitlab. Gitlab now supports built-in tables of contents in Markdown files and other supported places.

To add a table of contents, add either of these tags on its own line where you want the table of contents to appear:

~~~ text
[[_TOC_]]
~~~

or:

~~~ text
[TOC]
~~~

According to Gitlab's documentation, this works in Markdown files, Wiki pages, issues, merge requests, and epics, but not in notes or comments. See Gitlab's documentation [here](https://docs.gitlab.com/user/markdown/#table-of-contents).

## Bitbucket Markdown

According to documentation [here](https://confluence.atlassian.com/bitbucketserver/markdown-syntax-guide-776639995.html), Bitbucket's Markdown is also based on CommonMark, so I would expect my script to work on Bitbucket too.

## Kramdown Markdown

Meanwhile, other versions of Markdown have built in features to auto-generate tables of contents. Kramdown documented [here](https://kramdown.gettalong.org) is a Ruby implementation of Markdown that makes tables of contents a lot easier. If you are using Kramdown, you just need to add this:

~~~ text
* Table of contents
{:toc}
~~~

This Jekyll blog uses Kramdown Markdown for example.

## RedCarpet Markdown

RedCarpet documented [here](https://github.com/vmg/redcarpet) is another Markdown parser. RedCarpet can generate tables of contents programmatically via its `HTML_TOC` renderer, although whether a particular table-of-contents marker works depends on the application using RedCarpet.

For Gitlab specifically, use Gitlab's own table-of-contents syntax described above rather than relying on RedCarpet behaviour.

## Typora Markdown

Another flavour is Typora Markdown documented [here](https://support.typora.io/Markdown-Reference/#table-of-contents-toc). For a ToC you can write:

~~~ text
[toc]
~~~

## End note

These are all the Markdown formats I am aware of. I would like to keep this page up to date and to that end I welcome feedback and updates.
