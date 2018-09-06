---
layout: post
title: "Analysing Puppet module dependencies using JQ"
date: 2018-09-06
author: Alex Harvey
tags: puppet jq
---

About a month ago, it seems, Puppet's stdlib module version 5.0.0 was [released](https://github.com/puppetlabs/puppetlabs-stdlib/commit/597769a73cc194ea9daa8a49b5707be45ad5240b), and if my own ELK project is any indication, a lot of code bases out there that use Librarian Puppet to pull in stdlib will be confused and broken as mine was.

The main reason for this post, however, was just to document the method of analysing the dependencies I discovered.

## Broken build

The failed build is available online [here](https://travis-ci.org/alexharv074/elk/jobs/420704510) and I ran it again in Librarian verbose mode [here](https://travis-ci.org/alexharv074/elk/jobs/423859931). Librarian can be seen failing like this:

~~~ text
[Librarian] Resolving puppetlabs-concat (>= 0) <https://forgeapi.puppetlabs.com>
[Librarian]   Checking manifests
[Librarian]   Module puppetlabs-concat found versions: 5.0.0, 4.2.1, 4.2.0, 4.1.1, 4.1.0, 4.0.1, 4.0.0, 3.0.0, 2.2.1, 2.2.0, 2.1.0, 1.2.5, 1.2.4, 1.2.3, 1.2.2, 1.2.1, 1.2.0, 1.1.2, 1.1.1, 1.1.0, 1.1.0-rc1, 1.0.4, 1.0.3, 1.0.2, 1.0.1, 1.0.0, 1.0.0-rc1
[Librarian]     Checking puppetlabs-concat/5.0.0 <https://forgeapi.puppetlabs.com>
[Librarian]       Conflict between puppetlabs-concat/5.0.0 <https://forgeapi.puppetlabs.com> and puppetlabs-concat (< 5.0.0, >= 3.0.0) <https://forgeapi.puppetlabs.com>
[Librarian]       Backtracking from puppetlabs-concat/5.0.0 <https://forgeapi.puppetlabs.com>
[Librarian]     Checking puppetlabs-concat/4.2.1 <https://forgeapi.puppetlabs.com>
[Librarian]       Resolved puppetlabs-concat (>= 0) <https://forgeapi.puppetlabs.com> at puppetlabs-concat/4.2.1 <https://forgeapi.puppetlabs.com>
[Librarian]   Resolved puppetlabs-concat (>= 0) <https://forgeapi.puppetlabs.com>
[Librarian] Conflict between puppetlabs-stdlib (< 5.0.0, >= 4.13.1) <https://forgeapi.puppetlabs.com> and puppetlabs-stdlib/5.0.0 <https://forgeapi.puppetlabs.com>
Could not resolve the dependencies.
~~~

While it was clear that one of my modules wanted `puppetlabs-stdlib/5.0.0` and this conflicted with concat's requirement for `< 5.0.0, >= 4.13.1`, it was less clear as to which one!

## Querying stdlib versions

This JQ command here allowed me to view all dependencies conveniently:

~~~ text
▶ cat spec/**/metadata.json | \
>   jq '.dependencies[] | select(.name=="puppetlabs/stdlib") | .version_requirement'
">= 4.16.0 < 5.0.0"
">= 4.13.1 < 5.0.0"
">=3.2.0 <5.0.0"
">= 4.13.1 < 5.0.0"
">= 4.13.0 < 5.0.0"
">= 3.0.0"
">=4.13.0 <5.0.0"
">= 4.0.0 < 5.0.0"
">=3.2.0 <5.0.0"
">= 4.13.1 < 5.0.0"
">= 4.22.0 <5.0.0"
">= 4.13.1 < 5.0.0"
">= 1.0.2 <5.0.0"
">= 4.13.0 < 5.0.0"
~~~

This led me to realise:

1. Practically every module out there is specifying stdlib `< 5.0.0`!
1. No actual module was specifying `== 5.0.0`.

## The root cause

It turns out that the problem was simply that I had a Puppetfile line that I thought was requesting stdlib, _any_ version, like this:

~~~ text
mod 'puppetlabs/stdlib'
~~~

Whereas evidently such a line causes Librarian Puppet to require the _latest_ version.

## The fix

So, I changed my Puppetfile to this and everything was fine:

~~~ text
# All other dependencies specify < 5.0.0 whereas if I allow latest
# released ~ 18 days ago at the time of writing, librarian-puppet
# can't resolve the dependencies.
#
mod 'puppetlabs/stdlib', '< 5.0.0'
~~~

## Conclusion

I thought the behaviour of Librarian Puppet here was surprising enough to be worth documenting, and the `jq` command useful enough that I'll probably want it again some day. I also hope this is helpful to others.
