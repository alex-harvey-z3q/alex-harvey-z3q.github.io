---
layout: post
title: "Using catalog-diff while refactoring Puppet code"
date: 2015-12-31
author: Alex Harvey
---

In [yesterday’s post](http://alexharv074.github.io/compiling-a-puppet-catalog-on-a-laptop.html) I showed how you can compile a Puppet catalog from a bundle on a laptop. Today I’m going to document how to use Zack Smith’s catalog diff tool to assist with complex refactoring changes.

## Refactoring exercise
For the purpose of describing how to use the catalog diff tool, it will be better to use an artificially simple code example. Imagine a single site.pp file with the following contents:

~~~ puppet
node 'myhost.example.com' {
  file { '/tmp/myfile':
    ensure  => file,
    content => "My hostname is ${::hostname}\n",
  }
}
~~~

The intention is to refactor this as a class like this:

~~~ puppet
class myfile {
  file { '/tmp/myfile':
    ensure  => file,
    content => "My content is ${::hostname}\n",
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
  }
}

node 'myhost.example.com' {
  include myfile
}
~~~

## Project structure

If you wish to try this, I have the following simple project structure:

~~~ text
$ tree myproject/
myproject/
├── Gemfile
├── Gemfile.lock
└── manifests
    └── site.pp

1 directory, 3 files
~~~

And a Gemfile:

~~~ ruby
source "https://rubygems.org"
gem "puppet", "3.3.1"
~~~

## Installing puppet-catalog-diff

Normally, you would install puppet-catalog-diff on your Puppet Master, but as with yesterday’s post, I find it more useful to be able to run all of this from my laptop in a bundle.  So I have chosen to simply clone the Github project to the directory on my laptop where I have all my git projects:

~~~ text
$ cd ~/git
$ git clone https://github.com/acidprime/puppet-catalog-diff.git
~~~

The [documentation](https://github.com/acidprime/puppet-catalog-diff) for the project is awesomely long and complicated; it can do many things. All I care about is:

- The tool is delivered as a [Puppet Face](https://puppetlabs.com/blog/puppet-faces-what-the-heck-are-faces)
- You’ll therefore need to add its lib directory in $RUBYLIB for the Face to be available.

Again, I assume we have Puppet installed in a bundle.  I assume we have the bundle’s bin directory in $PATH and I assume we are in the root directory of the bundle.  So I add the catalog-diff tool’s lib directory to $RUBYLIB:

~~~ text
$ cd myproject/
$ export RUBYLIB=../puppet-catalog-diff/lib
~~~

We should now be able to access the ‘diff’ subcommand of the ‘puppet catalog’ face.

~~~ text
$ puppet help catalog
...
ACTIONS:
...
  diff        Compare catalogs from different puppet versions.
~~~

Note that the help for the ‘diff’ subcommand is a little misleading. While the original motivation for the tool may have been to compare catalogs from different puppet versions, it is equally useful to our task of comparing catalogs from before and after a refactor. So ‘puppet catalog diff’ really just allows you to do diff two Puppet catalogs.

We should also look at the help for the diff subcommand, and I show in this excerpt the only option I care about:

~~~ text
$ puppet help catalog diff
...
  --show_resource_diff           - Display differeces between resources in
                                   unified diff format
~~~

Being able to see the diffs between resources is certainly important if you’re refactoring code.

## Compiling the catalogs
For more detail on how to compile the catalogs, refer to yesterday’s post.

Our YAML facts file today needs only two fact values:

~~~ yaml
# ~/.puppet/var/yaml/facts/myhost.example.com.yaml
--- !ruby/object:Puppet::Node::Facts
values:
  hostname: myhost
  domain: example.com
~~~

A reminder that we set the $PATH:

~~~ text
$ export PATH=.bin:$PATH
~~~

And then the command to compile the catalog:

~~~ text
$ puppet master --manifestdir=manifests --compile myhost.example.com | sed 1d > myhost_before.json
~~~

At this point I would refactor the code, as described in the ‘Code examples’ section above, and then create the second catalog:

~~~ text
$ puppet master --manifestdir=manifests --compile myhost.example.com | sed 1d > myhost_after.json
~~~

## Diff’ing the two catalogs
We are now ready to run the diff:

~~~ text
$ puppet catalog diff --show_resource_diff myhost_before.json myhost_after.json

--------------------------------------------------------------------------------
myhost_after                                                               22.5%
--------------------------------------------------------------------------------
Old version:    1451635325
New version:    1451652391
Total resources in old: 4
Total resources in new: 5
Only in new:
        class[Myfile]
Differences as diff:
        File[/tmp/myfile]
 ",
                        }
             ensure => "file"
+            group => "root"
+            mode => "0644"
+            owner => "root"
        }
Params in old:
        File[/tmp/myfile]:

Params in new:
        File[/tmp/myfile]:
        owner = root
        group = root
        mode = 0644
Catalag percentage added:       20.00
Catalog percentage removed:     0.00
Catalog percentage changed:     25.00
Added and removed resources:    +1 / 0
Node percentage:        22.5

--------------------------------------------------------------------------------
1 out of 1 nodes changed.                                                  22.5%
--------------------------------------------------------------------------------

Nodes with the most changes by percent changed:
1. myhost_after                                                           22.50%

Nodes with the most changes by differeces:
1. myhost_after                                                           2false
~~~

So we can easily see that we have added a new resource, `Class[Myfile]`. Both catalogs contain the resource `File[/tmp/myfile]`, and we can see they differ, as expected, by the additional attributes we have passed to them.

This gives me confidence that I refactored the code without introducing bugs.
