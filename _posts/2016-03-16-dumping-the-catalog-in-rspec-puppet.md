---
layout: post
title: "Dumping the catalog in rspec-puppet"
date: 2016-03-16
author: Alex Harvey
category: puppet
tags: puppet catalog rspec
---

I always knew there must be a better way.

In a [previous post](https://alexharv074.github.io/2015/12/31/compiling-a-puppet-catalog-on-a-laptop.html) I documented a procedure for compiling a catalog without logging onto a Puppet Master.  The procedure is useful but also complicated.

I often wondered why Rspec-puppet couldn't just dump the catalogs it compiles during unit testing.

Well it can; I just found a bit of the answer [here](https://groups.google.com/forum/#!topic/puppet-dev/AbXgZEFl3ME), and the rest inside the debugger.

## How to dump the catalog in Rspec-puppet

I assume we have Rspec-puppet set up already.  If not, try the [Rspec-puppet tutorial](http://rspec-puppet.com/tutorial/).

Imagine we have a simple test as follows:

~~~ ruby
require 'spec_helper'

describe 'myclass' do
  it {
    is_expected.to compile.with_all_deps
  }
end
~~~

To instead just dump the catalog, change the code as follows:

~~~ ruby
require 'spec_helper'

describe 'myclass' do
  it {
    File.write(
      'myclass.json',
      PSON.pretty_generate(catalogue)
    )
    #is_expected.to compile.with_all_deps
  }
end
~~~

Note carefully the use of UK spelling in ‘catalogue’.  Otherwise, that’s it. Now run the spec tests again and you’ll have the catalog under test saved in myclass.json.

_Update see also Rob Nelson’s related post [here](https://rnelson0.com/2016/06/14/print-the-rspec-puppet-catalog-courtesy-of-willaerk/)._
