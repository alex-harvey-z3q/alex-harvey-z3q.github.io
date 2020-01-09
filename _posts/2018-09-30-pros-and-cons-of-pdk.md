---
layout: post
title: "The pros and cons of Puppet PDK"
date: 2018-09-30
author: Alex Harvey
category: puppet
tags: puppet pdk
---

It was about a year ago that Puppet released its Puppet Development Kit (PDK), to simplify and streamline the development of Puppet modules. This post investigates the pros and cons of using PDK compared to managing modules like any other Ruby project.

- ToC
{:toc}

## Example project

Suppose I have a simple "hello world" module:

~~~ puppet
class foo {
  notify { 'bar': }
}
~~~

And a unit test for it:

~~~ ruby
describe 'foo' do
  it { is.expected_to contain_notify('bar') }
end
~~~

How do I set up Rspec to run the test?

## Doing things the old way

### Setup files

#### .fixtures.yml

First, I need a simple `.fixtures.yml`:

~~~ yaml
fixtures:
  symlinks:
    foo: "#{source_dir}"
~~~

This is needed to create symbolic links in the fixtures directory, in order to ensure that Puppet can find both dependent modules and the code under test. This requirement is documented in the `puppetlabs_spec_heler` README.

#### .gitignore

I need to gitignore some files:

~~~ text
Gemfile.lock
spec/fixtures
~~~

It's necessary to gitignore the spec/fixtures directory so that Git won't see the temporary files used during testing. And gitignoring `Gemfile.lock` is a preference of mine, as I always want my tests to run against latest-everything. Not everyone would agree on that decision, and some people do revision control their Gemfile.locks.

#### Gemfile

The simplest Gemfile I use for Puppet testing is:

~~~ ruby
source 'https://rubygems.org'

group :tests do
  gem 'puppetlabs_spec_helper'
end

if puppetversion = ENV['PUPPET_GEM_VERSION']
  gem 'puppet', puppetversion
else
  gem 'puppet'
end
~~~

Note that I expect an optional environment variable there that allows me to test against different Puppet versions. This is important for modules I support on the Forge.

#### Rakefile

My simplest Rakefile contains these lines:

~~~ ruby
require 'puppetlabs_spec_helper/rake_tasks'
PuppetLint.configuration.send('disable_2sp_soft_tabs')
PuppetLint.configuration.send('disable_arrow_alignment')
PuppetLint.configuration.send('disable_variables_not_enclosed')
~~~

That just says to include the standard Rake tasks from puppetlabs_spec_helper, and sets up my linting preferences.

#### spec_helper.rb

Finally, my simplest spec helper is:

~~~ ruby
require 'puppetlabs_spec_helper/module_spec_helper'

RSpec.configure do |c|
  c.formatter = :documentation
  c.tty       = true
end
~~~

Again, I just include the default configuration from puppetlabs_spec_helper, set Rspec output to documentation mode; and tty true is a setting that's needed for colouring in build pipelines like Travis, Bitbucket etc.

### Running the tests

We run the tests using commands familiar to Ruby developers:

