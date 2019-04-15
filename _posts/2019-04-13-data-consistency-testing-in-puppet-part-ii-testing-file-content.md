---
layout: post
title: "Data consistency testing in Puppet, Part II: Testing file content"
date: 2019-04-13
author: Alex Harvey
tags: puppet rspec
---

This post continues my blog series on data consistency testing in Puppet, where I add additional layers of automated testing around the file content in Puppet catalogs. For Part I of the series, see [here](https://alexharv074.github.io/2018/09/30/data-consistency-testing-in-puppet-part-i-data-types.html).

The source code for this blog is available at GitHub [here](https://github.com/alexharv074/data_consistency_part_ii). Step through the revision history to see the various examples.

* ToC
{:toc}

## What is the problem

Unit tests are great but they only test the logic of your code. In practice, however, mistakes are often made in data. Thinking back, I would say that missing or unexpected commas in JSON files have caused more errors in production than I can count.

In Part I, I looked at how to test Hiera data as it passes into Puppet manifests using Puppet's data types. But no matter how hard we try to externalise our data in Hiera, some of it always stays inside manifests as file data.

That's the problem I am trying to solve today. How do you test the data that lives in files in Puppet manifests?

## Example 1: JSON data in an ERB template

### Code example 1

Suppose you have a manifest:

```puppet
class loopback {

  $rest_api_root = '/api'
  $host = '0.0.0.0'
  $port = 3000

  file { '/server/config.json':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0444',
    content => template('loopback/config.json.erb'),
  }
}
```

And an ERB template<sup>1</sup>:

```erb
{
  "restApiRoot": "<%= @rest_api_root -%>",
  "host": "<%= @host -%>",
  "port": <%= @port -%>,
  "remoting": {
    "context": {"enableHttpContext": false},
    "rest": {"normalizeHttpPath": false, "xml": false},
    "json": {"strict": false, "limit": "100kb"},
    "urlencoded": {"extended": true, "limit": "100kb"},
    "cors": false
    "errorHandler": {"disableStackTrace": false}
  },
  "legacyExplorer": false
}
```

And suppose I have the simplest Rspec-puppet test, one that just compiles and [writes](https://alexharv074.github.io/2016/03/16/dumping-the-catalog-in-rspec-puppet.html) a catalog:

```ruby
require 'spec_helper'

describe 'loopback' do
  it 'compiles' do
    is_expected.to compile
    File.write('catalogs/loopback.json', PSON.pretty_generate(catalogue))
  end
end
```

So I run the Rspec tests and everything passes:

```text
▶ bundle exec rake spec
...
loopback
  compiles

Finished in 0.83471 seconds (files took 1.27 seconds to load)
1 example, 0 failures
```

Great, everything passed. Release it to production!

### Testing the JSON file content

#### Using JQ on the compiled catalog

Well maybe not. The following JQ on the compiled catalog shows that I just compiled a catalog with invalid JSON data in it:

```text
▶ jq '
    .resources[]
    | select((.type == "File") and (.title=="/server/config.json"))
    | .parameters.content | fromjson
  ' < catalogs/loopback.json
```

Yields:

```text
jq: error (at <stdin>:95): Expected separator between values at line 11, column 18 (while parsing '{
  "restApiRoot": "/api",
  "host": "0.0.0.0",
  "port": 3000,
  "remoting": {
    "context": {"enableHttpContext": false},
    "rest": {"normalizeHttpPath": false, "xml": false},
    "json": {"strict": false, "limit": "100kb"},
    "urlencoded": {"extended": true, "limit": "100kb"},
    "cors": false
    "errorHandler": {"disableStackTrace": false}
  },
  "legacyExplorer": false
}
')
```

#### Using Rspec

But if the data is already inside the catalog, there must be a way to use Rspec-puppet to detect it earlier. And, of course, there is, although, as far as I am aware, how to do this has never been documented. I figured it out inside the Ruby debugger; it involves nagivating Rspec-puppet's `catalogue` object.

Here I add a failing test:

```ruby
  it '/server/config.json should be valid JSON' do
    require 'json'
    json_data = catalogue
      .resource('file', '/server/config.json')
      .send(:parameters)[:content]
    expect { JSON.parse(json_data) }.to_not raise_error
  end
```

The key insight is that the `catalogue` object has a `#resource` method that can look up resources in the catalog by type/title to get their parameters. In fact, I recommend attaching the debugger at that line yourself and spending some time playing around with it to further understand the `catalogue` object. More is possible! But for now, that one line is all I need.

So, I run the tests again, and now the invalid JSON is detected:

```text
  1) loopback /server/config.json should be valid JSON
     Failure/Error: expect { JSON.parse(json_data) }.to_not raise_error

       expected no Exception, got #<JSON::ParserError: 743: unexpected token at '{
         "restApiRoot": "/api",
         "host": "0.0.0.0",
         "por...  "cors": false
           "errorHandler": {"disableStackTrace": false}
         },
         "legacyExplorer": false
       }
       '> with backtrace:
         # ./spec/classes/init_spec.rb:21:in `block (3 levels) in <top (required)>'
         # ./spec/classes/init_spec.rb:21:in `block (2 levels) in <top (required)>'
     # ./spec/classes/init_spec.rb:21:in `block (2 levels) in <top (required)>'
```

#### Testing a specific field

What if I also want to make assertions about specific fields in the JSON data? I can do that too.

Here is a test case that tests the contents of ERB interpolated fields against regular expressions:

```ruby
  it 'restApiRoot, host and port should look ok' do
    json_data = catalogue.resource('file', '/server/config.json').send(:parameters)[:content]
    parsed = JSON.parse(json_data)
    expect(parsed['restApiRoot']).to match %r{^/[\w/]+$}
    expect(parsed['host']).to match /^(\d+(\.|$)){4}$/
    expect(parsed['port']).to be_a(Integer)
  end
```

On running these new tests:

```text
loopback
  compiles
  should contain file /server/config.json
  /server/config.json should be valid JSON
  restApiRoot, host and port should look ok

Finished in 0.78467 seconds (files took 1.3 seconds to load)
4 examples, 0 failures
```

## Example 2: JSON data in a sourced file

### Code example 2

This all works fine if your data is in Puppet templates. But sometimes Puppet's built-in file server is used.<sup>2</sup> What if our Loopback class looked like this:

```puppet
class loopback {

  file { '/server/config.json':
    ensure => present,
    owner  => 'root',
    group  => 'root',
    mode   => '0444',
    source => 'puppet:///modules/loopback/config.json',
  }
}
```

The JSON config file is saved at `files/config.json`. Imagine it has the same typo it had before.

### Testing the JSON file using pure Rspec

I can't use Rspec-puppet to test this file because the file content simply doesn't end up inside the Puppet catalog. Rather, Puppet's file server is used and the file content is retrieved when the catalog is actually applied.

But I can still test the file. I just use pure Rspec. Here's how I do it:

```ruby
  it '/server/config.json should be valid JSON' do
    json_data = File.read('files/config.json') ## THIS LINE CHANGES
    expect { JSON.parse(json_data) }.to_not raise_error
  end
```

Actually, it's easier to test plain text files served by Puppet's file server, although, in practice, these kinds of files - because they are not generated dynamically by ERB - tend to be less error prone. Still, it's good to "test all the things" and this is the method I typically use.

## Example 3: YAML data

Of course, not all file content is JSON data, although the same general approach can be used for any type of file data, as long as there is a Ruby library that can parse it. And that means pretty much anything.

### Code example 3

Here is a YAML example. The manifest:

```puppet
class hiera {

  $codedir = '/etc/puppetlabs/code'
  $confdir = '/etc/puppetlabs/puppet'

  file { "$confdir/hiera.yaml":
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0444',
    content => template('hiera/hiera.yaml.erb'),
  }
}
```

The template:

```erb
---
:yaml:
  :datadir: "<%= @codedir -%>/environments/%{::environment}/hieradata"
:backends:
  - yaml
  - json
:hierarchy:
  - "nodes/%{::trusted.certname}"
  - "virtual/%{::virtual}"
  - "common"
```

And the Rspec example:

```ruby
require 'spec_helper'
require 'yaml'

describe 'hiera' do
  it 'compiles' do
    is_expected.to compile
    File.write('catalogs/hiera.json', PSON.pretty_generate(catalogue))
  end

  it 'datadir in hiera.yaml should be correct' do
    yaml_data = catalogue
      .resource('file', '/etc/puppetlabs/puppet/hiera.yaml')
      .send(:parameters)[:content]
    parsed = YAML.load(yaml_data)
    expect(parsed[:"yaml"][:"datadir"])
      .to eq '/etc/puppetlabs/code/environments/%{::environment}/hieradata'
  end
end
```

## Example 4: INI file data

### Specific issues with INI files

To validate INI files I have used the TwP [inifile](https://github.com/twp/inifile) library in the past.

INI files, however, present a few specific challenges:

1. Reading an INI file from string data as opposed to a file on disk isn't documented in the inifile library's docs, although it is documented in the source code [here](https://github.com/TwP/inifile/blob/134595662bdb986a03dae075daeeb3734313645f/lib/inifile.rb#L59).

1. The library hasn't been committed to since 2014! It probably is not maintained.

1. It is almost impossible to produce a typo in an INI file that causes this parser to raise an error. Thus, I don't bother testing for raised errors at all.

### Code example 4

Here is an example inifile manifest:

```puppet
class puppet::agent {

  $agent_certname = 'agent01.example.com'
  $puppet_server = 'puppet'

  file { '/etc/puppetlabs/puppet/puppet.conf':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0444',
    content => template('puppet/puppet.conf.erb'),
  }
}
```

And the template:

```erb
[main]
certname = <%= @agent_certname %>
server = <%= @puppet_server %>
environment = production
runinterval = 1h
```

And an Rspec example:

```ruby
require 'spec_helper'
require 'inifile'

describe 'puppet::agent' do
  it 'compiles' do
    is_expected.to compile
    File.write('catalogs/puppet__agent.json', PSON.pretty_generate(catalogue))
  end

  it 'certname in /etc/puppetlabs/puppet/puppet.conf should be correct' do
    inifile_data = catalogue
      .resource('file', '/etc/puppetlabs/puppet/puppet.conf')
      .send(:parameters)[:content]
    parsed = IniFile.new(:content => inifile_data)
    expect(parsed.sections).to eq ['main']
    expect(parsed['main']['certname']).to eq 'agent01.example.com'
  end
end
```

Remember, unlike JSON and YAML, where the parsers ship with Ruby, you must also add the inifile library to Gemfile.

## Example 5: Java Properties

### Code example 5

I have tested Java Properties files in the past using Jonas Thiel's [java-properties](https://github.com/jnbt/java-properties) library.

Here is an example. Manifest:

```puppet
class javaprops {
  file { '/home/webapp/config.properties':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0444',
    content => template('javaprops/config.properties.erb'),
  }
}
```

Template:

```java
// vim: set ft=java:

dataSource.dialect = "org.hibernate.dialect.MySQL5InnoDBDialect"
dataSource.driverClassName = "com.mysql.jdbc.Driver"
dataSource.url = "jdbc:mysql://localhost:3306/icescrum?useUnicode=true&characterEncoding=utf8"
dataSource.username = "root"
dataSource.password = "myDbPass"
```

And a test:

```ruby
require 'spec_helper'
require 'java-properties'

describe 'javaprops' do
  it 'compiles' do
    is_expected.to compile
    File.write('catalogs/javaprops.json', PSON.pretty_generate(catalogue))
  end

  it 'dataSource.username in /home/webapp/config.properties should be root' do
    java_properties = catalogue
      .resource('file', '/home/webapp/config.properties')
      .send(:parameters)[:content]
    parsed = JavaProperties.parse(java_properties)
    expect(parsed[:"dataSource.username"]).to eq '"root"'
  end
end
```

## Discussion

In my experience of maintaining Puppet and other configuration management systems in production, data problems break production far more than code and logic problems. Whether developers write tests or otherwise for their code, the bugs in software do tend to be found and fixed whereas an INI file typo might not be detected until a strange behaviour in a system is seen by an end user.

It may not always be the job of the infrastructure developers to detect these errors but I believe strongly that everything that can be tested that is likely to change and break should be tested. I am also aware that, in practice, a lot of data of this kind does unfortunately go untested. For that reason, I hope that the method I devised and documented here takes off and is copied by others.

In a subsequent part of this series I will give examples of how script content such as Bash shell scripts and Python scripts can be unit tested after extraction from a Puppet catalog via Rspec-puppet.

## See also

- Paul Hammond and Samantha Stoller, Jul 28 2016, [Data Consistency Checks](https://slack.engineering/data-consistency-checks-e73261318f96) (Slack Engineering).

<sup>1</sup> And the reader can _surely_ notice that this isn't going to actually generate valid JSON right? No, I doubt it. The dreaded missing JSON comma is hard to notice.<br>
<sup>2</sup> Although I personally recommend almost always keeping your file data inside Puppet catalogs by always using the `template()` or `file()` function.
