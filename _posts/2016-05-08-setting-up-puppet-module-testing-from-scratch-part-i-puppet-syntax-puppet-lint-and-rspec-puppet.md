---
layout: post
title: "Setting up Puppet module testing from scratch: Part I, Puppet-syntax, Puppet-lint and Rspec-puppet"
date: 2016-05-08
author: Alex Harvey
---

It was brought to my attention that there’s demand for a post on how to set up Beaker from scratch. Then, after looking into it, I realised there’s a case for a whole series on how to set up Puppet modules as well as Puppet roles & profiles for testing.

In this series I am going to look at setting up all of the following components for Puppet module testing: Puppetlabs_spec_helper, Puppet-syntax, Puppet-lint, and Rspec-puppet (this post); Beaker for modules (part II); Travis CI (part III), Puppet Blacksmith and additional set up required for publishing your module on the Forge (part IV); and using ModuleSync to keep all of this set up in sync when you support many modules or code bases (part V).

My aim is not to provide tutorials on how to write Rspec or Rspec-puppet or Beaker tests; there are many of those out there already. My focus is simply how to set up the various frameworks, assuming no prior knowledge from the reader.

* Table of contents
{:toc}

## Example module
By way of example, we will look at adding the testing of the puppet-spacewalk module that I have been working on.  As such, it is a real-life example.

## The puppetlabs_spec_helper
It makes sense to begin with the puppetlabs_spec_helper gem, a wrapper around quite a number of other tools, including:

- Puppet-syntax
- Puppet-lint
- Rspec-puppet
And many others.

### Prerequisites
To install and configure up the puppetlabs_spec_helper gem we need to firstly have RubyGems, and Bundler installed.  This is well-documented in the links provided.  Once these are installed you should find these commands in your path:

~~~ text
$ bundler -v
Bundler version 1.10.5
$ gem -v
2.0.14
~~~

### Gemfile
Assuming we have Bundler and Ruby Gems installed, we begin by specifying our Ruby Gem dependencies in a file called Gemfile. I am using boilerplate from the Gem config from ModuleSync, although I have simplified it considerably for users who aren’t interested in setting up the ModuleSync tool at this stage. We’ll be adding to it in subsequent posts.

For now, I include the bits we need just for Puppet-syntax, Puppet-lint, and Rspec-puppet:

~~~ ruby
source 'https://rubygems.org'

group :test do
  gem 'puppetlabs_spec_helper', :require => false
end

gem 'facter'
gem 'puppet'
~~~

As can be seen, we have a gem group :test, which installs just the puppetlabs_spec_helper.  We use gem groups so that developers and CI/CD systems can opt-out of some of these dependencies, since Gem installs are expensive.

Note that puppetlabs_spec_helper installs Rspec, Rspec-puppet, Puppet-lint, Puppet-syntax, and other dependencies. For now, I’ll note in passing that if you want to know more about this tool, start at the project’s README. And if you want to know more about why we add :require => false, try this page.

Once the Gemfile is set up, we install all the gems using Bundler:

~~~ text
$ bundle install
Fetching gem metadata from https://rubygems.org/..........
Fetching version metadata from https://rubygems.org/..
Resolving dependencies...
Installing rake 11.1.2
Installing CFPropertyList 2.2.8
Installing diff-lcs 1.2.5
Installing facter 2.4.6
Installing json_pure 1.8.3
Installing hiera 3.1.2
Installing metaclass 0.0.4
Installing mocha 1.1.0
Installing puppet 4.4.2
Installing puppet-lint 1.1.0
Installing puppet-syntax 2.1.0
Installing rspec-support 3.4.1
Installing rspec-core 3.4.4
Installing rspec-expectations 3.4.0
Installing rspec-mocks 3.4.1
Installing rspec 3.4.0
Installing rspec-puppet 2.4.0
Installing puppetlabs_spec_helper 1.1.1
Using bundler 1.10.5
Bundle complete! 3 Gemfile dependencies, 19 gems now installed.
~~~

You will note that a file Gemfile.lock has been created. You may or may not choose to add this file to .gitignore to stop it from being saved in Git. If you intend to keep up to date with upstream in all of these tools (recommended), then git-ignore it.

### Rakefile
For the moment, we’ll need a simple Rakefile, that will contain just a single line:

~~~ ruby
require 'puppetlabs_spec_helper/rake_tasks'
~~~

Rake is a Make-like tool for Ruby, and we will use it to run our Lint and Rspec tests, which is the convention. As is probably clear enough, this single line pulls in the standard selection of Rake tasks from the puppetlabs_spec_helper. To see them all:

~~~ text
$ bundle exec rake -T
rake beaker                # Run beaker acceptance tests
rake beaker_nodes          # List available beaker nodesets
rake build                 # Build puppet module package
rake check:dot_underscore  # Fails if any ._ files are present in directory
rake check:git_ignore      # Fails if directories contain the files specified in
  .gitignore
rake check:symlinks        # Fails if symlinks are present in directory
rake check:test_file       # Fails if .pp files present in tests folder
rake clean                 # Clean a built module package
rake compute_dev_version   # Print development version of module
rake coverage              # Generate code coverage information
rake help                  # Display the list of available rake tasks
rake lint                  # Run puppet-lint
rake release_checks        # Runs all nessesary checks on a module in preparation for
  a release