~~~ text
▶ bundle exec rake spec
I, [2018-10-02T20:44:19.368027 #72078]  INFO -- : Creating symlink from spec/fixtures/modules/foo to /Users/alexharvey/git/home/pdktest
/Users/alexharvey/.rvm/rubies/ruby-2.4.1/bin/ruby -I/Users/alexharvey/.rvm/gems/ruby-2.4.1/gems/rspec-core-3.8.0/lib:/Users/alexharvey/.rvm/gems/ruby-2.4.1/gems/rspec-
support-3.8.0/lib /Users/alexharvey/.rvm/gems/ruby-2.4.1/gems/rspec-core-3.8.0/exe/rspec --pattern spec/\{aliases,classes,defines,unit,functions,hosts,integration,plan
s,type_aliases,types\}/\*\*/\*_spec.rb --color

foo
  should contain Notify[bar]

Finished in 0.15346 seconds (files took 1.24 seconds to load)
1 example, 0 failures
~~~

### Other things

Okay, I simplified the problem a bit by focusing only on Rspec, didn't I. To fully set up module testing, I probably want all this running in a CI pipeline like Travis CI; I could want Rubocop; perhaps I need something like Beaker or Test Kitchen or equivalent; maybe I want Rspec-puppet-facts for multi-OS testing; if I intend to publish this on the Forge, I'll need metadata and probably Puppet-blacksmith.

For now, I'm just focusing on the pain-point I hear most often about, which is how to set up Rspec.

### Shared boilerplate problem

I should also mention what I'm calling the "shared boilerplate problem", a problem that has been solved in one way by [modulesync](https://github.com/voxpupuli/modulesync). This is the problem of how to keep these files like Gemfile, Rakefile etc in sync when you manage lots of projects that all need the same files.

I don't use modulesync as I found it too complicated, whereas I have preferred to write a very simple custom Ruby script which I called `sync_spec`.

Well, it definitely should be noted that PDK automatically solves this problem too.

## Doing things the new way

### pdk new module

The Puppet PDK automates generation of all the above boilerplate and much, much more. It's very easy to use too and has a nice user interface. I started by running the following command:

~~~ text
▶ pdk new module pdktest
~~~

Then I was asked four questions. My Forge username, which happened to be the same as my laptop username, so PDK guessed that correctly. Then my full name. The license I use. And the operating systems I wished to support. This led to the creation of:

~~~ text
17 files changed, 673 insertions(+)
~~~

And 17 files and 673 lines of code for free is either a lot of time saved or a lot of magic, depending how you look at it. On the other hand, to do what I had wanted I needed only 6 files and 30 lines of code. Still, it's certainly easy.

### pdk new class

Next, I created a class:

~~~ text
▶ pdk new class foo
pdk (INFO): Creating '/Users/alexharvey/git/home/pdktest/manifests/foo.pp' from template.
pdk (INFO): Creating '/Users/alexharvey/git/home/pdktest/spec/classes/foo_spec.rb' from template.
~~~

This created an empty foo class with documentation examples, and then an empty spec file with an assumption that I would use rspec-puppet-facts thrown in for free. That's fine, I can refactor that out.

### Running the tests

Then, PDK also magically ran the tests for me:

~~~ text
▶ pdk test unit
pdk (INFO): Using Ruby 2.4.4
pdk (INFO): Using Puppet 5.5.3
[✔] Preparing to run the unit tests.
[✔] Running unit tests.
  Evaluated 1 tests in 0.286737 seconds: 0 failures, 0 pending.
~~~

If I was new to Puppet and/or Ruby, I would have no idea what happened here. As it is, I assume that PDK actually ran all the Rspec tests for me. And hid all the output too! What if a test fails, I wondered. So I tried changed my Rspec assertion to something that would fail:

~~~ text
▶ pdk test unit
pdk (INFO): Using Ruby 2.4.4
pdk (INFO): Using Puppet 5.5.3
[✔] Preparing to run the unit tests.
[✖] Running unit tests.
  Evaluated 1 tests in 0.383444 seconds: 1 failures, 0 pending.
failed: rspec: ./spec/classes/foo_spec.rb:4: expected that the catalogue would not contain Notify[bar]
  foo should not contain Notify[bar]
  Failure/Error:

  describe 'foo' do
    it { is_expected.to_not contain_notify('bar') }
  end
~~~

That's pretty clever. PDK knows which bits of the Rspec output are important, and it's showing me only that.

### pdk convert

Another cool feature is `pdk convert`. I can go into any module that I maintain and in one command convert to the PDK way of doing things. For instance, my firewall_multi module:

~~~ text
▶ pdk convert

------------Files to be added-----------
appveyor.yml
.gitlab-ci.yml
.pdkignore
.yardopts
spec/default_facts.yml
.rubocop.yml

----------Files to be modified----------
metadata.json
spec/spec_helper.rb
Gemfile
.gitignore
.travis.yml
.rspec
Rakefile

----------------------------------------

You can find a report of differences in convert_report.txt.

pdk (INFO): Module conversion is a potentially destructive action. Ensure that you have committed your module to a version control system or have a backup, and review
the changes above before continuing.
Do you want to continue and make these changes to your module? Yes

------------Convert completed-----------

6 files added, 7 files modified.
~~~

And I found that nothing was broken and `pdk test unit` then ran all my tests.

Further inspection led me to realise that there are some improvements I can make in my `.travis.yml`, although I was inclined to reject all of the remainder of changes.

Still, it's an impressive tool.

## Discussion

### Advantages

PDK is an opinionated tool for setting up Rspec and a whole range of other Puppet development tools in the way that Puppet like it. I can see that it lowers the barrier to entry to a lot of automated testing and other best practices; it hides all the messy details of Ruby and Rspec, and replaces all that with a nice user experience. It is also supported by Puppet and the Puppet community, and it solves the shared Rspec boilerplate problem more cleanly than modulesync.

There are many, obvious reasons to use it. But there are also reasons to not use it.

### Disadvantages

#### Loss of control

PDK evidently works best if you accept its preferences and ways of doing things.

If, on the other hand, you have an opinionated module setup of your own, it will be necessary to use [pdk-templates](https://github.com/puppetlabs/pdk-templates), and I would expect that going in that direction leads quickly to a testing setup that is more complicated for novices and experts alike. And also, although I haven't delved into it yet, I expect that many features of the PDK-managed tools simply can't be used at all with PDK, and I expect that some PDK preferences can't be turned off.

#### Pollution of config

Another problem with PDK is that it pollutes your repos with nearly 700 lines of config, most of which aren't applicable to you. So, most users won't be using the AppVeyor or the Gitlab CI Runner for instance.

On the other hand, it is my belief that code should also be documentation and for code to be good documentation, superfluous config that is unused needs to be removed. PDK appears to make this impossible. As a consequence, someone reading and trying to understand the design of PDK-managed tests would at times not know which Rspec options the tests actually depended on.

#### Barrier to understanding

Success with Puppet requires the user to understand Ruby and Rspec. (No, it really does.) And the Ruby community has produced wonderful tools, including Bundler, Rake, Yard etc. As a Puppet developer, I want people in my team to know how to write Gemfiles and Rakefiles and so on by themselves. This knowledge is going to be crucial, sooner or later, even if only in the context of debugging.

Likewise, learning how to design and write good unit tests - and I mean with the full understanding of what you are doing and why, rather than those who are writing tests for the sake of it - is hard. Learning how to think of a piece of code as a unit, as a black or white box, and expressing its expected behaviour in Rspec is an art - a rewarding art too - and also the secret to the rapid development of infrastructure-as-code. But I don't believe in falsely raising expectations that this is, or that it should be, easy. Lawyers, doctors, engineers, and others have no such demand that their work should be easy, and neither should the infrastructure-as-code developer. It is as easy or as difficult as it needs to be, but no more or less.

#### Barrier to advanced testing

PDK also presents a barrier for advanced users who do testing that goes beyond what the engineers at Puppet currently do. For example, PDK gets in the way of the Rspec data testing pattern I advocate. What if I want to test that all file content representing JSON files inside Puppet catalogs is valid JSON? What if I want Bash shell scripts to be tested in shUnit2 or BATS?

PDK actually gets in the way and makes it it hard to do this.

#### Only solves sync for Puppet

For many, a solution to the shared boilerplate problem is likely to be a big reason to use PDK, but I believe that, in practice, most teams will eventually require a solution that handles both Puppet repos and other infrastructure-as-code repos that are unrelated to Puppet. If a site truly embraces infrastructure-as-code, it's likely that they will have Bash scripts, Ruby and Python apps, so on, and in my experience, these other projects also end up with shared boilerplate that needs to be managed. In the past, I have used my `sync_spec` solution for this too, and I would expect that most sites do something similar. And if not, they probably should.

### How I will use it

So, will I use PDK, and if so how?

The above may have caused the reader to assume that I am not going to use PDK at all, but that's not the case. Rather, I intend to use it to keep abreast of best practices from Puppet and the community by periodically comparing my code to changes recommended by `pdk convert`. It's also possible that I'll use pdk-generated code as a starting point for my modules, and edit away the bits I don't need.

And for most other users, too, this would be my recommended way of using PDK. Of course, I can understand why some groups - e.g. the VoxPopuli community - might choose to fully embrace the PDK way of doing things. And Puppet Enterprise customers may use PDK in order to be better supported by Puppet.

But for most teams who aren't already Ruby and Puppet power users, my recommendation is to do what I do.

## Conclusion

I have tried out PDK and written about my experiences with it. I argue that many teams should think carefully about whether they really want to fully embrace this tool's way of doing things, or if it's still better to learn the Ruby way. Meanwhile, I personally plan to use the tool as a convenient way to keep informed of best practices in Puppet.

## See also

For other views:

- Rob Nelson, [Convert a Puppet module from bundle-based testing to the Puppet Development Kit (PDK)](https://rnelson0.com/2018/06/08/convert-a-puppet-module-from-bundle-based-testing-to-the-puppet-development-kit-pdk/).
