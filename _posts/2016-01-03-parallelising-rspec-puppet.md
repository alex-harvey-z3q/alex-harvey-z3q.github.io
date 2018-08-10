---
layout: post
title: "Parallelising rspec-puppet"
date: 2016-01-03
author: Alex Harvey
tags: puppet rspec
---

I recently migrated a site away from Andrew Cunningham’s [puppet-validator](https://github.com/oldNoakes/puppet-validator) – an open source project that simply compiles catalogs based on configurable fact values – to rspec-puppet.

The advantages of rspec-puppet are many and, obviously, being able to do more than just compile catalogs is one advantage.  However, Andrew’s project also had some advantages; in particular, it used a pool of workers to parallelise catalog compilation.  This meant that some 100 catalogs could be compiled and tested on my quad-core laptop in less than 3 minutes.  After setting up rspec-puppet, however, I found that the same tests were now taking over 20 minutes.

It seems to me that the Puppet community has thus far tolerated rspec-puppet’s slowness.  To illustrate, I’ll focus in this post on the very mature Puppet Labs Apache module and show how parallelising its rspec-puppet tests by setting up Michael Grosser’s [parallel_tests](https://github.com/grosser/parallel_tests) would get the current execution time of about 30 minutes (on my laptop) down to under three.

## Running the rspec tests in puppetlabs/apache
To get started, let’s clone the puppetlabs/apache module:

~~~ text
$ cd /tmp
$ git clone https://github.com/puppetlabs/puppetlabs-apache.git
~~~
Next, install the bundle:

~~~
$ cd puppetlabs-apache/
$ bundle install
~~~
And then run the tests:

~~~
$ bundle exec rake spec
...
Finished in 31 minutes 15 seconds (files took 1.19 seconds to load)
1180 examples, 0 failures
~~~

This has really taken too long.  It may not be a problem for the maintainers of these modules; they may well have improved the build performance in their CI pipeline in other ways. But for people doing continuous development on their own modules on their own development laptops, a build time of >30 minutes means that people just won’t run the tests.  Or maybe they’ll run them all the time and not get much work done.  Either way, it’s a problem.

To fix this, I turned to Michael Grosser’s [parallel_tests](https://github.com/grosser/parallel_tests).

## Setting up parallel_tests
The documentation at the time of writing was hard to follow, evidently as a result of the many features that have been added organically to it over the years.

In particular, I was confused for a while about the fact that parallel_tests parallelises at the level of the rspec command – i.e. at the level of the `*_spec.rb` files.  As such, it causes rspec commands to be fired off in parallel. Meanwhile, I had hoped (dreamt perhaps?) that the parallelisation would take place at the level of the examples themselves.

A consequence of this – and something important to be aware of – is that you won’t get parallelisation at all if all of your examples are in a single file, and, likewise, you’ll get minimal benefit if one file has 1000 examples in it and all of your others have only handfuls of examples.

### Install parallel_tests
To install parallel_tests, you’ll need to add it to your Gemfile:

~~~
gem 'parallel_tests'
~~~

And to actually install the gems:

~~~
$ bundle install
...
Installing parallel 1.6.1
Installing parallel_tests 2.2.1
~~~

### Digression: Understanding the Rake ‘spec’ task
In a moment we’ll add a new Rake task for parallel_tests but before we do that it will be good to understand how the existing :spec Rake task actually works.

Like most Puppet Forge modules, the Rakefile will contain the following line:

~~~
require 'puppetlabs_spec_helper/rake_tasks'
~~~

Let’s find that library:

~~~
$ find $(bundle show puppetlabs_spec_helper) -name rake_tasks.rb
/Users/alexharvey/.rvm/gems/ruby-2.0.0/gems/puppetlabs_spec_helper-1.0.1/lib/puppetlabs_spec_helper/rake_tasks.rb
~~~

In this file we can view the definition of the :spec Rake task:

~~~ ruby
desc "Run spec tests in a clean fixtures directory"
task :spec do
  Rake::Task[:spec_prep].invoke
  Rake::Task[:spec_standalone].invoke
  Rake::Task[:spec_clean].invoke
end
~~~

So the :spec task just calls three other tasks, :spec_prep, :spec_standalone, and :spec_clean.  The first one, :spec_prep, is needed to read rspec-puppet’s .fixtures.yml file and install dependent modules in spec/fixtures. We’ll need our new Rake task to also call that task.

Then :spec_clean, predictably, cleans all of this up again at the end. So we’ll need that too.

It’s the :spec_standalone task that does all the work, so let’s also have a look at that one:

~~~ ruby
desc "Run spec tests on an existing fixtures directory"
  RSpec::Core::RakeTask.new(:spec_standalone) do |t|
    t.rspec_opts = ['--color']
    t.pattern = 'spec/{classes,defines,unit,functions,hosts,integration,types}/**/*_sp
ec.rb'
  end
~~~

This is where RSpec::Core is called and we see here where the pattern is defined for the files to include, and where the --color option is configured.  (If you need to dig into this even further, have a look at rspec-core-3.1.7/lib/rspec/core/rake_task.rb.)

(Aside: a lot of rspec-puppet documentation out there incorrectly states that the file spec/spec.opts should be used to configure rspec. In fact, the spec/spec.opts was deprecated and rspec options are now configured in .rspec. The Apache module’s spec/spec.opts also contains a line --color as well as other options which you might believe are being passed to rspec. In fact, this file is not used at all and could be safely deleted.)

## The new Rake task
As alluded to above, our new Rake task will be similar to the :spec Rake task, except that we will replace :spec_standalone with a call to parallel_tests. So we add to our Rakefile:

~~~ ruby
require 'parallel_tests'
...
desc "Parallel spec tests"
task :parallel_spec do
  Rake::Task[:spec_prep].invoke
  ParallelTests::CLI.new.run('--type test
          -t rspec spec/hosts spec/classes spec/defines spec/unit'.split)
  Rake::Task[:spec_clean].invoke
end
~~~

To be honest, I am not sure if calling methods inside parallel_tests/cli directly is the preferred way of calling parallel_tests inside a Rake task.

The other way to do it would be to shell out and call the parallel_test binary:

~~~
system('bundle exec parallel_test -t rspec spec/classes spec/defines spec/unit')
~~~

Anyhow, we can now see our new Rake task if we run bundle exec rake -T:

~~~ text
$ bundle exec rake -T
rake beaker            # Run beaker acceptance tests
rake beaker_nodes      # List available beaker nodesets
rake build             # Build puppet module package
rake clean             # Clean a built module package
rake coverage          # Generate code coverage information
rake help              # Display the list of available rake tasks
rake lint              # Run puppet-lint
rake metadata          # Validate metadata.json file
rake parallel_spec     # Parallel spec tests
rake spec              # Run spec tests in a clean fixtures directory
rake spec_clean        # Clean up the fixtures directory
rake spec_prep         # Create the fixtures directory
rake spec_standalone   # Run spec tests on an existing fixtures directory
rake syntax            # Syntax check Puppet manifests and templates
rake syntax:hiera      # Syntax check Hiera config files
rake syntax:manifests  # Syntax check Puppet manifests
rake syntax:templates  # Syntax check Puppet templates
rake validate          # Check syntax of Ruby files and call :syntax and :metadata
~~~

To run it:

All our set up is finished, so let’s run it and see what we’ve achieved:

~~~ text
$ bundle exec rake parallel_spec
8 processes for 51 specs, ~ 6 specs per process
...............................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................

Finished in 58.97 seconds (files took 1.03 seconds to load)
191 examples, 0 failures
..................................................................................................................................................................................................................................................

Finished in 1 minute 34.53 seconds (files took 1.18 seconds to load)
110 examples, 0 failures
.........................................................................

Finished in 1 minute 44.08 seconds (files took 1.02 seconds to load)
144 examples, 0 failures
..................................................................................................

Finished in 2 minutes 3.7 seconds (files took 1.03 seconds to load)
117 examples, 0 failures
...............

Finished in 2 minutes 6.2 seconds (files took 1.04 seconds to load)
125 examples, 0 failures
.......................................................

Finished in 2 minutes 19.6 seconds (files took 1.06 seconds to load)
116 examples, 0 failures
......................

Finished in 2 minutes 25.6 seconds (files took 1.03 seconds to load)
131 examples, 0 failures
....................

Finished in 2 minutes 42.1 seconds (files took 1.04 seconds to load)
246 examples, 0 failures

1180 examples, 0 failures

Took 165 seconds (2:45)
~~~

And that's much better.
