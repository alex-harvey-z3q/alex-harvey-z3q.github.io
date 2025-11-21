---
layout: post
title: "Using create_specs to refactor Puppet"
date: 2017-05-31
author: Alex Harvey
category: puppet
tags: puppet create-specs rspec
---

In this post I document a new method for complex Puppet code refactoring, which involves a simple tool that I wrote called [create_specs](https://github.com/alex-harvey-z3q/create_specs).

I have been using this method a while now; I find it easier than catalog-diff and consider it to be safer as well.

The tool create_specs automatically generates Rspec test cases to test all aspects of a compiled catalog that is passed to it as an input. Of course, most Puppet modules can compile an infinite number of catalogs, unless they are very simple. Therefore, to have confidence in a real refactoring effort, we would need to compile a representative set of these catalogs and apply the method I describe here to each of those. This will be out of scope for today, but it is trivial to extend the method.

Here, I provide a simple Puppet module that manages an NTP service in a single class, and then I refactor it to split the module into several classes. I then show how this method proves with certainty that the refactoring did not introduce bugs.

I assume the reader already understands how to set up Rspec-puppet; if not, have a look at my [earlier](https://alex-harvey-z3q.github.io/2016/05/08/setting-up-puppet-module-testing-from-scratch-part-i-puppet-syntax-puppet-lint-and-rspec-puppet.html) post.

* Table of Contents
{:toc}

## Sample code

The sample code is a simple Puppet class that installs and configures NTP.

(Note: all of the code for this blog post is available at Github [here](https://github.com/alex-harvey-z3q/create_specs_example). The reader can step through the revision history to see the examples before and after the refactoring.)

~~~ puppet
class ntp (
  Array[String] $servers,
) {
  package { 'ntp':
    ensure => installed,
  }

  file { '/etc/ntp.conf':
    content => template("${module_name}/ntp.conf.erb"),
    require => Package['ntp'],
  }

  service { 'ntp':
    ensure    => running,
    enable    => true,
    subscribe => File['/etc/ntp.conf'],
  }
}
~~~

## Create specs

Before I refactor anything, I need to compile a catalog. To do this, I create an initial spec file that uses Rspec-puppet to simply compile a catalog, as documented in the project’s README:

```ruby
# init_spec.rb

require 'spec_helper'

describe 'ntp' do
  let(:params) do
    {
      'servers' => [
        '0.au.pool.ntp.org',
        '1.au.pool.ntp.org',
        '2.au.pool.ntp.org',
        '3.au.pool.ntp.org',
      ]
    }
  end

  it {
    File.write(
      'catalogs/ntp.before.json',
      PSON.pretty_generate(catalogue)
    )
  }
end
```

Then I run:

~~~ text
$ bundle exec rake spec
~~~

And the catalog is written to catalogs/ntp.before.json.

### Running the script

Running the script is easy:

~~~ text
$ create_specs.rb -c catalogs/ntp.before.json -o spec/classes/init_spec.rb
Writing out as spec/classes/init_spec.rb
~~~

After running the script, I find that it has overwritten the init_spec.rb with an updated version containing the auto-generated Rspec-puppet tests:

```ruby
require 'spec_helper'

describe 'ntp' do
  let(:params) do
    {
      "servers" => [
        "0.au.pool.ntp.org",
        "1.au.pool.ntp.org",
        "2.au.pool.ntp.org",
        "3.au.pool.ntp.org"
      ]
    }
  end

  it {
    is_expected.to contain_package('ntp').with({
      'ensure' => 'installed',
    })
  }

  it {
    is_expected.to contain_file('/etc/ntp.conf').with({
      'require' => 'Package[ntp]',
    })
  }

  [

"driftfile /var/lib/ntp/drift
restrict default kod nomodify notrap nopeer noquery
restrict 127.0.0.1
server 0.au.pool.ntp.org
server 1.au.pool.ntp.org
server 2.au.pool.ntp.org
server 3.au.pool.ntp.org
includefile /etc/ntp/crypto/pw
keys /etc/ntp/keys
",

  ].map{|k| k.split("\n")}.each do |text|

    it {
      verify_contents(catalogue, '/etc/ntp.conf', text)
    }
  end

  it {
    is_expected.to contain_service('ntp').with({
      'ensure' => 'running',
      'enable' => 'true',
      'subscribe' => 'File[/etc/ntp.conf]',
    })
  }

  it {
    is_expected.to compile.with_all_deps
    File.write(
      'catalogs/ntp.json',
      PSON.pretty_generate(catalogue)
    )
  }
end
```

### Enable coverage report

I am going to also manually add a line at the end of init_spec.rb to enable Rspec-puppet’s code coverage report:

```ruby
at_exit { RSpec::Puppet::Coverage.report! }
```

### Run the tests again

Next, I run the tests again to prove that create_specs really has created passing tests:

~~~ text
$ bundle exec rake spec
/System/Library/Frameworks/Ruby.framework/Versions/2.0/usr/bin/ruby -I/Library/Ruby/Gems/2.0.0/gems/rspec-core-3.6.0/lib:/Library/Ruby/Gems/2.0.0/gems/rspec-support-3.6.0/lib /Library/Ruby/Gems/2.0.0/gems/rspec-core-3.6.0/exe/rspec --pattern spec/\{aliases,classes,defines,unit,functions,hosts,integration,type_aliases,types\}/\*\*/\*_spec.rb --color

ntp
  should contain Package[ntp] with ensure => "installed"
  should contain File[/etc/ntp.conf] with require => "Package[ntp]"
  should contain exactly "driftfile /var/lib/ntp/drift", "restrict default kod nomodify notrap nopeer noquery", "restrict 127.0.0.1 ", "server 0.au.pool.ntp.org", "server 1.au.pool.ntp.org", "server 2.au.pool.ntp.org", "server 3.au.pool.ntp.org", "includefile /etc/ntp/crypto/pw", and "keys /etc/ntp/keys"
  should contain Service[ntp] with ensure => "running", enable => "true" and subscribe => "File[/etc/ntp.conf]"
  should compile into a catalogue without dependency cycles

Finished in 2.58 seconds (files took 1.15 seconds to load)
5 examples, 0 failures


Total resources:   3
Touched resources: 3
Resource coverage: 100.00%
~~~

## Under the hood

So, what just happened?

The create_specs.rb script is quite simple. It reads in a catalog, which, of course, is just a JSON document; it deletes all of the “scaffolding” if you like (the classes, anchors, stages etc. that relate to the catalog and Puppet manifests rather than the system itself); it extracts the parameters that were passed to the Class; and, finally, all of what is left is written out again, formatted as executable Rspec-puppet test code.

It is very useful if you inherit a Puppet module that has no tests; and of course it is useful in migrations, Puppet upgrades, and refactoring.

Finally, note that we achieved 100% resource coverage, as we would expect.

Let us continue.

## Refactoring task

The hypothetical refactoring task is to split the module into separate classes, ntp::install, ntp::configure, ntp::service and ntp::params.

However, in order to simulate a real refactoring task, I deliberately inserted a bug as well. It is a bug that will not break compilation, but it will stop Puppet from running. The reader may choose to spend a moment trying to find the bug before continuing.

```puppet
# init.pp

class ntp (
  Array[String] $servers = $ntp::params::servers,
) inherits ntp::params {
  contain ntp::install
  contain ntp::configure
  contain ntp::service

  Class['ntp::install']
  -> Class['ntp::configure']
  ~> Class['ntp::service']
}
```

```puppet
# install.pp

class ntp::install {
  package { 'ntp':
    ensure => installed,
  }
}
```

```puppet
# configure.pp

class ntp::configure (
  Array[String] $servers = $ntp::servers,
) {
  file { '/etc/ntp.conf':
    ensure  => file,
    content => template("${module_name}/ntp.conf.erb"),
  }
}
```

```puppet
# service.pp

class ntp::service {
 service { 'ntpd':
    ensure => running,
    enable => true,
  }
}
```

```puppet
# params.pp

class ntp::params {
  $servers = [
    '0.au.pool.ntp.org',
    '1.au.pool.ntp.org',
    '2.au.pool.ntp.org',
    '3.au.pool.ntp.org',
  ]
}
```

### Running the tests again

After refactoring, I run the tests again. Here is what I see this time:

~~~ text
$ bundle exec rake spec
/System/Library/Frameworks/Ruby.framework/Versions/2.0/usr/bin/ruby -I/Library/Ruby/Gems/2.0.0/gems/rspec-core-3.6.0/lib:/Library/Ruby/Gems/2.0.0/gems/rspec-support-3.6.0/lib /Library/Ruby/Gems/2.0.0/gems/rspec-core-3.6.0/exe/rspec --pattern spec/\{aliases,classes,defines,unit,functions,hosts,integration,type_aliases,types\}/\*\*/\*_spec.rb --color

ntp
  should contain Package[ntp] with ensure => "installed"
  should contain File[/etc/ntp.conf] with require => "Package[ntp]" (FAILED - 1)
  should contain exactly "driftfile /var/lib/ntp/drift", "restrict default kod nomodify notrap nopeer noquery", "restrict 127.0.0.1 ", "server 0.au.pool.ntp.org", "server 1.au.pool.ntp.org", "server 2.au.pool.ntp.org", "server 3.au.pool.ntp.org", "includefile /etc/ntp/crypto/pw", and "keys /etc/ntp/keys"
  should contain Service[ntp] with ensure => "running", enable => "true" and subscribe => "File[/etc/ntp.conf]" (FAILED - 2)
  should compile into a catalogue without dependency cycles

Failures:

  1) ntp should contain File[/etc/ntp.conf] with require => "Package[ntp]"
     Failure/Error:
       is_expected.to contain_file('/etc/ntp.conf').with({
         'require' => 'Package[ntp]',
       })

       expected that the catalogue would contain File[/etc/ntp.conf] with require set to "Package[ntp]" but it is set to nil
     # ./spec/classes/init_spec.rb:23:in `block (2 levels) in <top (required)>'

  2) ntp should contain Service[ntp] with ensure => "running", enable => "true" and subscribe => "File[/etc/ntp.conf]"
     Failure/Error:
       is_expected.to contain_service('ntp').with({
         'ensure' => 'running',
         'enable' => 'true',
         'subscribe' => 'File[/etc/ntp.conf]',
       })

       expected that the catalogue would contain Service[ntp]
     # ./spec/classes/init_spec.rb:49:in `block (2 levels) in <top (required)>'

Finished in 2.34 seconds (files took 1.03 seconds to load)
5 examples, 2 failures

Failed examples:

rspec ./spec/classes/init_spec.rb:22 # ntp should contain File[/etc/ntp.conf] with require => "Package[ntp]"
rspec ./spec/classes/init_spec.rb:48 # ntp should contain Service[ntp] with ensure => "running", enable => "true" and subscribe => "File[/etc/ntp.conf]"


Total resources:   6
Touched resources: 2
Resource coverage: 33.33%
Untouched resources:

  Class[Ntp::Configure]
  Class[Ntp::Install]
  Class[Ntp::Service]
  Service[ntpd]
/System/Library/Frameworks/Ruby.framework/Versions/2.0/usr/bin/ruby -I/Library/Ruby/Gems/2.0.0/gems/rspec-core-3.6.0/lib:/Library/Ruby/Gems/2.0.0/gems/rspec-support-3.6.0/lib /Library/Ruby/Gems/2.0.0/gems/rspec-core-3.6.0/exe/rspec --pattern spec/\{aliases,classes,defines,unit,functions,hosts,integration,type_aliases,types\}/\*\*/\*_spec.rb --color failed
~~~

So there are two test failures:

~~~ text
It was expected that File[/etc/ntp.conf] would require Package[ntp].
It was expected that the catalog would contain Service[ntp].
~~~

The first failure is a good failure. I wanted that to change, and I will now update my tests. Instead of expecting File[/etc/ntp.conf] to require Package[ntp], I expect instead for relationships to exist at the class level. So I add a new test:

```ruby
it 'classes and their relationships' do
  is_expected.to contain_class('ntp::install').with({'before' => ['Class[Ntp::Configure]']})
  is_expected.to contain_class('ntp::configure').with({'notify' => ['Class[Ntp::Service]']})
  is_expected.to contain_class('ntp::service')
end
```

And I change the package test to:

```ruby
it {
  is_expected.to contain_file('/etc/ntp.conf')
}
```

The second failure is a bad failure. I actually introduced a bug in the refactoring, by changing the name of the service from ntp to ntpd. I fix that by fixing the service class:

~~~ diff
$ git diff manifests/service.pp
diff --git a/manifests/service.pp b/manifests/service.pp
index 8b9fdbd..66367fd 100644
--- a/manifests/service.pp
+++ b/manifests/service.pp
@@ -1,5 +1,5 @@
 class ntp::service {
- service { 'ntpd':
+ service { 'ntp':
     ensure    => running,
     enable    => true,
   }
~~~

Finally, I run the tests and everything passes now:

~~~ text
$ bundle exec rake spec
/System/Library/Frameworks/Ruby.framework/Versions/2.0/usr/bin/ruby -I/Library/Ruby/Gems/2.0.0/gems/rspec-core-3.6.0/lib:/Library/Ruby/Gems/2.0.0/gems/rspec-support-3.6.0/lib /Library/Ruby/Gems/2.0.0/gems/rspec-core-3.6.0/exe/rspec --pattern spec/\{aliases,classes,defines,unit,functions,hosts,integration,type_aliases,types\}/\*\*/\*_spec.rb --color

ntp
  should contain Package[ntp] with ensure => "installed"
  should contain File[/etc/ntp.conf]
  should contain exactly "driftfile /var/lib/ntp/drift", "restrict default kod nomodify notrap nopeer noquery", "restrict 127.0.0.1 ", "server 0.au.pool.ntp.org", "server 1.au.pool.ntp.org", "server 2.au.pool.ntp.org", "server 3.au.pool.ntp.org", "includefile /etc/ntp/crypto/pw", and "keys /etc/ntp/keys"
  should contain Service[ntp] with ensure => "running" and enable => "true"
  classes and their relationships
  should compile into a catalogue without dependency cycles

Finished in 2.17 seconds (files took 0.98512 seconds to load)
6 examples, 0 failures


Total resources:   6
Touched resources: 6
Resource coverage: 100.00%
~~~

I am back to 100% passing tests and 100% resource coverage. I feel 100% certain that my refactoring has not broken anything, and there is no need for me to perform time-expensive testing, like spinning Vagrant instances etc. The tests ran in only 2.17 seconds. In fact, the most time expensive part of the whole procedure was refactoring the code itself.

This is an excellent outcome, because only if refactoring can be done quickly – and safely! – can developers realistically be expected to do it at all, and without refactoring, there can be no continuous improvement.

Questions and feedback in the comments most welcome!

_After writing this it was pointed out to me that Corey Osman has written another tool that auto-generates Rspec code called [Retrospec](https://github.com/nwops/puppet-retrospec), which is also worth having a look at._
