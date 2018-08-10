---
layout: post
title: "Rspec testing a simple Ruby script"
date: 2016-04-23
author: Alex Harvey
tags: rspec
---

While writing a simple Ruby script recently, I discovered that it is difficult to find any internet documentation that discusses the simplest use-case for Rspec, namely to test a short, simple Ruby script. By that I mean a script that has methods, but no classes.  This post intends to fill that gap.

* Table of contents
{:toc}

If you’d like to follow along with the code, you can clone this repo. Note that I have added tags so that you can checkout the code in stages that will closely follow the examples in the text. Where I say, “checkout 0.0.1” in the text, I mean run:

~~~ text
$ git checkout 0.0.1
~~~

and you’ll have the code matching where you’re up to in the text.

## Project structure
To begin (checkout 0.0.1) we create a new project that illustrates expected file locations.

~~~ text
$ mkdir example
$ cd example
$ mkdir bin spec
~~~

## The spec helper
To begin with we create a simple spec helper file in spec/spec_helper.rb:

~~~ ruby
RSpec.configure do |config|
  config.color = true
end
~~~

Our examples being very simple, we don’t really need a helper but it’s conventional and I include it anyway, and this one just adds colour to our Rspec output.

## The Gemfile
We assume you have already installed Ruby Gems and Bundler.  Next we create our Gemfile with:

~~~ ruby
source 'https://rubygems.org'
gem 'rspec'
gem 'rake'
~~~

And then we install the gems as follows:

~~~ text
$ bundle install
~~~

## The Rakefile
In order to call our tests from Rake, we add a simple Rakefile:

~~~ ruby
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)
task :default => :spec
~~~
This adds the rake spec task that we’ll use to run the tests.

## The first script
Imagine we have a script that just calls a method to convert a string from hours and minutes as used for example when logging time to a Jira ticket into seconds (checkout 0.0.2).  We add this script in ./bin/example.rb:

~~~ ruby
#!/usr/bin/env ruby

##
# Converts hours and minutes to seconds.

def hm2s(hm)
  if hm =~ /\d+h +\d+m/
    h, m = /(\d+)h +(\d+)m/.match(hm).captures
    h.to_i * 60 * 60 + m.to_i * 60
  elsif hm =~ /\d+m/
    m = /(\d+)m/.match(hm).captures
    m[0].to_i * 60
  elsif hm =~ /\d+h/
    h = /(\d+)h/.match(hm).captures
    h[0].to_i * 60 * 60
  else
    raise "hm2s: illegal input #{hm}"
  end
end

if $0 == __FILE__
  raise ArgumentError, "Usage: #{$0} xh ym" unless ARGV.length > 0
  puts hm2s(ARGV.join(' '))
end
~~~

The following construct is called a guard:

~~~ ruby
if $0 == __FILE__
  # do stuff
end
~~~
In Ruby, `__FILE__` is a special variable that contains the name of the current file, whereas $0 is the name of the file that started the program. So if called from Rspec, $0 will be something like /Library/Ruby/Gems/2.0.0/gems/rspec-core-3.4.4/exe/rspec whereas __FILE__ will contain the path to the file itself, in our case ../../bin/example.rb.

This allows us to run our script as a script by calling it directly, while allowing it to behave as a library of methods in the context of Rspec.

## The first test case
Now we will add the first test case, an expectation that our method, if passed a string ‘3h 30m’, will return 3 hours and 30 minutes expressed as seconds, which is 12,600.

~~~ ruby
require 'spec_helper'
require_relative '../bin/example'

describe '#hm2s' do
  it 'should convert 3h 30m to 12600' do
    expect(hm2s('3h 30m')).to eq 12600
  end
end
~~~

Note that I have had to use require_relative. This feels a bit like a hack to me, although it appears that Rspec will only load files if they’re in the project’s lib/ directory. This script, however, doesn’t belong in the lib/ directory, because it’s not a library. Perhaps there’s a better way? Let me know in the comments if you think there is!

