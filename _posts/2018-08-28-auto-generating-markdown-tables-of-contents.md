---
layout: post
title: "Auto-generating Markdown tables of contents"
date: 2018-08-28
author: Alex Harvey
tags: markdown
---

I recently spent some time automating the generation of Markdown tables-of-contents for compatibility with my open source projects in Github and also Gitlab Cloud. In the process, I reviewed a number of auto table-of-contents options by Markdown flavour and version, which I will document here.

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

There are tools out there to auto-generate tables of contents e.g. [markdown-toc](https://github.com/jonschlinkert/markdown-toc), but I wanted something simpler and I wrote my own Ruby script to do it.  My script is [gen_markdown_toc.rb](https://github.com/alexharv074/scripts/blob/master/gen_markdown_toc.rb).

To use it (on a Mac):

~~~ text
gen_markdown_toc.rb FILE.md | pbcopy
~~~

Then copy the generated text in your Markdown file where you want the table of contents to appear.

## Gitlab Markdown

As of now, Gitlab Cloud Markdown uses GFM as well, or at least the version of Gitlab Cloud that I tested this on does.

Note that Gitlab's docs [here](https://about.gitlab.com/handbook/product/technical-writing/markdown-guide/#table-of-contents-toc) reveal that until recently Gitlab used Kramdown under the hood (see below). I discovered this page [here](https://gitlab.com/gitlab-org/gitlab-ce/issues/45388) that explains why they migrated away from Kramdown and thereby broke the useful table of contents feature.

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

RedCarpet documented [here](https://github.com/vmg/redcarpet) is another flavour that makes auto-generation of tables of contents easy. It is apparently used in Gitlab's Wikis. Just add this for a table of contents:

~~~ text
* Table of contents
[[_TOC_]]
~~~

## Typora Markdown

Another flavour is Typora Markdown documented [here](https://support.typora.io/Markdown-Reference/#table-of-contents-toc). For a ToC you can write:

~~~ text
[toc]
~~~

## End note

These are all the Markdown formats I am aware of. I would like to keep this page up to date and to that end I welcome feedback and updates.
