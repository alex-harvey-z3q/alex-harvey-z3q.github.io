---
layout: post
title: "Compiling a puppet catalog – on a laptop"
date: 2015-12-31
author: Alex Harvey
---

_Update 13th March 2016_

_If you’re using Rspec-puppet and you want a catalog compiled, have a look here first._

From time to time I have wished that I could compile a Puppet catalog from my laptop.  Use-cases that spring to mind include debugging catalog compilation issues; and “hey, wouldn’t it be great if I could see what this super-complicated Puppet Forge module is actually doing without having to spin up a VM and ‘puppet apply’ it”.  Othertimes it has just been curiosity.

The actual use-case that caused me to finally sit down and figure out how to do all this was a large refactor, in the midst of which I discovered a need for Zack Smith’s / R.I. Pienaar’s catalog diff tool.  Disconnected from my corporate network at the time, unable to access my Puppet Master, I felt that I shouldn’t need to log into a Puppet Master to do what I wanted to do anyway.

It turns out that it’s a lot harder to do this than I expected.  Fortunately I can see that Puppet Labs have a feature request open to make this easier in PUP-3309, although it looks like we’ll need to wait for Puppet 5 for that.  In the mean time, this post will hopefully make it easier.

## Compiling a catalog on a Puppet Master

A catalog is a JSON file compiled by the Puppet Master that describes for the desired state for each resource that should be managed, and dependency information for resources that should be managed in a certain order.

In normal operation, the Puppet compiler takes as input the certificate name (`certname` in the agent’s `puppet.conf` file) and a representation of the node’s facts, and from this compiles the JSON catalog.

Most experienced Puppet administrators will have compiled catalogs manually before.  I usually do this when I’m debugging Hiera.  The command `puppet master --debug --compile <node> | grep -i hiera` is quite a useful one to know.

The `--compile` option is documented in the help as follows:

~~~ text
$ puppet help master
...
* --compile:
  Compile a catalogue and output it in JSON from the puppet master. Uses
  facts contained in the $vardir/yaml/ directory to compile the catalog.
~~~

It turns out, more specifically, that the facts for each node are stored in `$vardir/yaml/facts/$certname.yaml`.

Compiling a catalog from the Puppet Master is easy:

~~~ text
$ sudo puppet master --compile myhost.example.com > myhost.json
~~~

Doing the same thing from your development workstation or laptop, however, is a bit harder.

## Compiling a catalog from your laptop

### Set up your path

I assume that we have Puppet installed in a bundle.  In my `.bundle/config` I have:

~~~ yaml
---
BUNDLE_PATH: .gems
BUNDLE_BIN: .bin
~~~

I can therefore set $PATH as follows:

~~~ text
$ export PATH=.bin:$PATH
~~~

This allows me to find the Puppet binary in my bundle:

~~~ text
$ puppet -V
3.3.1
~~~

Which reminds me, I’m using a very old version of Puppet. Never mind about this; the procedure should be almost the same using the latest version of Puppet, which at the time of writing is 4.3.1. If not, let me know in the comments and I’ll fix it up accordingly.

### Determine your $vardir

As mentioned, the compiler will expect to find cached facts in `$vardir/yaml/facts/$certname.yaml`, so we need to know the value for $vardir.  Normally, this is set in our puppet.conf file, but because we are running Puppet from within a bundle, we don’t have a puppet.conf file.  We can of course use the `--configprint` option:

~~~ text
$ puppet master --configprint vardir
/Users/alexharvey/.puppet/var
~~~

If you were expecting to see /var/lib/puppet, you were probably unaware that the $vardir gets a different value if Puppet is run as a non-root user. Run it as root and we get /var/lib/puppet:

~~~ text
$ sudo puppet master --configprint vardir
/var/lib/puppet
~~~

### Set up your facts YAML file

The next thing to do is create the facts YAML file.  I also needed to create the facts directory to begin with:

~~~ text
$ mkdir -p ~/.puppet/var/yaml/facts
~~~

Next, we create the YAML file myhost.example.com.yaml:

~~~ yaml
--- !ruby/object:Puppet::Node::Facts
values:
  hostname: myhost
  domain: example.com
  concat_basedir: '/var/lib/puppet/concat'
  kernel: Linux
  osfamily: RedHat
  operatingsystem: RedHat
  operatingsystemrelease: '6.5'
  ipaddress: '10.1.1.1'
  node_tier: uat1
~~~

Note carefully the following points about this file’s content:

- The first line actually matters.  If the three dashes plus the comment are missing, Puppet will not read this file, and your catalog compilation will most likely fail after a cryptic warning that says ‘Host is missing hostname and/or domain’.
- You must supply both the $::hostname and $::domain facts – or alternatively provide $::fqdn – or you’ll get the same (in this context, slightly less cryptic) warning.
- Less surprisingly, you’ll need to provide values for all the facts that are actually needed to compile your catalog.  If you have already set up rspec-puppet, you’ll probably have already mentioned all the facts you care about in spec/spec_helper.rb and throughout your rspec examples.

Of course, the easiest way to generate this file is to simply log onto your Puppet Master and get your Puppet Master’s copy!

### Other mandatory command line options

Again, because we don’t have a puppet.conf file, our local Puppet Master won’t know about these other crucial settings:

- $modulepath – the search path to your modules
- $manifestdir – deprecated in later versions of Puppet after directory environments were introduced. I need to specify this setting as I’m using Puppet 3.3.1; later versions I think you’ll need to specify $manifest instead, but haven’t checked.
- $hiera_config – the path to your hiera.yaml file

### Run the spec_prep rake task

We will need all of our code to be available in a module path that we will pass to the compilation shortly.  I assume that we are using the puppetlabs_spec_helper gem and have rspec-puppet already set up.  The spec_prep task is responsible for making the code available in spec/fixtures/modules by setting up symbolic links.

~~~ text
$ bundle exec rake spec_prep
~~~

### Actually compiling the catalog

We are now ready to actually compile the catalog:

~~~ text
$ puppet master --modulepath=spec/fixtures/modules --manifestdir=manifests --hiera_config=hiera.yaml --compile myhost.example.com > myhost.json
~~~

That’s it!

Well, almost. I also found that the first line of myhost.json is not part of the JSON catalog:

~~~ text
$ cat myhost.json
^[[mNotice: Compiled catalog for myhost.example.com in environment production in 4.93 seconds^[[0m
{
  "document_type": "Catalog",
  "data": {
    "tags": [
      "settings",
...
~~~

Naturally, it won’t be valid JSON unless you delete that line.  Has this been fixed in a later version of Puppet?  Not sure yet.  To avoid having to manually delete that line we can pipe through ‘sed 1d’:

~~~ text
$ puppet master --modulepath=spec/fixtures/modules --manifestdir=manifests --hiera_config=hiera.yaml --compile myhost.example.com | sed 1d > myhost.json
~~~

### Troubleshooting: The cryptic warning

Well, it seems cryptic when you’re inside a debugger for half a day trying to figure out what caused it! If you haven’t composed your facts YAML file properly, or if it’s in the wrong location, you’ll see the following warning:

~~~ text
$ puppet master --modulepath=spec/fixtures/modules --manifestdir=manifests --hiera_config=hiera.yaml --compile myhost.example.com > /dev/null
Warning: Host is missing hostname and/or domain: myhost.example.com
~~~

Check the following:

- That you passed the correct hostname to --compile
- That your facts YAML file has the correct filename
- That it is in the correct directory
- That the first line is correct
- That you have provided either $::hostname and $::domain, or $::fqdn

And that’s it. In a later post, I’ll show how you can combine all this and use catalog diff while refactoring code.