We also require our spec helper, which is conventionally named and required as I’ve done here.

More interesting is our first test. By convention, we write describe '#method' do ... end to “describe” or test an instance method. (And we’d write describe '.method' do ... end to test a class method.)

It’s useful to be aware at this point that Ruby doesn’t have functions in the same way that some other OO languages like Python does, even if they look the same as functions when defined in a script. In Ruby, nearly everything is an object, and methods in a script become private instance methods of Object:

~~~ text
irb(main):001:0> def hello; puts 'hello world'; end
=> nil
irb(main):002:0> method(:hello)
=> <Method: Object#hello>
~~~

Finally, note also that eq is an Rspec “matcher”. I recommend reviewing the complete list at this page here.

We’d like a few more tests, since our method may receive just a string with hours or a string just with minutes:

~~~ ruby
it 'should convert 1h to 1800' do
  expect(hm2s('1h')).to eq 3600
end

it 'should convert 30m to 1800' do
  expect(hm2s('30m')).to eq 1800
end
~~~

## Running the tests

~~~ text
$ bundle exec rake spec
/System/Library/Frameworks/Ruby.framework/Versions/2.0/usr/bin/ruby -I/Library/Ruby/Gems/2.0.0/gems/rspec-core-3.4.4/lib:/Library/Ruby/Gems/2.0.0/gems/rspec-support-3.4.1/lib /Library/Ruby/Gems/2.0.0/gems/rspec-core-3.4.4/exe/rspec --pattern spec/\*\*\{,/\*/\*\*\}/\*_spec.rb
...

Finished in 0.00117 seconds (files took 0.12125 seconds to load)
3 examples, 0 failures
~~~

## Expecting an error
Our tests aren’t complete however (checkout 0.0.3). We also expect that this method will raise an exception given badly formatted input.

If I run the script with badly formatted input, I receive output like this:

~~~ text
$ ./bin/example.rb I_am_badly_formatted
./bin/example.rb:17:in `hm2s': hm2s: illegal input I_am_badly_formatted (RuntimeError)
        from ./bin/example.rb:23:in `<main>'
~~~

And that behaviour is normal. That’s what I want it to do if called incorrectly. Two things to note here about the behaviour: (1) the script has raised a RuntimeError (the default if unspecified); and (2) the error message string “illegal input” that I wrote into the code.

Rspec has a matcher raise_error that we can use here:

~~~ ruby
it 'should raise an error given badly formatted input' do
  expect { hm2s('I_am_badly_formatted') }.to
    raise_error(RuntimeError, /illegal input/)
end
~~~

Did you also note the syntax change after the expect call? When we expect a call to raise an exception, that call must be protected inside a block { ... }. If it wasn’t so protected, the raise call would cause Rspec itself to exit, which isn’t what we want.

## Using fixtures
Let’s extend the script a bit (checkout 0.0.4) so that it reads times from a YAML-formatted data file.

Assume we have a file spec/fixtures/good.yml that looks like this (the reason for this file name and path will be explained below):

~~~ yaml
---
times:
- 10h 3m
- 2h 5m
- 40m
~~~

We will add some methods for reading in this file and looping through its data:

~~~ ruby
require 'yaml'
...
##
# Get data from a YAML-formatted data file.

def get_data(data_file)
  begin
    YAML::load_file(data_file)
  rescue => e
    raise "Error reading #{data_file}: #{e}"
  end
end

##
# Process a list of data from a file.

def process(data_file)
  data = get_data(data_file)
  data['times'].each do |t|
    puts hm2s(t)
  end
end

if $0 == __FILE__
  raise ArgumentError, "Usage: #{$0} <filename>" unless ARGV.length == 1
  process(ARGV[0])
end
~~~

We can now run the script to convert all these times:

~~~ text
$ ./bin/example.rb spec/fixtures/good.yml
36180
7500
2400
~~~

But how do we test it?

