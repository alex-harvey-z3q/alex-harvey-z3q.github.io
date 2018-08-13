In the years since 2012, when Ansible burst onto the configuration management scene, the tool has gained increasing popularity.

Published opinions on Ansible’s viability appear to range from acceptable alternative to Puppet and Chef through to radically simpler and therefore superior.

In this post, we offer our considerable experience in the field in a review of the latest open source versions of the products, which are at the time of writing Puppet 4.10.1 and Ansible 2.3.1.0.

Table of Contents	
{:toc}

Difficulty and learning curve
Defining difficulty
Before addressing difficulty and learning curve, it is important to define what we are measuring.

Time taken to set up and install the tool and its supporting infrastructure.
Time taken to learn the DSL and its conventions.
Difficulty to use the tool, once fluency is gained, to solve problems in the configuration management problem space.
In rating the tools we define the following conventions:

very easy We expect it will take less than half a day to master this.
easy We expect it will take no more than one day to master this.
difficult We expect at least a few days effort in learning this, and possibly training required.
very difficult We expect that some people will give up.
Installing the tool and supporting infrastructure
Architecture considerations
Installing Ansible typically involves installing Ansible on a control machine; setting up SSH public key authentication for all managed nodes; and adding the nodes to an Ansible inventory (unless a dynamic inventory is used).

Installing Puppet typically involves setting up a Puppet Master; installing a Puppet Agent on the managed nodes; and signing a certificate signing request on the Puppet Master (unless auto-signing is enabled).

(More detail required here.)

(FIGURE: Puppet architecture v Ansible architecture.)

Proponents of Ansible often argue that Ansible is agentless and, therefore, is easier than Puppet and Chef to set up.

In fact, there are advantages and disadvantages to agentless and agentful, but it is a mistake to say that there is an inherent difference in complexity. In Ansible’s case, the problem of installing and registering the agent is replaced by a problem of installing the SSH public keys, securing the private key, and updating the inventory.

Some will say that SSH key authentication is something you need to set up anyway, so it is therefore unfair to define it as a part of Ansible’s architecture. Well, it is true that some sites will already allow SSH key password-less authentication, and in some cases the SSH access can be used as-is. But if security best practices are followed, Ansible will need a dedicated account for the purposes of auditing and access control (e.g.). Likewise, the Puppet and Chef users might also say that the agent is unlikely to be the only piece of third party software that needs to be installed by the node provisioning process.

Python v Ruby
Ansible is written in Python 2.7 whereas Puppet is written in Ruby 2.1.4.

Ansible assumes that Python is installed on the managed nodes (which is usually true for Linux, although can be a problem on other platforms like Windows), whereas Puppet (since Puppet 4) installs in an all-in-one bundle that contains Ruby and its other dependencies.

Again, both approaches have their advantages and disadvantages, but neither is inherently better or worse than the other.

Note that early versions of Puppet required a system Ruby, and this sometimes led to dependency problems and Ruby version bugs on systems that had an upgraded Ruby. It also made installation difficult on platforms where Ruby was not available at all. While these issues contributed to the perception that Puppet is difficult to install, the issues have long since been fixed.

Summary
Our finding is that there is no difference between Puppet and Ansible in terms of which is easiest to set up and install, and we rate both of them as easy.

Learning the DSL
Consensus of users
While not an objective measure, many users of Ansible have already found it to be easy to learn; and these same users have often said (ref, ref) that they found Puppet more difficult.

While we have no reason to doubt their user testimony, it does need to be understood that nearly all of these users had bad experiences learning earlier versions of Puppet. Furthermore, the reasons people often give for why they found Puppet difficult to learn are not applicable in the latest versions.

For example, Puppet’s ordering is often said to be unintuitive and difficult to learn (ref), whereas people are often unaware that Puppet’s default ordering was changed to resemble Ansible’s in late 2013 (ref).

