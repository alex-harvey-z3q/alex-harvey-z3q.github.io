---
layout: post
title: "Pretty-printing Puppet data"
date: 2018-09-02
author: Alex Harvey
tags: puppet
---

Sometimes it is useful to be able to pretty-print Puppet data when debugging. It would be great if there was native support for this, e.g. a built-in function `pp()` would be nice.

Until then, I found a useful [Gist](https://gist.github.com/Cinderhaze/6d1e90dec0184284eb25910b5ce06b5f) by Github user Cinderhaze a.k.a. Daryl, which is the basis of this method.

## Sample code

Consider the following snippet:

~~~ puppet
# data.pp
$data = {
  "test.ltd" => {
    "ensure" => "present",
    "zone_contact" => "contact.test.ltd",
    "zone_ns"     => ["ns0.test.ltd", "ns1.test.ltd"],
    "zone_serial" => "2018010101",
    "zone_ttl"    => "767200",
    "zone_origin" => "test.ltd",
    "hash_data" => {
      "newyork" => {"owner" => "11.22.33.44"},
      "tokyo"   => {"owner" => "22.33.44.55"},
      "london"  => {"owner" => "33.44.55.66"},
    }
  }
}

notice($data)
~~~

If I apply, the output is unreadable:

~~~ text
$ puppet apply data.pp
Notice: Scope(Class[main]): {test.ltd => {ensure => present, zone_contact => contact.test.ltd, zone_ns => [ns0.test.ltd, ns1.test.ltd], zone_serial => 2018010101, zone_ttl => 767200, zone_origin => test.ltd, hash_data => {newyork => {owner => 11.22.33.44}, tokyo => {owner => 22.33.44.55}, london => {owner => 33.44.55.66}}}}
Notice: Compiled catalog for alexs-macbook-pro.local in environment production in 0.02 seconds
Notice: Applied catalog in 0.01 seconds
~~~

## Pretty-printing

Using the idea suggested by Cinderhaze:

~~~ puppet
# data.pp
$data = {
  "test.ltd" => {
    "ensure" => "present",
    "zone_contact" => "contact.test.ltd",
    "zone_ns"     => ["ns0.test.ltd", "ns1.test.ltd"],
    "zone_serial" => "2018010101",
    "zone_ttl"    => "767200",
    "zone_origin" => "test.ltd",
    "hash_data" => {
      "newyork" => {"owner" => "11.22.33.44"},
      "tokyo"   => {"owner" => "22.33.44.55"},
      "london"  => {"owner" => "33.44.55.66"},
    }
  }
}

$content = inline_template("
  <%- require 'json' -%>
  <%= JSON.pretty_generate(@data) %>
  ")
~~~

I now get nice readable JSON-formatted output:

~~~ text
$ puppet apply data.pp
Notice: Scope(Class[main]):
  {
  "test.ltd": {
    "ensure": "present",
    "zone_contact": "contact.test.ltd",
    "zone_ns": [
      "ns0.test.ltd",
      "ns1.test.ltd"
    ],
    "zone_serial": "2018010101",
    "zone_ttl": "767200",
    "zone_origin": "test.ltd",
    "hash_data": {
      "newyork": {
        "owner": "11.22.33.44"
      },
      "tokyo": {
        "owner": "22.33.44.55"
      },
      "london": {
        "owner": "33.44.55.66"
      }
    }
  }
}

Notice: Compiled catalog for alexs-macbook-pro.local in environment production in 0.04 seconds
Notice: Applied catalog in 0.01 seconds
~~~

## Using awesome-print instead

Or we could use the Ruby awesome_print library:

~~~ puppet
$data = {
  "test.ltd" => {
    "ensure" => "present",
    "zone_contact" => "contact.test.ltd",
    "zone_ns"     => ["ns0.test.ltd", "ns1.test.ltd"],
    "zone_serial" => "2018010101",
    "zone_ttl"    => "767200",
    "zone_origin" => "test.ltd",
    "hash_data" => {
      "newyork" => {"owner" => "11.22.33.44"},
      "tokyo"   => {"owner" => "22.33.44.55"},
      "london"  => {"owner" => "33.44.55.66"}
    }
  }
}

$content = inline_template("
  <%- require 'awesome_print' -%>
  <%= ap(@data) %>
  ")
notice($content)
~~~

And get:

~~~ text
$ puppet apply data.pp
{
    "test.ltd" => {
              "ensure" => "present",
        "zone_contact" => "contact.test.ltd",
             "zone_ns" => [
            [0] "ns0.test.ltd",
            [1] "ns1.test.ltd"
        ],
         "zone_serial" => "2018010101",
            "zone_ttl" => "767200",
         "zone_origin" => "test.ltd",
           "hash_data" => {
            "newyork" => {
                "owner" => "11.22.33.44"
            },
              "tokyo" => {
                "owner" => "22.33.44.55"
            },
             "london" => {
                "owner" => "33.44.55.66"
            }
        }
    }
}
Notice: Scope(Class[main]):
  {"test.ltd"=>{"ensure"=>"present", "zone_contact"=>"contact.test.ltd", "zone_ns"=>["ns0.test.ltd", "ns1.test.ltd"], "zone_serial"=>"2018010101", "zone_ttl"=>"767200", "zone_origin"=>"test.ltd", "hash_data"=>{"newyork"=>{"owner"=>"11.22.33.44"}, "tokyo"=>{"owner"=>"22.33.44.55"}, "london"=>{"owner"=>"33.44.55.66"}}}}

Notice: Compiled catalog for alexs-macbook-pro.local in environment production in 0.08 seconds
Notice: Applied catalog in 0.01 seconds
~~~