## Testing get_data
To test the get_data method it would be ideal if we can use a real file as input and expect its Hash representation in return.

The reason I have saved my data file as spec/fixtures/good.yml is another Rspec convention (although some say that use of fixtures is an anti-pattern, e.g.) Well, I think it would be overkill to use factory_girl in a simple script, and this will remain beyond the scope of today’s post).

Now I’ll have a test as follows:

~~~ ruby
describe '#get_data' do
  it 'should read YAML-formatted data from a file' do
    expected = {'times' => ['10h 3m', '2h 5m', '40m']}
    expect(get_data('spec/fixtures/good.yml')).to eq expected
  end
end
~~~
We’ll also need a test for a badly formatted YAML file and we add that file in spec/fixtures/bad.yml. It looks like this:

~~~ yaml
---
times:
10h 3m
2h 5m
40m
~~~

Badly-formatted YAML. Well, not YAML at all. Anyway, the test:

~~~ ruby
it 'should error out if YAML is badly formatted' do
  expect { get_data('spec/fixtures/bad.yml') }.
    to raise_error(RuntimeError, /Error reading spec\/fixtures\/bad.yml/)
end
~~~

And running the tests now gives us:

~~~ text
$ bundle exec rake spec
/System/Library/Frameworks/Ruby.framework/Versions/2.0/usr/bin/ruby -I/Library/Ruby/Gems/2.0.0/gems/rspec-core-3.4.4/lib:/Library/Ruby/Gems/2.0.0/gems/rspec-support-3.4.1/lib /Library/Ruby/Gems/2.0.0/gems/rspec-core-3.4.4/exe/rspec --pattern spec/\*\*\{,/\*/\*\*\}/\*_spec.rb
......

Finished in 0.00565 seconds (files took 0.11604 seconds to load)
6 examples, 0 failures
~~~

## Stubbing out a method
Finally (checkout 0.0.5), we’ll want to test the process method. We could apply the same approach, and have the process method also read from a file in fixtures. However, that would not be a unit test; it would be an integration test. It would be testing at once the correct operation of both the get_data and the process methods.

To test the process method in isolation we need to “stub” the get_data method. In the language of Rspec, we will “allow” the method to be called with a specific input and then return a canned output.

It’s at this point that it’s good that we know that all of our methods in our script are really private instance methods of Object.

To do this we need to go outside of Rspec core and use the Rspec-mocks project.

We’ll need the following syntax:

~~~ ruby
allow_any_instance_of(Widget).to receive(:name).with('Wiggle').and_return('Wibble')
~~~

In our case the object will be Object, the message it will receive will be the name of the method :get_data, we’ll pass it a made up file '/some/file', and we’ll tell it to return the Hash from before.

But our method prints to STDOUT rather than returning a value. So we’ll need to use output matchers. Something like:

~~~ ruby
expect { actual }.to output('some output').to_stdout
~~~

Putting all this together:

~~~ ruby
describe '#process' do
  it 'should correctly process the data file' do
    allow_any_instance_of(Object).
      to receive(:get_data).with('/some/file').
      and_return({'times' => ['10h 3m', '2h 5m', '40m']})
    expect { process('/some/file') }.to output("36180\n7500\n2400\n").to_stdout
  end
end
~~~
And running the tests:

~~~ text
$ bundle exec rake spec
/System/Library/Frameworks/Ruby.framework/Versions/2.0/usr/bin/ruby -I/Library/Ruby/Gems/2.0.0/gems/rspec-core-3.4.4/lib:/Library/Ruby/Gems/2.0.0/gems/rspec-support-3.4.1/lib /Library/Ruby/Gems/2.0.0/gems/rspec-core-3.4.4/exe/rspec --pattern spec/\*\*\{,/\*/\*\*\}/\*_spec.rb
.......

Finished in 0.02416 seconds (files took 0.18324 seconds to load)
7 examples, 0 failures
~~~

And that’s it for today.
