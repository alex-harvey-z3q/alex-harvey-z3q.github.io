Building a highly available ELK solution with Puppet, Part II: The base profile
by Alex Harvey | Mar 28, 2016 | blogs | 0 comments

NOTE: this series is a work-in-progress that will be finished in due course.  I leave it up here because the code and approach is likely to be nonetheless useful to people engaged in building a similar ELK / Puppet solution.

Table of Contents	
Introduction
Configuring the Puppetfile
Why Librarian-puppet
Puppetfile config for base profile
Firewall configuration
A note about alexharvey/firewall_multi
Set up for puppetlabs/firewall
Add a rule for inbound ssh
A note about default parameter values
Yum configuration
The profile::base::yum class
Generating the list of default CentOS repos
Introduction
In this second part of our series, ‘Building a highly available ELK solution with Puppet’, we look at our example base profile.

The example is artificially simple, and provides an illustration of the concepts for readers who are new to the roles and profiles pattern, and allows me to make some general points about writing roles and profiles that inform my decisions in subsequent ELK-related posts. Most readers will already have their own base profile, and if not, will probably have requirements that go beyond this contrived example.

If you are already familiar with the roles and profiles pattern, you may want to read the section about the yum configuration, and you may be interested in the firewall_multi module.

As mentioned in part I, the source code is available at Github. It is licensed under the MIT license.

Configuring the Puppetfile
Before we can write the base profile we need to install the Puppet Forge modules that it will depend upon, and to do that, we must set up our Puppetfile. If you have not used a Puppetfile before, have a look at the documentation here.

Why Librarian-puppet
It should be noted that I am using Tim Sharpe’s Librarian-puppet, the original Puppetfile processor and, in my opinion, still the best. Many users will be using r10k both to install modules as specified in Puppetfile, and also to deploy their code into target environments. Meanwhile, Puppet Enterprise users may be using Code Manager, which uses r10k under the hood.

The advantage of Librarian-puppet is that it is simpler, and it resolves dependencies. And if you, like me, intend to deploy your code onto Puppet Masters using the deployment capabilities of your CI/CD system, you may find that Librarian-puppet is still the right choice.

Puppetfile config for base profile
Our base profile requires the following modules:

puppetlabs/stdlib
puppetlabs/ntp
alexharvey/firewall_multi
We therefore add the following lines to our Puppetfile (source code):

forge 'https://forgeapi.puppetlabs.com'
mod 'puppetlabs/stdlib'
mod 'puppetlabs/ntp'
mod 'alexharvey/firewall_multi'
We will talk more about the alexharvey/firewall_multi module below.

Firewall configuration
A note about alexharvey/firewall_multi
If you work in a large enterprise, the chances are your firewall needs to support large-ish arrays of source networks.

Many users of Puppet have expected that the puppetlabs/firewall type would accept arrays of source addresses, e.g. here, here.  This might seem like a limitation of the module, although a firewall resource is a representation of an iptables rule, and these rules themselves don’t support arrays.

Traditionally, the expectation has been that users would write their own defined type wrapper to handle such arrays, e.g. here.  However, I believe there should be standard solutions to standard problems, and I created firewall_multi as a drop-in replacement for (actually, a front end to) firewall that accepts arrays of sources (and a few other parameters).

To illustrate, the following code:

firewall_multi { '00100 accept inbound ssh':
  source =&gt; ['1.1.1.1/24', '2.2.2.2/24'],
  action =&gt; 'accept',
  proto  =&gt; 'tcp',
  dport  =&gt; '22',
}
Is equivalent to:

firewall { '00100 accept inbound ssh from 1.1.1.1/24':
  source =&gt; '1.1.1.1/24',
  action =&gt; 'accept',
  proto  =&gt; 'tcp',
  dport  =&gt; '22',
}
firewall { '00100 accept inbound ssh from 2.2.2.2/24':
  source =&gt; '2.2.2.2/24',
  action =&gt; 'accept',
  proto  =&gt; 'tcp',
  dport  =&gt; '22',
}
If you don’t need array support, feel free to s/firewall_multi/firewall/g.

Set up for puppetlabs/firewall
We follow the standard setup of the puppetlabs/firewall module, as described in its README.

We create a class profile::base::firewall that will be included in our base profile:

class profile::base::firewall {
  include firewall
 
  include profile::base::firewall::pre
  include profile::base::firewall::post
 
  resources { 'firewall':
    purge =&gt; true,
  }
}
Then we add the profile::base::firewall::pre and profile::base::firewall::post classes, the rules that will always be applied before and after all other rules:

# Rules which are applied to all nodes before any others.
class profile::base::firewall::pre {
  Firewall {
    require =&gt; undef,
  }
  firewall { '00000 accept all icmp':
    proto   =&gt; 'icmp',
    action  =&gt; 'accept',
  }
  -&gt;
  firewall { '00001 accept all to lo interface':
    proto   =&gt; 'all',
    iniface =&gt; 'lo',
    action  =&gt; 'accept',
  }
  -&gt;
  firewall { '00002 accept related established rules':
    proto   =&gt; 'all',
    state   =&gt; ['RELATED', 'ESTABLISHED'],
    action  =&gt; 'accept',
  }
}
And:

# Rules which are applied to all nodes AFTER any others.
class profile::base::firewall::post () {
  firewall { '99998 log packet drops':
    jump       =&gt; 'LOG',
    proto      =&gt; 'all',
    log_prefix =&gt; 'iptables InDrop: ',
    log_level  =&gt; 'warn',
  }
  -&gt;
  firewall { '99999 drop all':
    proto   =&gt; 'all',
    action  =&gt; 'drop',
    before  =&gt;  undef
  }
}
Then in our site.pp:

Firewall {
  require =&gt; Class['profile::base::firewall::pre'],
  before  =&gt; Class['profile::base::firewall::post'],
}
Finally we create the base profile itself profile::base:

class profile::base (
  Hash $firewall_multis,
) {
  create_resources(firewall_multi, $firewall_multis)
  include profile::base::firewall
}
And we would need to initialise that in Hiera with an empty hash:

profile::base::firewall_multis: {}
(If you’re wondering why I don’t just provide a default value of an empty hash inside the class, see the ‘Note about default parameter values’ section below for discussion.)

Add a rule for inbound ssh
At this point, we realise that our base class needs to provide at least one firewall rule for all our hosts, namely a rule for inbound ssh.  To do that, we replace our empty hash in Hiera with:

profile::base::firewall_multis: 
  '00099 accept tcp port 22 for ssh':
    dport: '22'
    action: 'accept'
    proto: 'tcp'
    source:
      - '0.0.0.0/0'
Or if you had decided to use the standard puppetlabs/firewall directly, and not alexharvey/firewall_multi:

profile::base::firewalls: 
  '00099 accept tcp port 22 for ssh':
    dport: '22'
    action: 'accept'
    proto: 'tcp'
    source: '0.0.0.0/0'
And back in your class you’d have:

class profile::base (
  Hash $firewalls,
) {
  create_resources(firewall, $firewalls)
  include profile::base::firewall
}
A note about default parameter values
Some may wonder why I did not not place a default parameter value for the firewall rules hash in the class. In other words, why did I not do this?

class profile::base (
  Hash $firewall_multis = {},
) {
  create_resources(firewall_multi, $firewall_multis)
  include profile::base::firewall
}
Such an approach, to be sure, is defensible, although I personally rarely use parameter defaults in Puppet profiles. (In modules, they are indispensable; another story.)

In my view, Puppet is a language that offers developers a lot of rope. Puppet’s flexibility is its greatest strength and its greatest weakness. There are many ways of defining and accessing data in Puppet:

Hiera, via implicit automatic parameter lookups
Hiera, via explicit Hiera calls in parameter definitions
Hiera, via explicit Hiera calls inside classes
Default values defined in params classes
Parameter defaults in classes
Values looked up out of scope
Values hardcoded in classes
Facter values
I religiously follow the keep-it-simple principle in my code, and a part of that for me means minimising the maintainer’s time spent thinking about and opening files relating to finding the configuration data. If a developer takes an all-of-the-above approach to data, the code will definitely be confusing and frustrating.

As such, when I am writing roles and profiles, I insist that all of my data must always come from Hiera, and if it doesn’t come from Hiera, it means that I don’t consider it to be data at all. All of my parameters are mandatory, and all of my mandatory parameters are populated by the automatic parameter lookup from Hiera feature. I never hard-code values in classes, or make explicit Hiera calls via the hiera() function. Facter is used where appropriate, and always fully scoped.

Even in this specific case, where the “data” is an empty hash, some may well ask, how is an empty hash “data”? Sure, it’s not really data. Even here, though, I still prefer to have mandatory parameters in my classes, because I want compilation to fail if there’s nothing in Hiera. I would say the developer has two choices here: If an empty hash is really required here, either make this clear from within Hiera, or otherwise, take it out of the manifest altogether.

Yum configuration
The profile::base::yum class
Some of the modules that we will use (namely, Elasticsearch, Logstash and Kibana 4) optionally configure their Yum (and Apt) repos, whereas others don’t, and since our overall solution depends on quite a number of Yum repos, the overall simplicity demands a Yum configuration that is kept in one place.

As such, we will define a profile::base::yum that takes care of configuring all of these.

Before we do that, however, we’ll add a special run stage for Yum to our site.pp:

stage { 'pre': before =&gt; Stage['main'] }
If you have not used run stages before, have a look at Gary Larizza’s post on this topic, where it is explained well.

Then we define a profile profile::base::yum, which we will include in profile::base:

class profile::base::yum (
  Hash $repos,
) {
  Yumrepo {
    stage =&gt; 'pre',
  }
  create_resources(yumrepo, $repos)
 
  # Since we must purge the file resources in
  # /etc/yum.repos.d/, we must also declare the 
  # associated files to prevent them also
  # being purged.
 
  keys($repos).each |String $yumrepo| {
    file { "/etc/yum.repos.d/${yumrepo}.repo": }
    -&gt;
    Yumrepo[$yumrepo]
  }
  file { '/etc/yum.repos.d/':
    ensure  =&gt; directory,
    recurse =&gt; true,
    purge   =&gt; true,
  }
}
If all of that is confusing, don’t panic! It is, I promise, the most difficult piece of code anywhere in this project.  And my preference would have been to use jlambert121/yum, but the Elasticsearch module requires us to use ceritsc/yum, which lacks the above functionality. If that issue is resolved, I will update my code and this post. (See here to learn more about this open issue.)

And if you need a Puppet 3.x compatible implementation of this, you can again copy the jlambert121/yum code.

Finally, we update profile::base:

class profile::base (
  Hash $firewall_multis,
) {
  create_resources(firewall_multi, $firewall_multis)
  include profile::base::firewall
  include profile::base::yum
}
Generating the list of default CentOS repos
To populate the default repos that are delivered by the OS (in this case, CentOS 7), I used the puppet resource tool, after booting the Puppet Labs CentOS 7 Vagrant box image, and fed this through a Perl script I wrote called pp_to_yaml.pl.

# puppet resource yumrepo | ./pp_to_yaml.pl &gt; /vagrant/yumrepo.pp
Note that in Puppet 4, a --to_yaml option has been added to the puppet resource tool, making my script unnecessary. I leave it in for those still using Puppet 3.x.

For the sake of not providing repetitive data, I won’t provide the output. Example Hiera data is here.
