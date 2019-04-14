---
layout: post
title: "Data consistency testing in Puppet, Part I: Data types"
date: 2018-09-30
author: Alex Harvey
tags: puppet data-testing
---

When maintaining Puppet (or any Infrastructure-as-code solution) in production, human errors are made most frequently in data. A class expected an array of strings but you just passed in a string. The data wasn't valid JSON because you left out a comma. You added a comment to an INI file using a hash symbol instead of the semicolon. And so on.

In this first part of a blog series on data consistency testing in Puppet, I look at the benefits of properly using Puppet's data types to prevent human errors and speed up your team's velocity.

* ToC
{:toc}

## Puppet data types

When Puppet 4 was released back in 2015, a lot of features were added, including much-awaited ones like iteration and manifest-ordering and all-in-one packaging. Also released was a feature that came as a surprise to many - data types. Data types seemed a bit like a solution to the problem you didn't know you had. Considering that the other languages people were familiar with didn't have them - e.g. Ruby, Python, Perl, Bash etc - why would Puppet need them?

Strictly-speaking, Puppet remains a dynamically-typed language, but the data types bring the most important benefit of static-typing, namely the ability of the compiler to detect unexpected data. This speeds up development, as data errors can be detected without a single line of test code.

## Using Puppet types

### Simple example

#### Code example 1

With that said, the benefits of Puppet's data types do not appear to be widely understood. Most of the time, I see code that looks like this:

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