rake spec                  # Run spec tests in a clean fixtures directory
rake spec_clean            # Clean up the fixtures directory
rake spec_prep             # Create the fixtures directory
rake spec_standalone       # Run spec tests on an existing fixtures directory
rake syntax                # Syntax check Puppet manifests and templates
rake syntax:hiera          # Syntax check Hiera config files
rake syntax:manifests      # Syntax check Puppet manifests
rake syntax:templates      # Syntax check Puppet templates
rake validate              # Check syntax of Ruby files and call :syntax and
  :metadata_lint
~~~
Of these, we’ll be discussing :validate, :lint, :spec, :spec_clean, and :spec_prep today.

But for now, that’s it for the Rakefile.

### The validate task
The :validate task is a wrapper around puppet-syntax, metadata-json-lint, and adds syntax checking of Ruby files.  It calls :syntax task which checks Hiera files, Puppet manifests, and ERB files for syntax errors. In addition, it runs ruby -c against any *.rb files, and finally, if a metadata.json file is present, and if you have this gem mentioned in your Gemfile, it will also run the :metadata_lint task against that.  We will discuss the linting of the metadata.json in a subsequent post.

If all is well, only the :syntax task will generate output, which is a little misleading, but that’s normal. Here goes:

~~~ text
$ bundle exec rake validate
---> syntax:manifests
---> syntax:templates
---> syntax:hiera:yaml
~~~

### The lint task
Also ready-configured is Puppet Lint, a tool that checks your manifests against style guide recommendations. It’s likely, however, that you’ll need to fine-tune Lint to your own preferences. In the case of our Spacewalk module, we find one issue that we’d like to simply ignore:

~~~ text
$ bundle exec rake lint
manifests/params.pp - ERROR: two-space soft tabs not used on line 7
~~~

That’s because I have some code:

~~~ puppet
  unless ($::operatingsystemmajrelease == '6') or
         ($::operatingsystemmajrelease == '7') {
    fail("module not supported for operatingsystemmajrelease ${::operatingsystemmajrelease}")
  }
~~~

I don’t want to “fix” this because I like it this way. To disable one check I’ll need to add some Lint config to my Rakefile, in fact one line:

~~~ ruby
require 'puppetlabs_spec_helper/rake_tasks'
PuppetLint.configuration.send('disable_2sp_soft_tabs')
~~~

To find the string 2sp_soft_tabs I simply grepped the Lint code for the string ‘two-space soft tabs not used’. There may be a better way.

(Rob Nelson has helpfully informed me that it’s possible to disable Lint checks for sections of code without disabling them globally using control comments. My feeling is that most people will not want to have Lint-related control comments in their code, but it’s still useful to be aware that this feature exists.)

For more information on configuring Lint, see the project’s README.

Also, be aware that at the time of writing, the Lint gem hasn’t been released in a long time, so it’s possible that the README is ahead of the released Gem.

If you can’t wait for the next Gem release, and you need the recent fixes in Lint, you can add to your Gemfile:

~~~ ruby
gem 'puppet-lint', :git => 'https://github.com/rodjek/puppet-lint.git'
~~~

### The spec task
The :spec task is used to run the Rspec and Rspec-puppet tests, so we now proceed to additional configuration required for Rspec-puppet.

It’s also useful to have a quick look at the source code for the :spec in lib/puppetlabs_spec_helper/rake_tasks.rb:

~~~ ruby
desc "Run spec tests in a clean fixtures directory"
task :spec do
  Rake::Task[:spec_prep].invoke
  Rake::Task[:spec_standalone].invoke
  Rake::Task[:spec_clean].invoke
end
~~~
So :spec is just a wrapper around three other tasks; it just calls :spec_prep (next subsection), then :spec_standalone task does the actual work, and then :spec_clean is called to cleanup again.

#### .fixtures.yml and the spec_prep task
In order for Rspec-puppet to find the module code and module dependencies, a file .fixtures.yml is used by the :spec_prep task to populate the spec/fixtures/module directory.

To understand how this file works, consult the puppetlabs_spec_helper README, and also have a look in lib/puppetlabs_spec_helper/rake_tasks.rb.

In the example of our Spacewalk module, and like many other modules, our only dependency will be the puppetlabs/stdlib module, and we’ll need to have a symbolic link back to the module root. To achieve this:

~~~ yaml
fixtures:
  repositories:
    stdlib:
      repo: https://github.com/puppetlabs/puppetlabs-stdlib.git
  symlinks:
    spacewalk: "#{source_dir}"
~~~

Having set that up, we can test it using the :spec_prep and :spec_clean tasks. To pull in the modules specified in the repositories section and create the symbolic links:

~~~ text
$ bundle exec rake spec_prep
Cloning into 'spec/fixtures/modules/stdlib'...
remote: Counting objects: 453, done.
remote: Compressing objects: 100% (314/314), done.
remote: Total 453 (delta 140), reused 358 (delta 124), pack-reused 0
Receiving objects: 100% (453/453), 204.80 KiB | 63.00 KiB/s, done.
Resolving deltas: 100% (140/140), done.
Checking connectivity... done.
~~~
This takes a little while, as the git clone is always expensive. And after it finishes:

~~~ text
$ ls -l spec/fixtures/modules/
total 8
lrwxr-xr-x   1 alexharvey  staff   38  8 May 00:32 spacewalk@ ->
  /Users/alexharvey/git/puppet-spacewalk
drwxr-xr-x  25 alexharvey  staff  850  8 May 00:32 stdlib/
~~~
Rspec will now be able to find the spacewalk and stdlib modules in spec/fixtures/modules.

To clean up this directory again:

~~~ text
$ bundle exec rake spec_clean
~~~
#### The spec directory tree
We now need to create our spec directory tree:

~~~ text
$ mkdir -p spec/classes
~~~

And we will add some additional subdirectories later.

#### The spec helper
Next, we create a spec helper, a file used to configure Rspec for the tests. By convention, this file should be named spec/spec_helper.rb, although you could call it whatever you like so long as your specs require it.

In our simple Spacewalk example we have the following content in here:

~~~ ruby
require 'puppetlabs_spec_helper/module_spec_helper'

RSpec.configure do |c|
  c.default_facts = {
    :osfamily => 'RedHat',
    :operatingsystemmajrelease => '7',
  }
end
~~~

By requiring puppetlabs_spec_helper/module_spec_helper, we have pulled in some default Rspec configuration appropriate for Rspec-puppet.  To understand better, have a look at the code.

The only custom config I need is specified in an RSpec.configure block, and for the moment, that means I just happen to want some default facts specified, which will apply to all of the Rspec-puppet tests.

##### A note about old config in spec helper
Be aware that many modules in the Forge, and even supported and approved modules, have configuration in here along the lines of:

~~~ ruby
require 'rspec-puppet'

fixture_path = File.expand_path(File.join(__FILE__, '..', 'fixtures'))

RSpec.configure do |c|
  c.module_path = File.join(fixture_path, 'modules')
  c.manifest_dir = File.join(fixture_path, 'manifests')
end
~~~
This comes from old incarnations of this stack, and perhaps from the rspec-puppet setup documentation, which at the time writing, hasn’t been updated in years. While it’s not a big deal, it is best to ignore the rspec-puppet set up documentation, and be aware that many modules have config in here that isn’t required.

#### The .rspec file
Another file you may or may not want is .rspec. This file contains options that are passed to the rspec command line. In earlier versions of rspec, this file was at spec/spec.opts. In the latest versions of rspec, spec/spec.opts is completely ignored.

Typically, the .rspec is used just to enable colouring, and sometimes to configure Rspec’s output format:

~~~ text
--color
--format documentation
~~~
Equally, we could move this to the RSpec.configure block in the spec helper:

~~~ ruby
require 'puppetlabs_spec_helper/module_spec_helper'

RSpec.configure do |c|
  c.color  = true
  c.format = :documentation
  c.default_facts = {
    :osfamily => 'RedHat',
    :operatingsystemmajrelease => '7',
  }
end
~~~

Personally, I prefer to have one less file, so I’ll put it in the spec helper.

#### The simplest test case
Finally I’ll create one simple test case, namely a test to prove that my Spacewalk class when declared compiles fine.  Of course, if module testing is your aim, you will normally have a number of Rspec-puppet tests.

~~~ ruby
require 'spec_helper'

describe 'spacewalk::server' do
  it { is_expected.to compile.with_all_deps }
end
~~~
#### Running the tests
To run this test:

~~~ text
$ bundle exec rake spec
Cloning into 'spec/fixtures/modules/stdlib'...
remote: Counting objects: 453, done.
remote: Compressing objects: 100% (314/314), done.
remote: Total 453 (delta 140), reused 358 (delta 124), pack-reused 0
Receiving objects: 100% (453/453), 204.80 KiB | 185.00 KiB/s, done.
Resolving deltas: 100% (140/140), done.
Checking connectivity... done.
/System/Library/Frameworks/Ruby.framework/Versions/2.0/usr/bin/ruby -I/Users/alexharvey/git/puppet-spacewalk/.gems/ruby/2.0.0/gems/rspec-core-3.4.4/lib:/Users/alexharvey/git/puppet-spacewalk/.gems/ruby/2.0.0/gems/rspec-support-3.4.1/lib /Users/alexharvey/git/puppet-spacewalk/.gems/ruby/2.0.0/gems/rspec-core-3.4.4/exe/rspec --pattern spec/{classes,defines,unit,functions,hosts,integration,types\}/\*\*/\*_spec.rb --color
.

Finished in 3.23 seconds (files took 1.19 seconds to load)
1 example, 0 failures
~~~
## Conclusion
We have so far covered the puppetlabs_spec_helper, and the Rake tasks that it adds, :validate, :lint, and :spec, and in so doing have covered the gem projects puppet-syntax, puppet-lint, and rspec-puppet, and a minimal configuration for each. In the next part, we will expand on this to add Beaker testing for our modules.
