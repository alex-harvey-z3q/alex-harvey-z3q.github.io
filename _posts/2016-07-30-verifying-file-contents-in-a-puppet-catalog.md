---
layout: post
title: "Verifying file contents in a puppet catalog"
date: 2016-07-30
author: Alex Harvey
category: puppet
tags: puppet rspec
---

One of the most useful applications of Rspec-puppet I have found is in the verification of generated ERB file content. However, it is not always obvious how to actually do this.

I discovered the verify_contents method one day when pondering a question at Ask.puppet.com. An undocumented feature of the Puppetlabs_spec_helper, it is used in a few Forge modules to allow testers to say, “the catalog should contain a file X, whose contents should contain lines A, B, C ...”. For example, in the Haproxy module [here](https://github.com/puppetlabs/puppetlabs-haproxy/blob/be6cde02d34ad61c32cc71123bfb9882b3b6a809/spec/classes/haproxy_spec.rb#L393).

In this post I’m going to document how I’ve used the verify_contents method and improved upon it when testing ERB generated file content.

## Basic usage

The basic usage of verify_contents is as follows:

~~~ ruby
# spec/spec_helper.rb
require 'puppetlabs_spec_helper/module_spec_helper'
~~~

and:

~~~ ruby
# spec/classes/test_spec.rb:
require 'spec_helper'

it {
  is_expected.to contain_file('/etc/resolv.conf')
  verify_contents(catalogue, '/etc/resolv.conf', ['server 1.1.1.1'])
}
~~~

This says, “I expect the catalog to contain a file /etc/resolv.conf containing the line ‘server 1.1.1.1’”.

The method itself is defined [here](https://github.com/puppetlabs/puppetlabs_spec_helper/blob/178b895c4a07f7d5c7ec43bf9eec5bce52cbe0e8/lib/puppetlabs_spec_helper/module_spec_helper.rb#L9-L12):

~~~ ruby
def verify_contents(subject, title, expected_lines)
  content = subject.resource('file', title).send(:parameters)[:content]
  expect(content.split("\n") & expected_lines).to eql expected_lines
end
~~~

## Checking for a block of several lines

Sometimes I want to know if a file contains a specific set of lines. Suppose I have a file whose content will be:

~~~ apache
# Ensure that Apache listens on port 80

Listen 80
<VirtualHost *:80>
  DocumentRoot "/www/example1"
  ServerName www.example.com
</VirtualHost>

<VirtualHost *:80>
  DocumentRoot "/www/example2"
  ServerName www.example.org
</VirtualHost>
And suppose I want to say that the catalog is expected to contain a file with the following lines:

<VirtualHost *:80>
  DocumentRoot "/www/example1"
  ServerName www.example.com
</VirtualHost>
~~~

In this case I can write a test as follows:

~~~ ruby
it {
  is_expected.to contain_file('/etc/httpd/conf.d/example.com.conf')
  verify_contents(catalogue, '/etc/httpd/conf.d/example.com.conf', [
    "<VirtualHost *:80>",
    "  DocumentRoot \"/www/example1\"",
    "  ServerName www.example.com",
    "</VirtualHost>",
  ])
}
~~~

Note the use of double quotes here, rather than single quotes. I do this because the JSON document will have text enclosed in double quotes, so we can present the text and enclosed escape characters as it appears in the JSON. In this case, the actual catalog will contain:

~~~ json
{
  "type": "File",
  "title": "/etc/httpd/conf.d/example.com.conf",
  "tags": ["file","class","test"],
  "file": "/Users/alexharvey/foo/spec/fixtures/modules/test/manifests/init.pp",
  "line": 3,
  "exported": false,
  "parameters": {
    "content": "# Ensure that Apache listens on port 80\nListen 80\n<VirtualHos
t *:80>\n  DocumentRoot \"/www/example1\"\n  ServerName www.example.com\n</VirtualH
ost>\n\n<VirtualHost *:80>\n  DocumentRoot \"/www/example2\"\n  ServerNamewww.examp
le.org\n</VirtualHost>\n"
  }
}
~~~

(If you don’t know how to dump the catalog, see my [earlier](https://alex-harvey-z3q.github.io/2016/03/16/dumping-the-catalog-in-rspec-puppet.html) post.)

## Tricks for catalog viewing

If you do choose to dump the catalog using the method described in the post I just linked, it’s useful in this context to know of these two tricks:

1. Using vim to remove newline characters

If viewing the catalog in vim, we can use the following key sequence to make the content lines human readable:
`:%s/\\n/^M/g`. Note that to enter the ^M character we type CTRL-v CTRL-m.

2. Using a perl one-liner to remove newline characters

The following perl one-liner is also handy:

~~~ text
$ perl -pi -e 's/\\n/\n/g' mycatalog.json
~~~

Afterwards, the relevant section of the catalog will look like this:

~~~ json
{
  "type": "File",
  "title": "/etc/httpd/conf.d/example.com.conf",
  "tags": ["file","class","test"],
  "file": "/Users/alexharvey/foo/spec/fixtures/modules/test/manifests/init.pp",
  "line": 3,
  "exported": false,
  "parameters": {
    "content": "# Ensure that Apache listens on port 80
Listen 80
<VirtualHost *:80>
  DocumentRoot \"/www/example1\"
  ServerName www.example.com
</VirtualHost>

<VirtualHost *:80>
  DocumentRoot \"/www/example2\"
  ServerName www.example.org
</VirtualHost>
"
  }
}
~~~

This is much easier to read, and helps us understand how to write our tests, and debug things when the tests fail.

## Duplicate lines

_Note 2018 my fix for duplicate lines was merged so this section is no longer relevant._

A skilled Rubyist may have noticed that the verify_contents method would emit a false negative if the array of expected lines contained duplicates. This is the case in the following example:

~~~ ruby
describe 'test' do
  it {
    is_expected.to contain_file('/etc/httpd/conf.d/example.com.conf')
    verify_contents(catalogue, '/etc/httpd/conf.d/example.com.conf', [
      "<VirtualHost *:80>",
      "  DocumentRoot \"/www/example1\"",
      "  ServerName www.example.com",
      "</VirtualHost>",
      "",
      "<VirtualHost *:80>",
      "  DocumentRoot \"/www/example2\"",
      "  ServerName www.example.org",
      "</VirtualHost>",
    ])
  }
end
~~~

With duplicate lines the tests unexpectedly fail:

~~~ text
       expected: ["<VirtualHost *:80>", "  DocumentRoot \"/www/example1\"", "  ServerNa
me www.example.com", "</Virtual...alHost *:80>", "  DocumentRoot \"/www/example2\"", "
 ServerName www.example.org", "</VirtualHost>"]
            got: ["<VirtualHost *:80>", "  DocumentRoot \"/www/example1\"", "  ServerNa
me www.example.com", "</VirtualHost>", "", "  DocumentRoot \"/www/example2\"", "  Serve
rName www.example.org"]

       (compared using eql?)
~~~

The issue here is use of the Array’s Set Intersection operator (&), which removes duplicates. I have sent in a pull request to fix this here.

In the mean time, we can add the modified verify_contents method to our spec_helper.rb:

~~~ ruby
require 'puppetlabs_spec_helper/module_spec_helper'

def verify_contents(subject, title, expected_lines)
  content = subject.resource('file', title).send(:parameters)[:content]
  expect(content.split("\n") & expected_lines).to match_array expected_lines.uniq
end
~~~

## Improving readability

What we have so far works well, but it’s cumbersome to edit, and ugly to read. Sometimes it would be nice if we could present the blocks of text we expect as free text, and sometimes we may want to search for more than one block within the same file content.

Here’s what I came up with:

~~~ ruby
require 'spec_helper'

describe 'test' do
  it {
    is_expected.to contain_file('/etc/httpd/conf.d/example.com.conf')

    [

"<VirtualHost *:80>
  DocumentRoot \"/www/example1\"
  ServerName www.example.com
</VirtualHost>
",

"<VirtualHost *:80>
  DocumentRoot \"/www/example2\"
  ServerName www.example.org
</VirtualHost>
",

    ].map{|k| k.split("\n")}.each do |array_of_lines|
      verify_contents(catalogue, '/etc/httpd/conf.d/example.com.conf', array_of_lines)
    end
  }
end
~~~
