---
layout: post
title: "Speeding up Beaker on a Mac using SquidMan"
date: 2016-04-25
author: Alex Harvey
category: puppet
tags: puppet beaker
---

If you have used Beaker extensively for system testing your Puppet roles and profiles, you will have no doubt had some coffees while waiting for RPMs to download that you may well have downloaded before.

I was pleasantly surprised to find that setting up a Squid Cache using [SquidMan](http://squidman.net/) on my Mac OS X Yosemite laptop and then having Beaker point at it was fairly straightforward. Still, there are a few gotchas to justify a blog post on the subject.

Thanks go to Alexander Rumyantsev for his [post](http://serverascode.com/2014/03/29/squid-cache-yum.html) on using Squid to cache RedHat/CentOS yum repositories, and also to My Private Network for their [post](https://help.my-private-network.co.uk/support/solutions/articles/9418-setting-up-a-proxy-server-on-your-mac-os-x-system) on setting up Squid Man.

## Installing and configuring SquidMan

I downloaded SquidMan 3.6 from [here](http://squidman.net/resources/downloads/SquidMan3.6.dmg), and installed as with any other DMG file (although, to be sure, I had to manually drag and drop the app into my Applications folder).

Having started I went to its Preferences and entered the following config:

![Squid Preferences 1]({{ "/assets/squidman1.png" | absolute_url }})

That is, I set the port to 3128, increased the maximum object size to 256MB in case I need to deal with large RPMs, and set the cache size to 4GB, and then I went to the Clients tab:

![Squid Preferences 2]({{ "/assets/squidman2.png" | absolute_url }})

And here I allowed Beaker to connect from whatever network it happens to be on, i.e. all. (Limit that as your needs for security dictate.)  (If you forget this step, Beaker will error out during a Yum install with a 403 Forbidden error.)

After starting Squid, you can find its config file using:

~~~ text
$ ps -ef |grep squid
  501  2955     1   0  8:17pm ??         0:03.64 /Applications/SquidMan.app/Contents/MacOS/SquidMan
  501  7283     1   0  8:28pm ??         0:00.00 /usr/local/squid/sbin/squid -f /Users/alexharvey/Library/Preferences/squid.conf
  501  7285  7283   0  8:28pm ??         0:00.08 (squid-1) -f /Users/alexharvey/Library/Preferences/squid.conf
  501 13310 96095   0  8:43pm ttys003    0:00.00 grep squid
~~~

And have a look at the squid.conf file, in particular:

~~~ text
cache_access_log stdio:/Users/alexharvey/Library/Logs/squid/squid-access.log
cache_store_log stdio:/Users/alexharvey/Library/Logs/squid/squid-store.log
cache_log /Users/alexharvey/Library/Logs/squid/squid-cache.log
~~~

Tailing these log files while your Beaker tests run allows you to see it working, in particular the Cache Hits and Misses.

## Disabling mirrorlists

As Alexander Rumyantsev notes, use of Yum mirror lists in place of baseurls is going to cause a lot of unnecessary cache misses, so we disable them.

In my case I have all my Yum repos in Hiera so this meant making changes like:

~~~ yaml
---
  'epel':
    ensure: 'present'
    descr: 'Extra Packages for Enterprise Linux 7 - $basearch'
    enabled: '1'
    failovermethod: 'priority'
    gpgcheck: '1'
    gpgkey: 'https://getfedora.org/static/352C64E5.txt'
    #mirrorlist: 'https://mirrors.fedoraproject.org/metalink?repo=epel-7&arch=$basear
ch'
    baseurl: 'http://download.fedoraproject.org/pub/epel/7/$basearch'
~~~

(Alexander Rumyantsev also removes the Yum Fastest Mirror plugin, although my reading of the documentation is that this won’t be used anyway if you remove all the mirror lists.)

(If you’d like to see the actual commit where I updated mirror lists with base URLs it is [here](https://github.com/alexharv074/elk/commit/86a740caa37afc9254e2abfb9397bcb38e6f3d3a).)

## Telling Beaker to use the Squid Cache

All that is left to do is call Beaker after setting the $BEAKER_PACKAGE_PROXY environment variable:

~~~ text
$ BEAKER_PACKAGE_PROXY=http://<myHostIP>:3128 bundle exec rspec spec/acceptance/
~~~

The first time you run it, of course, the Squid Cache will be empty, so you won’t expect to see any performance improvement. After that, I found 14 minutes for an ELK stack became about 4.

## A note about $BEAKER_PACKAGE_PROXY on non-Red Hat-based platforms

By a curious coincidence I had actually fixed the $BEAKER_PACKAGE_PROXY functionality for Yum-based platforms in Beaker-rspec myself in [this](https://github.com/puppetlabs/beaker/pull/983/files) PR.

I mention this because I noted at the time that $BEAKER_PACKAGE_PROXY looked broken in the same way for Debian-based platforms (and not to mention other platforms like AIX etc.). Consider this a heads-up if you’re trying to get this procedure to work on say Ubuntu; you may need to send in a patch similar to the one I sent in for the Red Hat plaforms.

_Update: Thanks to [Steven Bambling](https://github.com/smbambling) for pointing out that SquidMan is also available as a Homebrew Cask._
