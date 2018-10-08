---
layout: post
title: "Data consistency testing in Puppet, Part I: strongly-typed data"
date: 2018-09-30
author: Alex Harvey
tags: puppet data-testing
---

When maintaining Puppet (or indeed any Infrastructure-as-code solution) in production, the human errors most often made are in data. The class expected an array of strings but you just passed in a string. The data wasn't valid JSON because you left out a comma. You added a comment in an INI file using a hash symbol instead of the semicolon. And so on.

In this first part of this series, I look at benefits of properly using Puppet's strong data types to prevent errors and speed up your team's velocity.

## Puppet data types

When Puppet 4 was released back in 2015, a lot of features were added, including much-awaited ones like iteration and manifest ordering and all-in-one packaging - and also Puppet data types.

Whereas the community had demanded many of these features, data types seemed like the solution to the problem you didn't know you had. Other languages didn't have them. They're not in Bash, and they're not in Ruby or Python either. So what's the point?

## Why strongly-typed matters

Strictly-speaking, Puppet is still a dynamically-typed language, but the introduction of rich data types brings the most important benefit of strong-typing all the same, which is the ability for the compiler to abort compilation if unexpected data is passed in. This allows us to automatically-detect one of the most common human errors - data entry mistakes - without writing a single line of automated test code.

Based on the code I have seen so far, most Puppet users don't appear to really know what they're for. Often I see code like this:

~~~ puppet
class hostname (
  String $hostname,
  ) {
  host { 'hostname':
    ensure  => present,
    name    => $hostname,
    ip      => $facts['ipaddress'],
    host_aliases => $hostname,
  }
}
~~~

Many will look at this code and wonder, quite justifiably, what the point is of the declaration, "String".