Likewise, Puppet 3 and earlier did not have explicit support for iteration (which led to a kind of work-around being commonly used (ref), whereas Puppet 4 added an easy to use iteration based on Ruby (ref).

Vendor training
A more objective measure of the learning curve for the two products is to look at the length of the vendor training courses. Both Red Hat and Puppet offer specialised training for their products; the entry-level training for Ansible is a four-day course, whereas the corresponding offering from Puppet is a three-day course.

Length of official documentation
The official documentation PDF for Ansible is 568 pages.
The official documentation PDF for Puppet is (unknown) – need a different way to compare, perhaps can use a spider to download all HTML and compare the size.

Length of popular published books
Another measure is books published and their lengths. A popular book on Ansible is Ansible Up and Running (334 pages). Ansible for DevOps (398 pages). Learning Puppet 4 (590 pages). Puppet 4 Essentials (246 pages).

Summary
While it is difficult to objectively measure, our view is that both DSLs are in fact difficult to learn. We believe that Puppet is not as difficult as it is reputed to be, and that Ansible is more difficult than it is claimed to be. However, we do not disagree that the Puppet DSL is more difficult to learn than Ansible.

Using the DSL to solve configuration management problems
Complex requirements
Ease of installation and learning curve tell us how fast the tools can be installed and how easily they can be picked up by staff.

But a DSL that is easy to learn is not the same as a DSL that easily solves problems in a given problem space. It is easy to learn Bash, for example, but it is not easy to solve configuration management problems in Bash.

An example of an easy configuration management problem might be configuring a Redis cache for a single team or application at a start-up; a difficult configuration management problem might be providing a Redis role that is customised to the requirements of all teams at a large organisation, or perhaps even a general purpose role for publication on Ansible Galaxy.

Conditional logic
Difficult configuration management problems always require conditional logic, but the only conditional statement currently in Ansible’s DSL is the when statement (ref).

Thus, via Ansible’s when statement, we can write:

tasks:
  - name: 'shut down'
    command: '/sbin/shutdown -t now'
    when: ansible_os_family == 'Debian'
Ansible’s when statement is essentially an inverted if conditional wrapped onto several lines of YAML. (To see the other languages that allow the inverted if conditional, ref.)

It should be immediately obvious that in the absence of an if/elsif/else statement, it is difficult to express anything other than simple conditional logic.

Imagine some simple conditional logic in Puppet:

if $facts['is_virtual'] {
  warning('Tried to include ntp on a VM; might be misclassified.')
}
elsif $facts['os']['family'] == 'Darwin' {
  warning('This NTP module does not yet work on Mac laptops.')
}
else {
  include ntp
} 
This would have to be expressed in Ansible as:

- debug:
  msg: 'Tried to include ntp on a VM; might be misclassified.'
  when: is_virtual == true
 
- debug:
  msg: 'This NTP role does not yet work on Mac laptops.'
  when: os.family == 'Darwin'
 
- include: ntp.yml
  when: (is_virtual != true and os.family != 'Darwin')
This is a problem for Ansible, and becomes increasingly problematic as complex requirements demand more and more conditional logic.

For real life examples, we need to only look at those handful of Ansible Galaxy roles that have so far matured to provide general purpose solutions. Two such roles are the Redis and Consul roles that we selected in our Galaxy v Forge analysis (see below). As expected, we find that most tasks are qualified by a different and sometimes complex conditional statements (ref, ref, ref).

Finally, be aware that the Ansible code above is what results when it is written by a team of skilled developers. In the hands of non-programmers – Ansible’s target user – Ansible code can quickly becomes very difficult to update and maintain.

Compounding this problem is the fact that Ansible does not have a debugger (the pry debugger is now available in Puppet (ref)), and it is not possible to write unit tests that validate complex conditional logic either.

Simple requirements
Of course, if the requirement is not complex then it is quick and easy to use Ansible to solve the configuration management problem. For example, if a developer needs to automate the set up of their own development environment, then it is likely to be easier to do this using Ansible than it would be using Puppet.
Likewise, at a small site, or a start up, or a single cloud project, conditional logic can (and should) largely be avoided.

Summary
Therefore, our view is that it is easy to solve the simpler problems of configuration management in both Puppet and Ansible.

Our view is that it is difficult to solve complex configuration managements problems in Puppet, but no more than in any other language; whereas it is very difficult to solve the same problems in Ansible.

This is one reason that we do not recommend Ansible to customers at large sites with complex configuration management requirements.

Ordering and resources
Default ordering in Puppet
Because there is a lot of confusion about Puppet’s ordering, we begin by dispelling a myth: the default ordering in Puppet is exactly the same as it is in Ansible and other imperative languages. Numerous articles on this topic incorrectly assert that Puppet’s order is either random or at least difficult to understand (ref, ref, ref, ref). In fact, Puppet’s ordering has not been random since the days of Puppet 2.6 (released in 2010), and its ordering has been top-to-bottom (“manifest ordered”) since late 2013.

A simple demonstration: ordering in Puppet
Here is a demonstration of this. Given a simple Puppet manifest:

file { '/a': ensure => file }
file { '/b': ensure => file }
file { '/c': ensure => file }
file { '/d': ensure => file }
file { '/e': ensure => file }
We can apply that manifest to see that, all other things being equal, resources are applied in the same order as they are written:

# puppet apply test.pp
Notice: Compiled catalog for myhost in environment production in 0.10 seconds
Notice: /Stage[main]/Main/File[/a]/ensure: created
Notice: /Stage[main]/Main/File[/b]/ensure: created
Notice: /Stage[main]/Main/File[/c]/ensure: created
Notice: /Stage[main]/Main/File[/d]/ensure: created
Notice: /Stage[main]/Main/File[/e]/ensure: created
Notice: Applied catalog in 0.02 seconds
History of ordering in Puppet
Some history helps to explain this lingering confusion.

In the earliest versions of Puppet, ordering was indeed random. And the random ordering of Puppet was controversial, and it is one of the reasons why Puppet was forked by Adam Jacobs to create Chef. Jacobs had observed a bug in a manifest that depended on an ordering of resources that could only be reproduced once in every 1000 runs. Luke Kanies and Adam disagreed about the significance of this, and finally, Adam created Chef. Shortly after, Luke changed the default ordering from random to deterministic – but still difficult to understand. The so-called title-hash ordering was born, and this was the default ordering in Puppet from 2010 through to end of 2013.

This post here announced the change to the default ordering in Puppet (ref).

Anchor pattern
To add insult to injury, Puppet Labs introduced a Bug #8040 some time around Puppet 2.7 that made it impossible to define ordering at the class level. A work-around was invented, known as the Anchor pattern. The bug was left open for so long, that the Anchor pattern word-around made its way into the Puppet training materials! The bug was not “fixed” until containment was introduced in Puppet 3.4.0 (again, in late 2013).

Certainly, Puppet Labs did themselves no favours here, and this contributed to the perception that Puppet’s ordering is confusing at best, and almost impossible to understand at worst.

Again, however, this is mainly a problem in legacy code, and unlikely to be a pain point for new users. It is our belief that this history helps to understand why Ansible is, somewhat mistakenly, perceived to be much easier to understand than Puppet.

Subscribe and notify
It should be noted that Puppet’s declarative ordering does still need to be understood in the case of subscribe and notify relationships.

In Puppet, subscribe and notify relationships exist when one resource needs to be refreshed when another resource changes. The example that is usually given is that of a service that needs to be restarted if a config file is updated.

However, Ansible’s handlers are declaratively ordered by a notify statement that is almost identical to Puppet.

In Ansible, for example, we write:

- name: 'template configuration file'
  template: >
    src=template.j2
    dest=/etc/foo.conf
  notify:
     - restart memcached
     - restart apache
Whereas in Puppet, we write:

file { 'template configuration file':
  ensure  => file,
  path    => '/etc/foo.conf',
  content => template('foo/template.erb'),
  notify  => [
    Service['Memcached'],
    Service['Apache'],
  ],
}
The real differences
By now, the reader might suspect that there is no difference at all between Puppet’s ordering and Ansible’s, but that is not quite true.

The directed acyclic graph
Puppet continues to build a directed acyclic graph (discussion) before its resources are applied, and the ordering in this graph still defines the ordering that resources are applied. Ansible does not do this; the ordering is only defined by the ordering in the playbooks, except in the case of notify relationships to handlers.

As a result, Puppet’s ordering is more flexible, but this flexibility is only available to those who understand it. It can also be abused, for example:

class a {
  file { '/a': ensure => file }
}
class b {
  file { '/b':
    ensure => file,
    before => File['/a'],
  }
}
include a
include b
Which leads to the following surprising ordering:

Notice: Compiled catalog for alexs-macbook-pro.local in environment production in 0.10 seconds
Notice: /Stage[main]/B/File[/b]/ensure: created
Notice: /Stage[main]/A/File[/a]/ensure: created
Notice: Applied catalog in 0.01 seconds
However, anyone with a basic understanding of programming best practices would see that the real problem with this code is action-at-a-distanceref – and not to mention poorly named resources!

Duplicate resources
The other real difference is that Puppet’s system of representing each resource as a node in a graph leads to a restriction that the resources may not be duplicated, whereas Ansible allows the same resources to be controlled in multiple playbooks.

Both approaches have their advantages and disadvantages.

The advantage of Puppet’s approach is that it forces the user to fully understand the final state of any given resource. If, on the other hand, Puppet allowed a class A to define a file A, and then allowed a class B to redefine the file A, it would, in most cases, be a bug at worst, and confusing at best.

That said, there are occasions when it would make sense to relax this rule and allow the same resource in multiple classes. For example, many applications might want to declare that the /etc directory should exist; so it is convenient that in Ansible you can do this.

Summary
Our view is that Ansible’s ordering is very easy to understand, and that Puppet’s is difficult. However, we do not expect the difficulty of Puppet’s ordering to be a real pain point, except in uncommon situations. Finally, we regard Puppet’s ordering as more flexible and powerful.

Forge v Galaxy
In this section we compare the Puppet Forge to Ansible Galaxy. We find Puppet to be the clear winner here.

Method
Selection procedure
Our method is to take the top 10 most downloaded modules on Puppet Forge, and compare these modules to the most downloaded equivalent role we can find at Ansible Galaxy. Then, we do the same in reverse; we take the top 10 most downloaded roles at Ansible Galaxy, and compare these to most downloaded equivalent module we can find at Puppet Forge.

However, Puppet Forge provides special categories of modules called Supported (modules which are fully supported by the company Puppet) and Approved modules (modules which Puppet has defined as meeting its own Supported modules quality levels). So, we give priority to Puppet modules in these two categories, if they exist.

We deleted modules that simply extended the Puppet framework itself. So, for instance, we deleted the stdlib Puppet module, which provides standard functions used by other Puppet modules, and we deleted Puppetlabs/powershell, which provides the Powershell exec provider for use on Windows.

The 10 Puppet modules we selected were:

apt
keepalived
epel
apache
postgresql
ntp
mysql
firewall
java
consul
The 10 Ansible roles we selected were:

redis
grafana
logrotate
composer
java
mysql
mongodb
nginx
php
apache
Since the modules for Java, MySQL and Apache are in the top 10 for both products, we ended up with a list of 17 modules in total to compare.

Assessment criteria
The criteria we chose to rate the modules were:

Lines of documentation in the README
Number of commits
Number of contributors
Number of parameters
Supported platforms
Lines of unit and integration test code
Results
For 15 of the 17 modules, the Puppet module won in all 6 of our assessment categories, and clearly had the superior offering.

In the case of the Consul module, the Ansible role had more complete documentation, and offered more features, and in the case of the Redis role, it had more documentation than the Puppet module.

Data
Forge Module	README	Commits	Contributors	Parameters	Platforms	Tests
https://github.com/puppetlabs/puppetlabs-apt	528	1139	143	25	5	Complete coverage
https://github.com/telusdigital/ansible-apt-repository	36	45	4	3	1	Basic
https://github.com/arioch/puppet-keepalived	349	207	37	20	7	Complete coverage
https://github.com/evrardjp/ansible-keepalived	72	79	11	4	unknown	None
https://github.com/stahnma/puppet-module-epel	146	111	15	48	3	Complete coverage
https://github.com/geerlingguy/ansible-role-repo-epel	37	40	6	3	2	Basic
https://github.com/puppetlabs/puppetlabs-apache	4136	2635	317	598	20	Complete coverage
https://github.com/geerlingguy/ansible-role-apache	156	190	17	32	6	Basic
https://github.com/puppetlabs/puppetlabs-postgresql	1799	1334	179	239	19	Complete coverage
https://github.com/ANXS/postgresql	99	255	44	353	4	Basic
https://github.com/puppetlabs/puppetlabs-ntp	646	736	89	57	37	Complete coverage
https://github.com/geerlingguy/ansible-role-ntp	66	58	3	6	6	Basic
https://github.com/puppetlabs/puppetlabs-mysql	1262	1419	210	167	21	Complete coverage
https://github.com/geerlingguy/ansible-role-mysql	181	256	27	57	5	Basic
https://github.com/puppetlabs/puppetlabs-firewall	973	1160	126	9	21	Complete coverage
https://github.com/geerlingguy/ansible-role-firewall	89	63	8	92	6	Basic
https://github.com/puppetlabs/puppetlabs-java	232	420	80	20	28	Complete coverage
https://github.com/geerlingguy/ansible-role-java	67	75	8	2	7	Basic
https://github.com/solarkennedy/puppet-consul	268	560	75	72	40	Complete coverage
https://github.com/savagegus/ansible-consul	360	326	46	96	3	Complete kitchen
https://github.com/arioch/puppet-redis	149	292	44	120	8	Complete coverage
https://github.com/DavidWittman/ansible-redis	334	255	27	73	4	Complete kitchen
https://github.com/voxpupuli/puppet-grafana	405	275	40	17	5	Complete coverage
https://github.com/Stouts/Stouts.grafana	194	72	9	104	unknown	Basic
https://github.com/voxpupuli/puppet-logrotate	192	188	27	14	18	Complete coverage
https://github.com/nickhammond/ansible-logrotate	71	41	10	2	unknown	Basic
https://github.com/willdurand/puppet-composer	220	101	12	8	6	Complete unit test coverage
https://github.com/geerlingguy/ansible-role-composer	77	80	8	10	4	Various configurations
https://github.com/puppetlabs/puppetlabs-mongodb	766	546	110	130	9	Complete coverage
https://github.com/Stouts/Stouts.mongodb	115	136	10	57	5	Basic
https://github.com/voxpupuli/puppet-nginx	347	1563	205	123	14	Complete unit test coverage
https://github.com/geerlingguy/ansible-role-nginx	224	150	25	30	4	Various configurations
https://github.com/voxpupuli/puppet-php	281	903	95	209	12	Complete coverage
https://github.com/geerlingguy/ansible-role-php	220	248	23	61	8	Various configurations
Summary
We have found that the Puppet Forge is superior to Ansible Galaxy. Modules at the Puppet Forge have more features, better documentation, a bigger contributor base, more supported platforms, and come with exhaustive unit and integration tests.

It is an important consideration.

With Puppet, it is likely that a project can re-use fully supported Puppet Forge modules, leaving only a small amount of code that would need to be written at the site. And even if it turns out that these modules need to be customised, the maintainers of Supported and Approved modules will often help, or at least quickly accept pull requests that merge the local features into the supported offering upstream.

With Ansible, it is more likely that a project will use roles found on Galaxy as either inspiration, or as a starting point, and then modify them to meet the local requirements. While it may be easy enough to do this, the long term cost is that the business ends up owning and maintaining all of this forked code for the project’s perhaps 3-5 year lifecycle.

Language features
Variables and data
Data types
Variables in Ansible 2.3 are similar to variables in Puppet 3 and earlier. Variables can be either strings, lists and dictionaries (a dictionary or dict is to Python and Ansible as a Hash is to Ruby and Puppet).

Puppet 4 introduced rich, strict data types, and became a type safe language. This has advantages and disadvantages. The advantage is that it is safer, and adds a lot of power to the language, and forces bugs to be found earlier.

The disadvantage would be that, for non-programmers, these data types might seem confusing.

Our feeling is that the learning curve issue is minor; because the most difficult concepts for non-programmers, as far as data types are concerned, are likely to be lists and hashes/dicts, and both of these exist in Ansible and Puppet.

Variable reassignment
It should be noted that Puppet has an odd limitation that its “variables” are in fact immutable, which means that they cannot be reassigned. In practice, this is not often called out as a pain point. Ansible does not have this limitation.

Data sources
In Puppet, data is stored in YAML files in Hiera, which is a file-based key-value store. Ansible, meanwhile, uses YAML files in its vars/ and group_vars/ hierarchy.

The latest version of Puppet uses Hiera 5, which is a complete rewrite of the old Hiera 3 and earlier. It has many features and is very powerful.

Conditionals
We discussed what we regard as a serious limitation in Ansible in the section above. To recap, Ansible has only a when statement, which is essentially an inverted if conditional.

Puppet, on the other hand, provides if/elsif/else statements; unless statements; case statements; and selectors.

Templates
Ansible’s templates use Jinja2, from the Flask web development framework, whereas Puppet’s templates can use either ERB (embedded Ruby), from the Ruby on Rails framework – and, more recently, they can also use EPP (embedded Puppet).

Feature-wise, both ERB and Jinja2 are similar, and both as easy or difficult to learn.

Puppet’s EPP, however, has advantages over the traditional ERB template approach. Firstly, parameters are passed explicitly to Puppet epp function via a parameters hash. This is clearer, and results in more readable, and more maintainable code.

Secondly, with EPP, Puppet’s DSL is also available inside templates, meaning there is now only one language that the user needs to learn.

Iteration
Both Puppet and Ansible have support for iteration, but where Puppet has a quite conventional form of iteration that is likely to be familiar to users of other programming languages, Ansible’s is quite unusual.

(There is actually an excellent article on the topic of Ansible’s loops here, and it should make quite clear to any newcomers that Ansible really is not as easy as its proponents say it is.)

The issue, again, is not that Ansible makes it impossible to do the things you will need to do; it is, rather, that Ansible’s unusual grammar does not scale well when the requirements are complex.

To give a code example:

Puppet allows us to write a loop like:

$users = {
  'bill' => {
    'uid'  => '10001',
    'home' => '/home/bill',
  },
  'fred' => {
    'uid'  => '10002',
    'home' => '/home/fred',
  },
}
 
$users.keys.each |$user| {
  notice("Creating user $user")
 
  user { $user:
    ensure => present,
    uid    => $users[$user]['uid'],
  }
 
  file { $users[$user]['home']:
    ensure => directory,
  }
}  
In Ansible, because we cannot open a code block, we need to write:

(to do.)

Automated testing
Syntax and Linting
Unit testing and Rspec-puppet
Integration testing: Beaker v Kitchen Ansible

