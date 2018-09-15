---
layout: post
title: "Setting up Puppet module testing from scratch&#58 Part II, Beaker for module testing"
date: 2016-05-13
author: Alex Harvey
tags: puppet rspec beaker
---

In the previous post I covered the puppetlabs_spec_helper, a kind of front-end to a bunch of tools including puppet-syntax, puppet-lint, and rspec-puppet.

Today I will be looking at how to set up the Beaker framework for module testing. Beaker is the Puppet community’s preferred acceptance test harness.

Before proceeding, I must call out some of the materials that I found useful when I learnt Beaker, especially Liam J. Bennett’s three part series, [Testing puppet with Beaker](http://tech.opentable.co.uk/blog/2014/04/04/testing-puppet-with-beaker/), [Part 2: the Windows Story](http://tech.opentable.co.uk/blog/2014/09/01/testing-puppet-with-beaker-pt-dot-2-the-windows-story/), and [Part 3: testing roles](http://tech.opentable.co.uk/blog/2014/09/01/testing-puppet-with-beaker-pt-dot-3-testing-roles/).  There is also a great 1-hour presentation by Puppet’s David Schmidt online [here](https://www.youtube.com/watch?v=GgNrxLfoDF8), which covers a lot of the material we look at in this post and in the previous post (the Beaker-related material starts at around 40 minutes).

Once again, my focus is on helping new people to quickly stand up the Beaker framework, while assuming as little as possible by way of Ruby and any other prior knowledge; I am less concerned about writing a proper tutorial on writing Beaker and Serverspec tests.  And as before, I use the real life example throughout of the Spacewalk module we are developing.

Let’s dive right into it.

* Table of Contents
{:toc}

## Installing and configiuring Beaker

### Prerequisites

To get started, we’ll need to ensure we have our prerequisites installed. In addition to Ruby Gems and Bundler, which were discussed in Part I, we’ll also need to install Vagrant.  I assume that my readers have used Vagrant before; if not, it’s well worth spending 15 minutes doing the Vagrant tutorial.

Otherwise, let’s continue.

### Gemfile additions

As we discussed in Part I, the Gemfile is a file that specifies Ruby dependencies to be installed in our ‘bundle’ by Bundler, a Ruby app that manages dependencies in Ruby projects.

To install Beaker, we will add a new system testing Gem group to the Gemfile:

~~~ ruby
group :system_tests do
  gem 'beaker',        :require => false
  gem 'beaker-rspec',  :require => false
  gem 'beaker-puppet_install_helper', :require => false
end
~~~

The complete file becomes:

~~~ ruby
source 'https://rubygems.org'

group :tests do
  gem 'puppetlabs_spec_helper', :require => false
end

group :system_tests do
  gem 'beaker',       :require => false
  gem 'beaker-rspec', :require => false
  gem 'beaker-puppet_install_helper', :require => false
end

gem 'facter'
gem 'puppet'
~~~

To understand these additions, be aware that Beaker really has two parts, Beaker itself, and Beaker-rspec, a shim that connects Beaker to Rspec and Serverspec.  Meanwhile, the beaker-puppet_install_helper is a helper library that takes care of installing Puppet in all of its various open source and PE versions.

If you are wondering why we add a Gem group :system_tests distinct from the :tests Gem group, this is mainly so that our Travis CI build system, which we discuss in Part III, won’t need to install all the system test related Gems (unless it is going to actually run the system tests, which is often not the case).

Having updated our Gemfile, we proceed to update our Bundle:

~~~ text
$ bundle update
Fetching gem metadata from https://rubygems.org/..........
Fetching version metadata from https://rubygems.org/..
Resolving dependencies.....
Using rake 11.1.2
Using CFPropertyList 2.2.8
Installing addressable 2.4.0
Installing json 1.8.3 with native extensions
Installing mini_portile2 2.0.0
Installing nokogiri 1.6.7.2 with native extensions
Installing aws-sdk-v1 1.66.0
Installing aws-sdk 1.66.0
Installing require_all 1.3.3
Installing stringify-hash 0.0.2
Installing beaker-answers 0.4.3
Installing beaker-hiera 0.1.1
Installing beaker-pe 0.1.2
Installing excon 0.49.0
Installing docker-api 1.28.0
Installing fission 0.5.0
Installing builder 3.2.2
Installing formatador 0.2.5
Installing fog-core 1.38.0
Installing fog-xml 0.1.2
Installing fog-atmos 0.1.0
Installing multi_json 1.12.0
Installing fog-json 1.0.2
Installing ipaddress 0.8.3
Installing fog-aws 0.9.2
Installing inflecto 0.0.2
Installing fog-brightbox 0.10.1
Installing fog-dynect 0.0.3
Installing fog-ecloud 0.3.0
Installing fog-google 0.0.9
Installing fog-local 0.3.0
Installing fog-powerdns 0.1.1
Installing fog-profitbricks 0.0.5
Installing fog-radosgw 0.0.5
Installing fog-riakcs 0.1.0
Installing fog-sakuracloud 1.7.5
Installing fog-serverlove 0.1.2
Installing fog-softlayer 1.1.1
Installing fog-storm_on_demand 0.1.1
Installing fog-terremark 0.1.0
Installing fog-vmfusion 0.1.0
Installing fog-voxel 0.1.0
Installing fog 1.34.0
Installing multipart-post 2.0.0
Installing faraday 0.9.2
Installing jwt 1.5.4
Installing little-plugger 1.1.4
Installing logging 2.1.0
Installing memoist 0.14.0
Installing os 0.9.6
Installing signet 0.7.2
Installing googleauth 0.5.1
Installing httpclient 2.8.0
Installing hurley 0.2
Installing mime-types 2.99.1
Installing uber 0.0.15
Installing representable 2.3.0
Installing retriable 2.1.0
Installing thor 0.19.1
Installing google-api-client 0.9.4
Installing hocon 0.9.5
Installing inifile 2.0.2
Installing minitest 5.8.4
Installing net-ssh 2.9.4
Installing net-scp 1.2.1
Installing open_uri_redirections 0.2.1
Installing trollop 2.1.2
Installing rbvmomi 1.8.2
Installing rsync 1.0.9
Installing unf_ext 0.0.7.2 with native extensions
Installing unf 0.1.4
Installing beaker 2.41.0
Installing beaker-puppet_install_helper 0.4.4
Using rspec-support 3.4.1
Using rspec-core 3.4.4
Using diff-lcs 1.2.5
Using rspec-expectations 3.4.0
Using rspec-mocks 3.4.1
Using rspec 3.4.0
Installing rspec-its 1.2.0
Installing net-telnet 0.1.1
Installing sfl 2.2
Installing specinfra 2.57.2
Installing serverspec 2.34.0
Installing beaker-rspec 5.3.0
Using facter 2.4.6
Using json_pure 1.8.3
Using hiera 3.1.2
Using metaclass 0.0.4
Using mocha 1.1.0
Using puppet 4.4.2
Using puppet-lint 1.1.0
Using puppet-syntax 2.1.0
Using rspec-puppet 2.4.0
Using puppetlabs_spec_helper 1.1.1
Using bundler 1.10.5
Bundle updated!
~~~

As can be seen, there is a long list of dependencies.

### Adding the nodesets

Moving along, we’ll now need to add to our project some nodesets – YAML files that define platforms that we will test our modules on.

Firstly, we create a directory for them:

~~~ text
$ mkdir -p spec/acceptance/nodesets
~~~

And then we copy them from the moduleroot/spec/acceptance/nodesets directory of the ModuleSync project, which I assume we have checked out in the same directory as our project:

~~~ text
$ cp ../modulesync_config/moduleroot/spec/acceptance/nodesets/* spec/acceptance/nodesets/
$ ls -1 spec/acceptance/nodesets/
centos-511-x64.yml
centos-66-x64-pe.yml
centos-66-x64.yml
centos-72-x64.yml
debian-78-x64.yml
debian-82-x64.yml
default.yml
ubuntu-server-1204-x64.yml
ubuntu-server-1404-x64.yml
~~~

### Rakefile

#### The :beaker and :beaker_nodes tasks

You may have noticed in Part I of this series that the :beaker and :beaker_nodes tasks were placed in the list of Rake tasks by the puppetlabs_spec_helper. Well, the :beaker task will run all of the specs in spec/acceptance. I rarely use that one. The other one, :beaker_nodes, essentially just lists the files I have in the nodesets directory:

~~~ text
$ bundle exec rake beaker_nodes
centos-511-x64
centos-66-x64-pe
centos-66-x64
centos-72-x64
debian-78-x64
debian-82-x64
default
ubuntu-server-1204-x64
ubuntu-server-1404-x64
~~~

So, you’ll probably find that you don’t actually need the Beaker-related tasks from the puppetlabs_spec_helper, but it’s still good to know what they are.

So the take away point is, when configuring Beaker, you don’t really need to touch the Rakefile, and I’ve covered the config you might find in here in case you’re interested.

### The spec helper acceptance

The acceptance test spec helper file, however, is very important.

As we mentioned in Part I, the spec helper is a file that is used by convention to configure Rspec, and we will already be using that file to configure Rspec-puppet. So for Beaker, a special spec helper file is typically used to configure Beaker-rspec, and it lives at spec/spec_helper_acceptance.rb.

#### Digression: The Beaker docs

Before proceeding I’d like to note some important sources of Beaker documentation that will help in understanding the spec/spec_helper_acceptance.rb file.

- The README of Beaker-rspec, where an (at the time of writing, out of date) set up tutorial can be found there.
- The README of the Beaker-puppet_install_helper project.
- The Beaker DSL documentation, but don’t be intimidated by the Beaker DSL, as we’ll be using just a handful of these methods, and these are all discussed in the next subsection.

#### Beaker DSL methods

As the documentation linked above shows, the Beaker DSL provides a large number of helper methods and classes.  Of these, we will need just a few for our simple Spacewalk module:

- The copy_module_to method: Copies a module to the module path on the test system.
- The on method:  Runs arbitrary commands on the test system.
- The puppet method:  Runs puppet on the test system.

And of course, read the source code when all else fails!

#### The Beaker::Host object and the nodesets

It’s also important to be aware that the Beaker DSL makes available to Rspec an array named hosts that contains Beaker::Host objects, a.k.a. “systems under test” or SUTs. (Only follow the link if you know Ruby well.)

The SUTs themselves are initialised according to the HOSTS Hash in the nodesets files that we copied earlier. For example, our the CentOS 7 node set:

~~~ yaml
HOSTS:
  centos-72-x64:
    roles:
      - master
    platform: el-7-x86_64
    box: puppetlabs/centos-7.2-64-nocm
    hypervisor: vagrant
CONFIG:
  type: foss
~~~

There are two potential gotchas here:

Firstly, note that the keys of the HOSTS Hash in our node sets correspond to elements in a hosts Array in our spec helper.

Secondly, it is normal to have only a single host defined in the nodesets; you’ll only ever see multiple hosts in here in multi-node configurations that use Beaker DSL in multi-node configurations.

#### Puppet install helper

A perceptive reader may have noticed that the Beaker-rspec documentation includes an example spec helper that includes the following lines:

~~~ ruby
# Install Puppet on all hosts

hosts.each do |host|
  on host, install_puppet
end
~~~

Don’t do this, because we now have the Puppet install helper to do this for us, which not only installs Puppet, but also sorts out for us how to install all the various versions of Puppet. I’ll have more to say about this helper below. For now, just be aware that we’re going to replace the 4 lines above with a single line:

~~~ ruby
run_puppet_install_helper
~~~

#### Putting it all together

Ok, so we have all of the pieces we need, so here is the code for our spec/spec_helper_acceptance.rb:

~~~ ruby
require 'beaker-rspec'
require 'beaker/puppet_install_helper'

run_puppet_install_helper

RSpec.configure do |c|
  proj_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))

  c.formatter = :documentation

  c.before :suite do
    hosts.each do |host|
      copy_module_to(host, :source => proj_root, :module_name => 'spacewalk')
      on host, puppet('module install puppetlabs-stdlib'),
        {:acceptable_exit_codes => [0]}
    end
  end
end
~~~

So we require the beaker-rspec and beaker/puppet_install_helper, we run the install helper, then in our RSpec.configure block we define a variable for our project root directory, we configure RSpec’s output, and then declare a before :suite hook (set up code that is run once before all of our tests).

Notice that our hosts.each loops through the hosts, and then inside this loop we copy the module to the host and on that host we call puppet module install puppetlabs-stdlib.

Why loop through an array if we already know that it has only one element? Well, convention. We could equally refactor as:

~~~ ruby
c.before :suite do
  copy_module_to(hosts[0], :source => proj_root, :module_name => 'spacewalk')
  on hosts[0], puppet('module install puppetlabs-stdlib'),
    {:acceptable_exit_codes => [0]}
end
~~~

### A simple test case

The apply_manifest method and the test for idempotence
We finally arrive at the test case themselves.

Although my intention is not to write a tutorial on writing Beaker tests, I should mention in passing the apply_manifest method from the Beaker DSL, which is a wrapper around the puppet apply command.

Every suite of Beaker tests will at some point need to apply some Puppet manifest code, and it is typical for the first test case to apply a Puppet manifest using apply_manifest and passing it :catch_failures => true, and this will be followed by a second test case that applies the manifest again, and expects the exit code to be zero.

In the example of our Spacewalk module, we’ll write these test cases as:

~~~ ruby
require 'spec_helper_acceptance'

describe 'spacewalk::server' do
  let(:manifest) {
    <<-EOS
include spacewalk::server
EOS
  }
  it 'should apply without errors' do
    apply_manifest(manifest, :catch_failures => true)
  end

  it 'should apply a second time without changes' do
    @result = apply_manifest(manifest)
    expect(@result.exit_code).to be_zero
  end
end
~~~

#### Extending the test case with Serverspec

It’s likely that remainder of your test cases will use the Serverspec extensions, and as such I’d refer the reader to the Serverspec tutorial.

In the case of our Spacewalk module, we’ll expect that our server will be at minimum listening on ports 80 and 443. So we add to our describe two more:

~~~ ruby
describe port('80') do
  it { is_expected.to be_listening }
end

describe port('443') do
  it { is_expected.to be_listening }
end
~~~

### Running the tests

#### Specifying the Puppet version

Now, here’s a big gotcha. By default, the Puppet install helper will install the latest Puppet 3.x, and not the latest Puppet 4.x! At the time of writing, that means we’ll get Puppet 3.8.6 instead of Puppet 4.4.2.

And wham, followed by a second big gotcha: to set the Puppet version to Puppet 4.4.2, we need to understand that the environment variable $PUPPET_INSTALL_VERSION is overloaded when used in conjunction with $PUPPET_INSTALL_TYPE. It is explained here in the docs.

If you want to install Puppet 3.x, that’s easy: set $PUPPET_INSTALL_VERSION to the version you want, and ensure that $PUPPET_INSTALL_TYPE is unset. In other words:

~~~ text
$ export PUPPET_INSTALL_VERSION=3.3.2
$ bundle exec rake beaker
~~~

If you want to install Puppet 4.x, however, the $PUPPET_INSTALL_TYPE must be set to agent, and then $PUPPET_INSTALL_VERSION takes on a new meaning, as the version of the Puppet Agent. Thankfully there’s a matrix converting Puppet versions and Puppet Agent versions here. So if I want Puppet version 4.4.2, then I need Agent version 1.4.2. Confused yet?

So here goes:

~~~ text
$ export PUPPET_INSTALL_TYPE=agent
$ export PUPPET_INSTALL_VERSION=1.4.2  # Now denotes Puppet Agent version!!
$ bundle exec rake beaker
~~~

Phew.

#### Specifying the node set

Specifying the node set is much easier. Just set the variable $BEAKER_set to the node set:

~~~ text
$ export BEAKER_set=centos-72-x64
$ bundle exec rake beaker
~~~

If left unset, it will default to default (i.e. it will use whatever is specified in spec/acceptance/nodesets/default.yml.

#### Other important environment variables

Another important environment variable is $BEAKER_destroy. If you set this to no, the VM will not be destroyed after the test/s.

This is really useful for debugging, and perhaps the best part, your acceptance tests double as a convenient way of quickly spinning up a VM that is ready-configured by Puppet. So if I ever want a Spacewalk server to play with, I just run my spec test, and voila!

#### Understanding the output

I’ll need to truncate the output, as there will always be a lot of it.

To begin, Rspec is called, and it is quite common to call the rspec command directly:

~~~ text
$ bundle exec rspec spec/acceptance/spacewalk_server_spec.rb
~~~

At the time of writing, the latest version of Serverspec is emitting some warnings that I am not interested in:

~~~ text
/Users/alexharvey/git/puppet-spacewalk/.gems/ruby/2.0.0/gems/beaker-rspec-5.3.0/lib/beaker-rspec/helpers/serverspec.rb:43: warning: already initialized constant Module::VALID_OPTIONS_KEYS
/Users/alexharvey/git/puppet-spacewalk/.gems/ruby/2.0.0/gems/specinfra-2.57.2/lib/specinfra/configuration.rb:4: warning: previous definition of VALID_OPTIONS_KEYS was here
~~~

If you know how to silence these then feel free to let me know in the comments! One of the fun parts of working with Beaker is that the maintainers of Serverspec don’t allow us to raise issues, but will only accepts PRs that resolve the issues you’ve found, and I don’t have time right now.

Moving along:

~~~ text
Hypervisor for centos-72-x64 is vagrant
Beaker::Hypervisor, found some vagrant boxes to create
==> centos-72-x64: VM not created. Moving on...
created Vagrantfile for VagrantHost centos-72-x64
Bringing machine 'centos-72-x64' up with 'virtualbox' provider...
==> centos-72-x64: Importing base box 'puppetlabs/centos-7.2-64-nocm'...
Progress: 20%Progress: 30%Progress: 50%Progress: 70%Progress: 90%==> centos-72-x64: Mat
ching MAC address for NAT networking...
~~~

So the Beaker::Hypervisor is set to Vagrant, and calls out to Vagrant. Vagrant proceeds (in my case) to import the base box that is specified in spec/acceptance/nodesets/centos-72-x64.yml.

Note that when you run this the first time, the Vagrant box image will be downloaded from Hashicorp, and this will probably take a long time.

Beaker then runs vagrant init and vagrant up:

~~~ text
==> centos-72-x64: Checking if box 'puppetlabs/centos-7.2-64-nocm' is up to date...
==> centos-72-x64: A newer version of the box 'puppetlabs/centos-7.2-64-nocm' is available! You currently
==> centos-72-x64: have version '1.0.0'. The latest is version '1.0.1'. Run
==> centos-72-x64: `vagrant box update` to update.
==> centos-72-x64: Setting the name of the VM: defaultyml_centos-72-x64_1463064614268_
==> centos-72-x64: Clearing any previously set network interfaces...
==> centos-72-x64: Preparing network interfaces based on configuration...
    centos-72-x64: Adapter 1: nat
    centos-72-x64: Adapter 2: hostonly
==> centos-72-x64: Forwarding ports...
    centos-72-x64: 22 => 2222 (adapter 1)
==> centos-72-x64: Running 'pre-boot' VM customizations...
==> centos-72-x64: Booting VM...
==> centos-72-x64: Waiting for machine to boot. This may take a few minutes...
    centos-72-x64: SSH address: 127.0.0.1:2222
    centos-72-x64: SSH username: vagrant
    centos-72-x64: SSH auth method: private key
    centos-72-x64: Warning: Connection timeout. Retrying...
    centos-72-x64: Warning: Remote connection disconnect. Retrying...
==> centos-72-x64: Machine booted and ready!
==> centos-72-x64: Checking for guest additions in VM...
    centos-72-x64: The guest additions on this VM do not match the installed version of
    centos-72-x64: VirtualBox! In most cases this is fine, but in rare cases it can
    centos-72-x64: prevent things such as shared folders from working properly. If you see
    centos-72-x64: shared folder errors, please make sure the guest additions within the
    centos-72-x64: virtual machine match the version of VirtualBox you have installed on
    centos-72-x64: your host and reload your VM.
    centos-72-x64:
    centos-72-x64: Guest Additions Version: 4.3.22
    centos-72-x64: VirtualBox Version: 5.0
==> centos-72-x64: Setting hostname...
==> centos-72-x64: Configuring and enabling network interfaces...
==> centos-72-x64: Mounting shared folders...
    centos-72-x64: /vagrant => /Users/alexharvey/git/puppet-spacewalk/.vagrant/beaker_vagrant_files/default.yml
~~~

Now I’m going to truncate a bunch of output, as Beaker sets up SSH keys; configures the /etc/hosts file; reconfigures the SSH daemon; and a bunch of other stuff, before it comes around to installing Puppet:

~~~ text
centos-72-x64 01:48:27$ rpm --replacepkgs -Uvh http://yum.puppetlabs.com/puppetlabs-release-el-7.noarch.rpm
  Retrieving http://yum.puppetlabs.com/puppetlabs-release-el-7.noarch.rpm
  Preparing...                          ########################################
  Updating / installing...
  puppetlabs-release-7-12               ########################################
  warning: /var/tmp/rpm-tmp.bKzxg4: Header V4 RSA/SHA1 Signature, key ID 4bd6ec30: NOKEY
~~~

So as mentioned, it’s installing Puppet 3.8.6 by default, which is fine for my purposes.

A bit later we see Beaker copy the modules across and install stdlib with the Puppet module tool:

~~~ text
centos-72-x64 01:48:48$ echo /etc/puppet/modules
  /etc/puppet/modules

centos-72-x64 executed in 0.01 seconds
Using scp to transfer /Users/alexharvey/git/puppet-spacewalk to /etc/puppet/modules/spacewalk
localhost $ scp /Users/alexharvey/git/puppet-spacewalk centos-72-x64:/etc/puppet/modules {:ignore => [".bundle", ".git", ".idea", ".vagrant", ".vendor", "vendor", "acceptance", "bundle", "spec", "tests", "log", ".", ".."]} going to ignore (?-mix:((\/|\A)\.bundle(\/|\z))|((\/|\A)\.git(\/|\z))|((\/|\A)\.idea(\/|\z))|((\/|\A)\.vagrant(\/|\z))|((\/|\A)\.vendor(\/|\z))|((\/|\A)vendor(\/|\z))|((\/|\A)acceptance(\/|\z))|((\/|\A)bundle(\/|\z))|((\/|\A)spec(\/|\z))|((\/|\A)tests(\/|\z))|((\/|\A)log(\/|\z))|((\/|\A)\.(\/|\z))|((\/|\A)\.\.(\/|\z)))

centos-72-x64 01:48:48$ rm -rf /etc/puppet/modules/spacewalk

centos-72-x64 executed in 0.01 seconds

centos-72-x64 01:48:48$ mv /etc/puppet/modules/puppet-spacewalk /etc/puppet/modules/sp
acewalk

centos-72-x64 executed in 0.01 seconds

centos-72-x64 01:48:48$ puppet module install puppetlabs-stdlib
  Notice: Preparing to install into /etc/puppet/modules ...
  Notice: Downloading from https://forgeapi.puppetlabs.com ...
  Notice: Installing -- do not interrupt ...
  /etc/puppet/modules
  └── puppetlabs-stdlib (v4.12.0)
~~~

… and then it hands over to Serverspec:

~~~ text
spacewalk::server
This is the documentation formatted output beginning our first test case. The puppet apply follows:

centos-72-x64 01:49:02$ mktemp -t apply_manifest.pp.XXXXXX
  /tmp/apply_manifest.pp.3g2lsP

centos-72-x64 executed in 0.01 seconds
localhost $ scp /var/folders/5d/4scjn6p131g6bvgspftw41580000gn/T/beaker20160513-41030-
10du1li centos-72-x64:/tmp/apply_manifest.pp.3g2lsP {:ignore => }

centos-72-x64 00:51:54$ puppet apply --verbose /tmp/apply_manifest.pp.445Tr4
  Info: Loading facts
  Notice: Compiled catalog for centos-72-x64.home in environment production in 0.23 se
conds
  Info: Applying configuration version '1463064714'
  Notice: /Stage[pre]/Spacewalk::Repos/Yumrepo[epel-testing-debuginfo]/ensure: created
  Info: changing mode of /etc/yum.repos.d/epel-testing-debuginfo.repo from 600 to 644
  Notice: /Stage[pre]/Spacewalk::Repos/Yumrepo[epel-source]/ensure: created
  Info: changing mode of /etc/yum.repos.d/epel-source.repo from 600 to 644
  Notice: /Stage[pre]/Spacewalk::Repos/Yumrepo[epel]/ensure: created
  Info: changing mode of /etc/yum.repos.d/epel.repo from 600 to 644
  Notice: /Stage[pre]/Spacewalk::Repos/Yumrepo[spacewalk-source]/ensure: created
  Info: changing mode of /etc/yum.repos.d/spacewalk-source.repo from 600 to 644
  Notice: /Stage[pre]/Spacewalk::Repos/Yumrepo[epel-testing-source]/ensure: created
  Info: changing mode of /etc/yum.repos.d/epel-testing-source.repo from 600 to 644
  Notice: /Stage[pre]/Spacewalk::Repos/Yumrepo[epel-debuginfo]/ensure: created
  Info: changing mode of /etc/yum.repos.d/epel-debuginfo.repo from 600 to 644
  Notice: /Stage[pre]/Spacewalk::Repos/Yumrepo[epel-testing]/ensure: created
  Info: changing mode of /etc/yum.repos.d/epel-testing.repo from 600 to 644
  Notice: /Stage[pre]/Spacewalk::Repos/Yumrepo[jpackage-generic]/ensure: created
  Info: changing mode of /etc/yum.repos.d/jpackage-generic.repo from 600 to 644
  Notice: /Stage[pre]/Spacewalk::Repos/Yumrepo[spacewalk-nightly]/ensure: created
  Info: changing mode of /etc/yum.repos.d/spacewalk-nightly.repo from 600 to 644
  Notice: /Stage[pre]/Spacewalk::Repos/Yumrepo[spacewalk]/ensure: created
  Info: changing mode of /etc/yum.repos.d/spacewalk.repo from 600 to 644
  Notice: /Stage[main]/Spacewalk::Server/File[/etc/sysconfig/spacewalk.answers]/ensure: defined content as '{md5}6dae2980336445ea8766bff9b0104a48'
  Notice: /Stage[main]/Spacewalk::Server/Package[spacewalk-setup-postgresql]/ensure: created
  Info: /Stage[main]/Spacewalk::Server/Package[spacewalk-setup-postgresql]: Scheduling refresh of Exec[spacewalk-setup]
  Notice: /Stage[main]/Spacewalk::Server/Package[spacewalk-postgresql]/ensure: created
  Info: /Stage[main]/Spacewalk::Server/Package[spacewalk-postgresql]: Scheduling refresh of Exec[spacewalk-setup]
  Notice: /Stage[main]/Spacewalk::Server/Exec[spacewalk-setup]: Triggered 'refresh' from 2 events
  Info: /Stage[main]/Spacewalk::Server/Exec[spacewalk-setup]: Scheduling refresh of Exec[enable-spacewalk-service]
  Notice: /Stage[main]/Spacewalk::Server/Exec[enable-spacewalk-service]: Triggered 'refresh' from 1 events
  Info: /Stage[main]/Spacewalk::Server/Exec[enable-spacewalk-service]: Scheduling refresh of Exec[start-spacewalk-service]
  Notice: /Stage[main]/Spacewalk::Server/Exec[start-spacewalk-service]: Triggered 'refresh' from 1 events
  Info: Creating state file /var/lib/puppet/state/state.yaml
  Notice: Finished catalog run in 722.84 seconds

centos-72-x64 executed in 722.85 seconds
Exited: 2
  should apply without errors
~~~

The line “should apply without errors” is the continuation of the Rspec documentation-formatted output, and it’s telling me that the test passed. (If it’s not telling you that yet, don’t worry; you’ll get used to Serverspec’s output format.)

And in passing, I’ll note it really did take 722 seconds and if you need or want to run these tests often, check out my post on how to speed up Beaker by running a SquidMan cache.

Moving along, we see our second test run, the test for idempotency:

~~~ text
centos-72-x64 02:01:50$ mktemp -t apply_manifest.pp.XXXXXX
  /tmp/apply_manifest.pp.jwMrvi

centos-72-x64 executed in 0.03 seconds
localhost $ scp /var/folders/5d/4scjn6p131g6bvgspftw41580000gn/T/beaker20160513-41030-ss45ek centos-72-x64:/tmp/apply_manifest.pp.jwMrvi {:ignore => }

centos-72-x64 02:01:51$ puppet apply --verbose /tmp/apply_manifest.pp.jwMrvi
  Info: Loading facts
  Notice: Compiled catalog for centos-72-x64.home in environment production in 0.30 seconds
  Info: Applying configuration version '1463068912'
  Notice: Finished catalog run in 0.12 seconds

centos-72-x64 executed in 2.74 seconds
  should apply a second time without changes
~~~

Next the test for port 80:

~~~ text
  Port "80"
  .
  .
  .  ## a lot of confusing output is truncated
centos-72-x64 executed in 0.01 seconds

centos-72-x64 02:01:54$ /bin/sh -c ss\ -tunl\ \|\ grep\ --\ :80\\\
  tcp    LISTEN     0      128      :::80                   :::*

centos-72-x64 executed in 0.09 seconds
    should be listening
~~~

And finally, I’ll skip to the bottom:

~~~ text
Finished in 13 minutes 6 seconds (files took 12 minutes 13 seconds to load)
4 examples, 0 failures
~~~

Rspec tells me that my 4 examples took 13 minutes and 6 seconds and all of them passed.

Well, that’s it for part II of the series.
