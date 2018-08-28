---
layout: post
title: "Auto-generating Markdown tables of contents"
date: 2018-08-28
author: Alex Harvey
tags: markdown
---

I recently wrote a script to auto-generate Markdown tables-of-contents for compatibility with both the latest version of Gitlab Cloud and Github. In the process, I reviewed a number of Markdown table-of-contents options that I will document here, which depend on the Markdown flavour and version.

## Kramdown Markdown

This is used for example in this Jekyll blog. If you're lucky enough to have Kramdown Markdown then you just need to add this:

~~~ text
* Table of contents
{:toc}
~~~

## Github Markdown

Github uses Github Flavoured Markdown a.k.a. GFM, based on the CommonMark spec. It is documented [here](https://github.github.com/gfm/#what-is-github-flavored-markdown-).

As far as I know, GFM doesn't support auto ToCs like Kramdown does, although there are tools out there to do it, e.g. [markdown-toc](https://github.com/jonschlinkert/markdown-toc). I chose to write a Ruby script to do it as it seemed like that was going to be faster. My script is [gen_markdown_toc.rb](https://github.com/alexharv074/scripts/blob/master/gen_markdown_toc.rb).

To use it:

~~~ text
gen_markdown_toc.rb FILE.md | pbcopy
~~~

Then copy it into your Markdown file.

## Gitlab Markdown

Gitlab Cloud Markdown is now the same as Github. Specifically, this was tested on Gitlab Cloud.

Gitlab's docs [here](https://about.gitlab.com/handbook/product/technical-writing/markdown-guide/#table-of-contents-toc) suggest that until recently Gitlab used Kramdown under the hood. Then I discovered this page [here](https://gitlab.com/gitlab-org/gitlab-ce/issues/45388) which seems to explain why they migrated away from Kramdown and thereby broke the very useful ToC feature.

## RedCarpet Markdown

I read that RedCarpet is used in Gitlab's Wikis, and for completeness I note that it's documented that you can add a table of contents using:

~~~ text
* Table of contents
[[_TOC_]]
~~~

## Typora Markdown

The Typora Markdown is documented [here](https://support.typora.io/Markdown-Reference/#table-of-contents-toc). For a ToC you can write:

~~~ text
[toc]
~~~

## Conclusion

I am happy to keep this page up to date and to that end welcome feedback and updates. My email address is on my Github.