And when I say most of the time, I mean in most of the Puppet Supported modules too, e.g. [concat](https://github.com/puppetlabs/puppetlabs-concat/blob/master/manifests/init.pp), [ntp](https://github.com/puppetlabs/puppetlabs-ntp/blob/master/manifests/init.pp), [apt](https://github.com/puppetlabs/puppetlabs-apt/blob/master/manifests/init.pp) etc.

Many no doubt have seen code like this and wondered what the point of it is. Why declare the hostname as a "String". What else would it be?

#### Making this better

To benefit from Puppet's types, it is necessary to use them precisely to define a range of acceptable inputs. Declaring hostname as a String has the advantage of preventing compilation if an Array is passed in, although it's unlikely someone would pass an Array into a hostname field. What about an empty string though? That's more plausible.

Now imagine the following Rspec example:

~~~ ruby
describe 'hostname' do
  let(:hiera_config) { 'spec/fixtures/hiera/hiera.yaml' }
  it { is_expected.to compile }
end
~~~

Notice two things here:

1. I have configured Rspec to use real Hiera data
1. This is the only Rspec code I am going to write in this blog post.

All testing is based on simply passing real Hiera data into the compiler.

So, I also create a common.yaml file with:

~~~ yaml
hostname::hostname: ''
~~~

Now, running Rspec leads to:

~~~ text
error during compilation: Parameter host_aliases failed on Host[hostname]: Host aliases cannot be an em
pty string. Use an empty array to delete all host_aliases  (file: /Users/alexharvey/git/home/puppet-tes
t/spec/fixtures/modules/hostname/manifests/init.pp, line: 4)
~~~

That's pretty confusing. The user's mistake was to pass an empty string for the hostname, whereas the error messages directs them to look at host aliases on another line in the file.

To force compilation to abort if an empty string is passed in, we can do this instead:

~~~ puppet
class hostname (
  String[1] $hostname,
  ) {
  # ...
}
~~~

The declaration `String[1]` means string of minimum length 1.

If I run the test again, compilation now aborts with this error:

~~~ text
Error while evaluating a Resource Statement, Class[Hostname]: parameter 'hostname' expects a String[1]
value, got String (line: 2, column: 1)
~~~

This is better, even if the message is still cryptic. At least the error message has directed the user to the right line in the code, and has informed them that the problem is in the data.

#### Better still

Quite often, hostnames are expected to match a pattern. Suppose a hostnaming convention exists: `AAABCCCnnn` where:

- AAA = department
- B = L or W (Linux or Windows)
- CCC = app
- nnn = a number from 1 to 999.

We can now further improve our code using a [Pattern](https://puppet.com/docs/puppet/5.3/lang_data_abstract.html#pattern) type as follows:

~~~ ruby
class hostname (
  Pattern[/^[A-Z]{3}[LW][A-Z]{3}\d{3}$/] $hostname,
  ) {
  # ...
}
~~~

If we pass in the empty string here, we now get a much better error message:

~~~ text
Error: Evaluation Error: Error while evaluating a Resource Statement, Class[Hostname]: parameter 'host
name' expects a match for Pattern[/^[A-Z]{3}[LW][A-Z]{3}\d{3}$/], got ''
~~~

By using the types, we have:

1. Made it very difficult for compilation to proceed if invalid data is passed in
1. Set it up so that if bad data is passed in, Puppet's compiler aborts with a helpful message.

### Real life example

If the example of the hostnaming convention is a bit abstract, a second, more complex example using a nested Hash structure makes the value of Puppet's type clearer.

#### Code example 2

Imagine an ELK data node that expects a Hash of volume groups:

~~~ puppet
class profile::elasticsearch::data_node (
  Hash $volume_groups,
  ) {
  create_resources(lvm::volume_group, $volume_groups)
  # ...
}
~~~

This is a modification of my open source ELK solution from [here](https://github.com/alexharv074/elk).

The declaration "Hash" here is not likely to detect actual errors and does not add much as documentation. The chances are that in the absence of some sample data, it is not going to be easy to figure out what the actual YAML Hash of volume groups really looks like. The user probably would need to carefully study the internals of the LVM module or its documentation to figure out that a structure like this would be required:

~~~ yaml
profile::elasticsearch::data_node::volume_groups:
  esvg00:
    physical_volumes:
      - "%{facts.espv}"
    logical_volumes:
      eslv00:
        mountpath: /srv/es
~~~

But let's suppose the user mucks up the LV struct:

~~~ yaml
profile::elasticsearch::data_node::volume_groups:
  esvg00:
    physical_volumes:
      - "%{facts.espv}"
    logical_volumes:
      eslv00: /srv/es
~~~

The mistake above is not easy to spot and an easy mistake to make.

Now let's see what happens if I compile my actual code using these modifications:

~~~ text
error during compilation: Evaluation Error: Error while evaluating a Resource Statement, Evaluation Er
ror: Error while evaluating a Function Call, no implicit conversion of String into Hash (file: /Users/
alexharvey/git/home/elk/spec/fixtures/modules/lvm/manifests/volume_group.pp, line: 34, column: 3) (fil
e: /Users/alexharvey/git/home/elk/spec/fixtures/modules/profile/manifests/elasticsearch/data_node.pp,
line: 43)
~~~

Huh? How did I cause an error at line 34 in spec/fixtures/modules/lvm/manifests/volume_group.pp? That's a file from a Supported Puppet module.

#### Making this better

Confusing errors like this one can be avoided if Puppet's type system is used. Here I refactor to declare the expected data types:

~~~ ruby
class profile::elasticsearch::data_node (
  Hash[Pattern[/^[a-z]+vg\d+$/], Struct[{
    physical_volumes => Array[Stdlib::Absolutepath],
    logical_volumes  => Hash[
      Pattern[/^[a-z]+lv\d+$/], Struct[{
        mountpath      => Stdlib::Absolutepath
      }]]  $volume_groups,
  ) {
  create_resources(lvm::volume_group, $volume_groups)
  # ...
}
~~~

Notice that I have declared everything from the structure of the data down to the naming convention of the logical volumes and the volume groups.

Running the tests now leads to an error message that explains to the user exactly what they did wrong and where:

~~~ text
error during compilation: Evaluation Error: Error while evaluating a Function Call, Class[Profile::Elas
ticsearch::Data_node]: parameter 'volume_groups' entry 'esvg00' entry 'logical_volumes' entry 'eslv00'
expects a Struct value, got String (file: /Users/alexharvey/git/home/elk/spec/fixtures/modules/role/man
ifests/elk_stack.pp, line: 3, column: 3)
~~~

## Discussion

### Why data testing matters

I expect that many people will be skeptical of the claim that Puppet's data types can significantly increase team velocity.

All the same, I have seen at site after site the same story recorded in revision histories everywhere - human errors, typos etc in the frequently-changing configuration data files causing immense wasted effort. And when you think about it, this is natural; data is supposed to change and this is the reason we separate it from the manifests in the first place. On the other hand, we are usually told to do behaviour-driven development and write unit tests that test only the logic and behaviour of classes. An important opportunity is missed becauses tests are not useful if the thing they are testing is not expected to change.

(Of course, I am not suggesting that unit tests are not important either, but the emphasis is often in the wrong place.)

### Errors detected early

The Puppet types means that most data errors can be detected early - in the pre-commit stage, in fact - while the developer is present and likely to be aware of the mistake made. Since the compilation tests take only seconds to run, mistakes picked up early end up costing only a little lost time. Compare this to the worst case where a data error finds its way all the way into production without detection by any other testing. In that case, a simple typo can end up costing the team quite a lot of lost time and not to mention a possible production outage.

### Improved error messages

Another key benefit of allowing Puppet's types to detect data errors is that we avoid a lot of Puppet's otherwise sometimes confusing error messages. Next time someone is complaining that Puppet is hard to debug, ask them if the confusing error message could have been avoided if Puppet's data types were used properly.

### Types as documentation

Yet another benefit of use of Puppet's types is that the types document the assumptions about the data, and this documentation is unlikely to exist otherwise. The example I gave already was of the hostnaming convention. This makes the code easier to use by the team and leads to fewer questions about naming conventions etc which otherwise may be part of the undocumented tribal knowledge and thus sees people get more work done.

### A reason to use Puppet

In my opinion, the data types feature is a big reason to choose Puppet over other configuration management solutions like Ansible and Chef. None of the others have this feature - even newer tools like Terraform don't have this<sup>1</sup> - and it is unlikely that they ever will. That a feature like this could be implemented is one of the benefits of Puppet's early design choice to be its own special purpose configuration language.

Of course, this benefit of Puppet is not sold well if no one knows about it! I daresay that not many DevOps engineers out there have seen any kind of data consistency testing in their infrastructure code, and much less the highly efficient use of Puppet's types.

I do hope this post helps to get the good word out.

## Conclusion

I have argued in this post that proper use of Puppet's data types increases team velocity for a number of reasons, and given a couple of examples of how to actually use them. I've shown that data errors can be detected without writing any explicit tests in Rspec aside from the compilation tests.

In the next part, I will discuss the use of Rspec to directly test the data in the Hiera files, for data errors that can't be detected as easily using just the data types.

<sup>1</sup> Actually, Amazon Cloudformation has a data types feature similar to Puppet's. This is the only other tool I'm aware of that has it.
