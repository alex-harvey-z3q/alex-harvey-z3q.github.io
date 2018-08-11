Building a highly available ELK solution with Puppet, Part III: Elasticsearch backend
by Alex Harvey | Mar 28, 2016 | blogs | 0 comments

NOTE: this series is a work-in-progress that will be finished in due course.  I leave it up here because the code and approach is likely to be nonetheless useful to people engaged in building a similar ELK / Puppet solution.

Table of Contents	
Introduction
Puppetfile configuration
Installing the JDK
The profile profile::jdk
Installing Elasticsearch
Configuring the repo
The profile profile::elasticsearch
The user accounts
The profile profile::elasticsearch::data_node
The LVM configuration
The Elasticsearch instance configuration
Instance declaration
Hiera data for a cluster of 3-or-more ES instances
Network configuration
discovery.zen.minimum_master_nodes
The kibana node
JAVA_HOME
Setting the ES_HEAP_SIZE
Hiera data for a single instance ES
index.number_of_replicas
Other tunables
Templates, plugins, and curator
The firewall configuration
Firewall configuration
Putting it all together
Related roles
Automated tests
Rspec-puppet tests
Beaker tests
The spec_helper_acceptance.rb file
The spec/acceptance/role_es_data_node_spec.rb file
Define some code to apply
Puppet apply and check for idempotence
Tests for installed packages
Tests for configuration files
Tests for log files
Tests for commands
Running the Beaker tests
Conclusion
Introduction
Elasticsearch is a Java-based open-source search engine built on top of Apache Lucene, and released under the terms of the Apache license. It provides a distributed, multitenant-capable search engine behind a convenient RESTful JSON API. Today, it is the most popular enterprise search engine in the world.

In this third part of our series, ‘Building a highly available ELK solution with Puppet’, we look at how to build an Elasticsearch 2.2 cluster using the latest Elasticsearch, the latest Puppet 4, and the latest Elastic.co Elasticsearch Puppet module.

Here we look at the profiles profile::jdk, profile::elasticsearch, and profile::elasticsearch::data_node. We will discuss Hiera data for a single-node and clustered configuration. This will involve configuring Yum; installing the JDK; managing the elasticsearch user and group; configuring an LVM volume for Elasticsearch data; installing and configuring the Elasticsearch application; and configuring the firewall. We will discuss in passing some of our views on Puppet programming best practices, and justify some of the choices we have made.

Puppetfile configuration
We add the following modules to our Puppetfile for the Elasticsearch cluster:

forge 'https://forgeapi.puppetlabs.com'
mod 'thias/sysctl',
  :git => 'https://github.com/thias/puppet-sysctl.git'
mod 'elasticsearch/elasticsearch',
  :git => 'https://github.com/elastic/puppet-elasticsearch.git'
...
All of these modules will be installed locally when we call our :librarian_spec_prep Rake task:

$ bundle exec rake librarian_spec_prep
(It might take a while the first time you run it.)

Likewise, we provide a :librarian_update task that removes the Puppetfile.lock and updates all modules to the latest versions. This may also come in handy from time to time.

Installing the JDK
Because Elasticsearch is a Java-based application, we must of course install Java and a JDK. In the past it was recommended to use the Oracle JDK, and some people will no doubt still prefer to use the Oracle JDK. However, installing the Oracle JDK is complicated, and the license is tricky.

According to the latest docs, it is safe to use either the Oracle JDK or the OpenJDK, although Elastic.co advise to ensure we keep this up to date.

The profile profile::jdk
We have the following profile for the JDK (source code):

class profile::jdk (
  String $package,
) {
  package { $package:
    ensure => installed,
  }
}
We have moved it to its own profile so that it can also be included by all the ELK components that require a JDK, namely the Logstash Shipper, Logstash Indexer and the Elasticsearch data and client nodes (more on them in subsequent posts).

Readers who are new to Puppet 4 may be surprised by the keyword String. Declaring the input parameter as of type String means I don’t need to call Stdlib’s validate_string() function.

In Puppet 3, we would instead write:

class profile::jdk (
  $package,
) {
  validate_string($package)
 
  package { $package:
    ensure => installed,
  }
}
And of course this profile depends on one piece of Hiera data, namely the package name. Sadly, the OpenJDK package does not follow convention for RPM naming, with part of the package version appearing in the package name here.

So in Hiera I’ll have the following item of data:

profile::jdk::package: 'java-1.8.0-openjdk'
Installing Elasticsearch
Configuring the repo
For the Elasticsearch repo, we can now add to Hiera the following lines:

profile::base::yum::repos:
  ...
  'elasticsearch-2.x':
    descr: 'Elasticsearch repository for 2.x.x packages'
    baseurl: 'http://packages.elasticsearch.org/elasticsearch/2.x/centos'
    gpgcheck: '1'
    gpgkey: 'http://packages.elastic.co/GPG-KEY-elasticsearch'
    enabled: '1'
Later we will also need to install the elastic-curator package from EPEL. So we also add:

'epel':
  ensure: 'present'
  descr: 'Extra Packages for Enterprise Linux 7 - $basearch'
  enabled: '1'
  failovermethod: 'priority'
  gpgcheck: '1'
  gpgkey: 'https://getfedora.org/static/352C64E5.txt'
  mirrorlist: 'https://mirrors.fedoraproject.org/metalink?repo=epel-7&arch=$basearch'
The profile profile::elasticsearch
Returning to our Elasticsearch profiles, we must support profiles for two Elasticsearch node types, namely the master-eligible data node — the ES nodes that store actual data — and a client node, which is required by Kibana to view the data in the cluster.

We also need to support application of both of these profiles on the same host; we do this in role::elk_node and role::elk_node_test. Thus, we must separate out common configuration in a common profile::elasticsearch and include this in specific profiles, profile::elasticsearch::data_node and profile::elasticsearch::client_node.

The common profile contains:

The JDK
The Elasticsearch user and group
The Elasticsearch class which contains:
The package
Config and log file directories
/usr/lib/tmpfiles.d/elasticsearch.conf
The init (systemd) script
/etc/sysconfig/elasticsearch
/etc/elasticsearch/elasticsearch.yml
/etc/elasticsearch/logging.yml
Note that the content of these latter files is modified by data passed into the Elasticsearch instance types.  More on that later.

The user accounts
A common problem in configuration management is that packages like RPMs tend to create users in their post-install scripts, and they tend to grab the next available UIDs/GIDs in the < 500 range. This creates a configuration management problem if, like me, you want to know that all of your users will have the same UIDs/GIDs on all of your server instances.

The workaround is to have Puppet explicitly manage the users and group, and to ensure that Puppet manages them prior in the dependency graph to the package.

A longer term solution would be for all Puppet Forge modules to optionally manage the UIDs/GIDs.  That’s something I am advocating for, and I may raise a pull request at some stage to add this functionality into the Elasticsearch module, where in my view, it belongs.

Thus in our profile we have (source code):

class profile::elasticsearch (
  Integer[30000] $uid,
  Integer[30000] $gid,
) {
  include profile::jdk
 
  # Manage the user and group to prevent UID and
  # GID assignment by the RPM.
 
  group { 'elasticsearch':
    ensure => present,
    gid    => $gid,
  }
  user { 'elasticsearch':
    ensure     => present,
    uid        => $uid,
    gid        => $gid,
    home       => '/usr/share/elasticsearch',
    shell      => '/sbin/nologin',
    managehome => false,
  }
  include elasticsearch
  User['elasticsearch'] -> Package['elasticsearch']
}
Here, we understand that Package['elasticsearch'] is declared in the elasticsearch and we declare a relationship, User['elasticsearch'] -> Package['elasticsearch'].

For the data, we pass in:

profile::elasticsearch::uid: 30000
profile::elasticsearch::gid: 30000
You can, of course, use whatever UIDs/GIDs you please.

The profile profile::elasticsearch::data_node
Moving along, the more specific profile will contain:

The Elasticsearch instance manages the following:

The LVM configuration.
The elasticsearch::instance which contains:
Additions to /etc/elasticsearch/elasticsearch.yml
Additions to /etc/elasticsearch/logging.yml
The Elasticsearch service.
Any elasticsearch::templates, and elasticsearch::plugins.
Any elastic-curator cron jobs.
The firewall configuration.
The LVM configuration
Not everyone, in this age of cloud computing, will require an LVM configuration, or separate LVM volumes for their Elasticsearch data. If you do, however, the configuration is included.

We use the standard puppetlabs/lvm module, and more specifically, we used the lvm::volume_group defined type interface.

We also require a custom fact $::espv that reports back the block device path to that filesystem.

We include a line:

validate_absolute_path($::espv)
The purpose of this line is to force compilation failure if the provisioning of the node has not created the custom fact. My expectation is that a provisioning system like Terraform would run a post-install script that would create an external fact.

An example of such a post-install script might be:

#!/bin/bash
mkdir -p /etc/facter/facts.d
echo "espv=$(pvs | awk 'END {print $1}')" >> /etc/facter/facts.d/facts.txt
We assume here that the LVM volume appears last in the pvs. Your mileage may vary.

Now to create the LVM config in Puppet we define the VGs as a hash in Hiera:

profile::elasticsearch::data_node::datadir: '/srv/es'
profile::elasticsearch::data_node::volume_groups:
  esvg00:
    physical_volumes:
      - "%{::espv}"
    logical_volumes:
      eslv00:
        mountpath: "%{hiera('profile::elasticsearch::data_node::datadir')}"
And then in our manifest:

class profile::elasticsearch::data_node (
  Hash $volume_groups,
  ...
) {
  create_resources(lvm::volume_group, $volume_groups)
  ...
}
If that Hiera lookup from within Hiera is too scary, too ugly, or too many characters, one could simply duplicate the mount path '/srv/es'. I wouldn’t have a problem with that personally. For the documentation on how to look up Hiera data from within Hiera, see here.

The Elasticsearch instance configuration
Instance declaration
The Elasticsearch module provides a defined type elasticsearch::instance which declares an Elasticsearch instance. The module, therefore, supports running multiple instances on the same node, and, as already mentioned, we rely on this feature when we spin a data node instance and client node instance on the same host in the role::elk_node and role::elk_node_test.

The main configuration data is passed in as a hash to the elasticsearch::instance.

We declare the instance as follows:

class profile::elasticsearch::data_node (
  String $datadir,
  Hash $config,
  Hash $init_defaults,
  Hash $es_templates,
  ...
) {
  $cluster_name = $config['cluster.name']
  include elasticsearch
  include profile::elasticsearch
 
  elasticsearch::instance { $cluster_name:
    init_defaults => $init_defaults,
    config        => $config,
    datadir       => $datadir,
  }
Hiera data for a cluster of 3-or-more ES instances
profile::site_elasticsearch::data_node::datadir: '/srv/es'
profile::site_elasticsearch::data_node::config:
  'cluster.name': 'es01'
  'node.name': "es01_%{::hostname}"
  'network.host': "%{::ipaddress}"
  'http.enabled': true
  'node.master': true
  'node.data': true
  'discovery.zen.ping.unicast.hosts':
    - "data01.%{::domain}:9300"
    - "data02.%{::domain}:9300"
    - "data03.%{::domain}:9300"
    - "kibana01.%{::domain}:9300"
  'discovery.zen.minimum_master_nodes': 2
profile::site_elasticsearch::data_node::init_defaults:
  JAVA_HOME: '/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.65-0.b17.el6_7.x86_64'
  ES_HEAP_SIZE: '10g'
  MAX_MAP_COUNT: '262144'
  ES_JAVA_OPTS: '"-XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintTenuringDistribution -Xloggc:/var/log/elasticsearch/tcom01/gc.log -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=10 -XX:GCLogFileSize=10M"'
Points to note here:

Network configuration
This network configuration is based on recommendations for a simple configuration that I obtained from Elastic.co at discuss.elastic.co here.

I have opted for a static unicast network configuration that uses the HTTP protocol for node communication for simplicity. If I need to add additional nodes, I’ll add them manually, and update this Hiera data. It’s not hard.

The disadvantage, though, is also its simplicity. Elasticsearch supports a variety of node discovery protocols (for Azure, EC2 & Google Compute etc), and we’re not using them. (Advanced discovery and auto-scaling is beyond the scope of this article.)

discovery.zen.minimum_master_nodes
Quoting the documentation,

The discovery.zen.minimum_master_nodes sets the minimum number of master eligible nodes that need to join a newly elected master in order for an election to complete and for the elected node to accept it’s mastership. The same setting controls the minimum number of active master eligible nodes that should be a part of any active cluster. If this requirement is not met the active master node will step down and a new mastser election will be begin.

This setting must be set to a quorum of your master eligible nodes. It is recommended to avoid having only two master eligible nodes, since a quorum of two is two. Therefore, a loss of either master node will result in an inoperable cluster.

The kibana node
Note also that we assume the existence of a host ‘kibana01’. That, of course, will be the Kibana node’s ES client node instance that we will build later in the series. If you don’t need the Kibana node (i.e. if you are building an Elasticsearch cluster is not be a component in an ELK solution), simply delete that line.

JAVA_HOME
This is a nuisance. To find the JAVA_HOME, I just installed the package manually, and ran rpm -ql java-1.8.0-openjdk. Perhaps someone java-savvier than me will inform me in the comments of a better way.

Setting the ES_HEAP_SIZE
For Elastic.co’s recommendations on setting the heap size, see here. If that’s too much information, give it half of your physical RAM, unless that’s greater than 32GB, in which case give it 32GB.

Hiera data for a single instance ES
When running the whole thing on a single instance, or on your laptop for testing, we have a different data set to pass in here:

profile::elasticsearch::data_node::config:
  'cluster.name': 'es01'
  'node.name': "es01_%{::hostname}"
  'http.enabled': true
  'node.master': true
  'node.data': true
  'index.number_of_replicas': 0
Most of this is self-explanatory except for:

index.number_of_replicas
Since we’re a one-node cluster, shard replicas are impossible, so we set this to 0, or the cluster won’t go “green”. For more on this topic, see the docs.

Other tunables
The Elasticsearch documentation recommends disabling swapping, and provides a number of ways of doing this on Linux. I opted for a kernal tunable, vm.swappiness.  In addition, it is recommended to increase the value of vm.max_map_count.

Our profile profile::elasticsearch::data_node contains:

class profile::elasticsearch::data_node (
  Integer[0,1] $vm_swappiness,
  Integer $vm_max_map_count,
  ...
) {
  ...
  $cluster_name = $config['cluster.name']
 
  sysctl { 'vm.swappiness': value => $vm_swappiness }
  ->
  sysctl { 'vm.max_map_count': value => $vm_max_map_count }
  ->
  Service["elasticsearch-instance-${cluster_name}"]
and

profile::elasticsearch::data_node::vm_swappiness: 0
Now some may wonder, justifiably, if I really needed to parameterise this setting? I thought long and hard about this, and opted to parameterise, because I want all of this configuration visible to the maintainer who browses the Hiera data. If that’s not important to you, by all means, hardcode it in the manifest.

Note also, in case it’s not obvious, that we need the kernel tunables to be set before the Elasticsearch service starts.

(I try to avoid the require, before, subscribe and notify metaparameters. I just find the arrow notations to be easier to read. Some will, no doubt, disagree.)

Templates, plugins, and curator
If you need to install custom templates, plugins and curator clean up jobs, we pass them in as a hash:

class profile::elasticsearch::data_node (
  Hash $es_templates,
  Hash $es_plugins,
  Hash $curator_jobs,
  ...
) {
  create_resources(elasticsearch::template, $es_templates)
  create_resources(elasticsearch::plugin, $es_plugins)
 
  package { 'elastic-curator':
    ensure => installed,
  }
  create_resources(cron, $curator_jobs)
  ...
}
And hiera data might look something like:

profile::elasticsearch::data_node::es_templates:
  logstash:
    file: 'puppet:///modules/profile/logstash/logstash.json'
profile::elasticsearch::data_node::es_plugins:
  'lmenezes/elasticsearch-kopf':
    instances: 'es01'
  'jetty':
    url: 'https://oss-es-plugins.s3.amazonaws.com/elasticsearch-jetty/elasticsearch-jetty-1.2.1.zip',
    instances: 'es01'
profile::elasticsearch::data_node::curator_jobs:
  curator_delete:
    command: '/usr/bin/curator --master-only --logfile /var/log/elasticsearch/curator.log delete --older-than 30'
    hour: '2'
    minute: '05'
The firewall configuration
As discussed in Part II, we use the alexharvey/firewall_multi module, which is a drop-in replacement (front end) to the standard puppetlabs/firewall module that supports arrays of source addresses. Again, if you don’t need array support, feel free to call the firewall types directly.

Firewall configuration
Our Elasticsearch data nodes use HTTP for communication on port 9200. This is the only port we need to open for Elasticsearch.

As such we have:

class profile::elasticsearch::data_node (
  Hash $firewall_multis,
  ...
) {
  create_resources(firewall_multi, $firewall_multis)
  ...
}
And in Hiera:

profile::elasticsearch::data_node::firewall_multis:
  '00100 accept tcp port 9200 for elasticsearch':
    dport: '9200'
    action: 'accept'
    proto: 'tcp'
    source:
      - '1.1.1.1/24'
      - '2.2.2.2/24'  # etc
(Note that I have not discussed a base profile yet. That will be the right place for other common rules, e.g. in bound port 22.)

Putting it all together
Putting all of this together we end up with a profile like this (source code):

class profile::elasticsearch::data_node (
  String $datadir,
  Hash $firewall_multis,
  Hash $volume_groups,
  Hash $config,
  Hash $init_defaults,
  Hash $es_templates,
  Hash $es_plugins,
  Hash $curator_jobs,
  Integer[0,1] $vm_swappiness,
) {
  validate_absolute_path($::espv)
 
  create_resources(firewall_multi, $firewall_multis)
  create_resources(lvm::volume_group, $volume_groups)
 
  include elasticsearch
  include profile::elasticsearch
 
  $cluster_name = $config['cluster.name']
 
  elasticsearch::instance { $cluster_name:
    init_defaults => $init_defaults,
    config        => $config,
    datadir       => $datadir,
  }
  Mount[$datadir] -> File[$datadir]
 
  create_resources(elasticsearch::template, $es_templates)
  create_resources(elasticsearch::plugin, $es_plugins)
 
  package { 'elastic-curator':
    ensure => installed,
  }
  create_resources(cron, $curator_jobs)
 
  sysctl { 'vm.swappiness': value => $vm_swappiness }
  ->
  Service["elasticsearch-instance-${cluster_name}"]
}
And in Hiera something like:

# profile::elasticsearch
 
profile::elasticsearch::uid: 30000
profile::elasticsearch::gid: 30000
 
# profile::elasticsearch::data_node
 
profile::elasticsearch::data_node::firewall_multis:
  '00100 accept tcp ports 9200 for elasticsearch':
    dport: '9200'
    action: 'accept'
    proto: 'tcp'
    source:
      - '0.0.0.0/0'
profile::elasticsearch::data_node::datadir: '/srv/es'
profile::elasticsearch::data_node::volume_groups:
  esvg00:
    physical_volumes:
      - "%{::espv}"
    logical_volumes:
      eslv00:
        mountpath: "%{hiera('profile::elasticsearch::data_node::datadir')}"
profile::site_elasticsearch::data_node::config:
  'cluster.name': 'es01'
  'node.name': "es01_%{::hostname}"
  'network.host': "%{::ipaddress}"
  'http.enabled': true
  'node.master': true
  'node.data': true
  'discovery.zen.ping.unicast.hosts':
    - "data01.%{::domain}:9300"
    - "data02.%{::domain}:9300"
    - "data03.%{::domain}:9300"
    - "kibana01.%{::domain}:9300"
  'discovery.zen.minimum_master_nodes': 2
profile::site_elasticsearch::data_node::init_defaults:
  JAVA_HOME: '/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.65-0.b17.el6_7.x86_64'
  ES_HEAP_SIZE: '10g'
  MAX_MAP_COUNT: '262144'
  ES_JAVA_OPTS: '"-XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintTenuringDistribution -Xloggc:/var/log/elasticsearch/tcom01/gc.log -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=10 -XX:GCLogFileSize=10M"'
profile::elasticsearch::data_node::vm_swappiness: 0
profile::elasticsearch::data_node::es_templates:
  logstash:
    file: 'puppet:///modules/profile/logstash/logstash.json'
profile::elasticsearch::data_node::es_plugins:
  'lmenezes/elasticsearch-kopf':
    instances: 'es01'
  'jetty':
    url: 'https://oss-es-plugins.s3.amazonaws.com/elasticsearch-jetty/elasticsearch-jetty-1.2.1.zip',
    instances: 'es01'
profile::elasticsearch::data_node::curator_jobs:
  curator_delete:
    command: '/usr/bin/curator --master-only --logfile /var/log/elasticsearch/curator.log delete --older-than 30'
    hour: '2'
    minute: '05'
Related roles
Having finished our Elasticsearch data node profile, we include it in three of our roles:

role::es_data_node
role::elk_node_test
role::elk_node

The ES data node is just our base profile and our Elasticsearch data node profile (source code):

class role::es_data_node {
  include profile::base
  include profile::es_data_node
}
Automated tests
Rspec-puppet tests
Now that we have our role and our profile, we need a single Rspec-puppet test, a simple test that confirms that role compiles when included. This gives us quick feedback that:

We haven’t made any typos or syntax errors.
We have supplied valid Hiera data.
Our dependent Puppet Forge modules all work have the data they need.
(If you are wondering about the second point, namely that compilation proves we have supplied valid Hiera data, this follows from our decision to not provide parameter default values in our profiles. If we had instead provided default values for our profile parameters, the code would compile fine and we wouldn’t find out about the missing data unless we wrote additional assertions in Rspec-puppet about the data, or additional Beaker tests. This is perhaps the main reason I don’t use default values in parameters.)

Another choice we have made is whether to test at the level of the profile or the role or both. Well, it would be almost redundant to test the profiles and the roles, because the role compiling proves that all of its included profiles compile. And testing at the role level also tests the integration of the profiles. It might pick up, for instance, a situation where both profiles try to manage the same resource.

As a matter of fact, in my production version of this code, I have nodes defined in site.pp, as well as some node-specific data in Hiera. I therefore move the compilation tests to the node level, where each node simply includes one role. Here, though, I don’t have node definitions, so I’m testing the roles instead.

Our only test is in spec/classes/role_es_data_node_spec.rb

require 'spec_helper'
 
describe 'role::es_data_node' do
  it { is_expected.to compile.with_all_deps }
end
To run our tests:

I firstly run librarian-puppet update to ensure that I have the latest versions of the Puppet Forge modules:

$ bundle exec rake librarian_update
Running cd spec/fixtures && bundle exec librarian-puppet update 
I run lint:

$ bundle exec rake lint
$
No output means all is good.

I run validate:

$ bundle exec rake validate
---> syntax:manifests
---> syntax:templates
---> syntax:hiera:yaml
I run the rspec-tests:

$ bundle exec rspec spec/classes/role_es_data_node_spec.rb 
.
 
Finished in 5.07 seconds (files took 1.32 seconds to load)
1 example, 0 failures
Beaker tests
I use Beaker to do the real testing.

My philosophy about Beaker (Serverspec) testing is that the tests provide more than just confirmation that the code does what we expect it to do, but also provides executable documentation of our configuration. These tests describe a blueprint for a working server node, including commands used to verify the application configuration, locations of the log files, start and stop commands and the rest of it. These tests, therefore, remove (or at least could in principle remove) the need for an Ops Wiki.

There is not a lot of documentation out there on how to use Beaker to test roles and profiles, and I’m hoping that this series will also help to fill that gap. There is, however, one very good post that everyone should read by Liam Bennett here. My approach is slightly different, however. I don’t want to spin a Puppet Master and a second system-under-test because that’s two VMs and two VMs take longer to spin up and some may not have a laptop that can cope with so many VMs.

Instead, I use Masterless Puppet to test my roles and profiles.

The spec_helper_acceptance.rb file
Firstly, let me shout out to Trevor Vaughan who gave me some assistance in the Beaker Mailing List with this. Keep an eye on some of the related work he’s doing here).

Our spec_helper_acceptance.rb is as follows (source code):

# Environment variables:
#
#   ENV['PUPPET_INSTALL_VERSION']
#     The version of Puppet to install (if 3.x) or the version of the
#     AIO agent (if 4.x). Defaults to latest Puppet 3.x.
#
#   ENV['PUPPET_INSTALL_TYPE']
#     If set to agent, the Puppet 4 agent is installed, and 
#     PUPPET_INSTALL_VERSION now specified the agent, rather than the
#     Puppet, version.  See
#     [here](https://github.com/puppetlabs/beaker-puppet_install_helper). 
#
#   ENV['BEAKER_destroy']
#     If set to 'no' Beaker will not tear down the Vagrant VM after the
#     tests run.  Use this if you want the VM to keep running for 
#     manual checking.
#   
#   ENV['YUM_UPDATE']
#     If set, a yum update will be run before testing.
 
require 'beaker-rspec/spec_helper'
require 'beaker-rspec/helpers/serverspec'
require 'beaker/puppet_install_helper'
 
def copy_modules_to(host, opts = {})
  Dir["#{opts[:source]}/*"].each do |dir|
    if File.symlink?(dir)
      scp_to host, dir, opts[:module_dir], {:ignore => 'spec/fixtures/modules'}
    else
      scp_to host, dir, opts[:dist_dir]
    end
  end
end
   
def copy_hiera_files_to(host, opts = {})
  scp_to host, opts[:hiera_yaml], opts[:target] + '/hiera.yaml'
  scp_to host, opts[:hieradata], opts[:target]
end
 
def copy_external_facts_to(host, opts = {})
  on host, 'mkdir -p ' + opts[:target]
  scp_to host, opts[:source], opts[:target]
end
 
run_puppet_install_helper
 
RSpec.configure do |c|
  # Project root
  proj_root = File.expand_path File.join(File.dirname(__FILE__), '..')
 
  # Readable test descriptions
  c.formatter = :documentation
 
  # Configure all nodes in nodeset
  c.before :suite do
    host = hosts[0]
 
    if ENV['YUM_UPDATE'] == 'yes'
      on host, 'yum -y update'
    end
 
    system 'bundle exec rake librarian_spec_prep'
    system 'bundle exec rake spec_prep'
 
    copy_modules_to(host, {
      :source     => proj_root + '/spec/fixtures/modules',
      :dist_dir   => '/etc/puppetlabs/code/modules',
      :module_dir => '/etc/puppetlabs/code/environments/production/modules'
    })
 
    copy_hiera_files_to(host, {
      :hieradata  => proj_root + '/spec/fixtures/hieradata',
      :hiera_yaml => proj_root + '/spec/fixtures/hiera.yaml.beaker',
      :target     => '/etc/puppetlabs/code',
    })
 
    copy_external_facts_to(host, {
      :source => proj_root + '/spec/fixtures/facts.d',
      :target => '/etc/facter',
    })
 
    # https://tickets.puppetlabs.com/browse/MODULES-3153
    on host, 'yum -y install iptables-services'
    on host, 'systemctl start iptables.service'
  end
end
So my approach is different from Liam Bennett’s in that I’m using Masterless Puppet and therefore relying on my own helper methods. Arguably, these helper methods should be in Beaker itself, and they probably one day will be. In the mean time, this code shouldn’t be too hard to understand.

As can be seen, I begin my installing the latest Puppet from the Puppet Collections 1 (pc1) repo (see here about https://puppetlabs.com/blog/welcome-puppet-collections). I call the :librarian_spec_prep to checkout the latest Forge modules into spec/fixtures/modules and then the spec_prep to create the symbolic links in the same directory as defined in .fixtures.yml.

Then I copy my modules to the appropriate directories on the VM. The modules available via symbolic links are my own profiles and they are copied to /etc/puppetlabs/code/environments/production/modules and the rest are the shared modules from the Forge that were checked out by Librarian-puppet, so they’re copied to /etc/puppetlabs/code/modules. I copy statically defined Hiera data from spec/fixtures/hieradata to /etc/puppetlabs/code/hieradata and a special spec/fixtures/hiera.yaml.beaker to /etc/puppetlabs/code/hiera.yaml.

Our hiera.yaml.beaker is pretty simple:

---
:backends:
  - yaml
:hierarchy:
  - common
:yaml:
  :datadir: '/etc/puppetlabs/code/hieradata'
And it differs from the hiera.yaml used by Rspec-puppet only by the absolute path to the :datadir.

We set up an external fact for $::espv as discussed above by copying spec/fixtures/facts.d to /etc/facter.

Finally, a note about an open bug against the puppetlabs/firewall MODULES-3153 https://tickets.puppetlabs.com/browse/MODULES-3153 we must manually install the iptables-services package on CentOS 7.

The spec/acceptance/role_es_data_node_spec.rb file
(The source code for this is here.)

Define some code to apply
The first section of a Beaker spec file is usually a heredoc saved in a variable by convention pp:

pp = <<-EOS
stage { 'pre': before => Stage['main'] }
 
Firewall {
  require => Class['profile::base::firewall::pre'],
  before  => Class['profile::base::firewall::post'],
}
 
include role::es_data_node
EOS
The stage declaration and Firewall resource defaults would normally go in site.pp and the include would normally go inside a node definition.

If you like, this snippet of code in pp is a cut-down site.pp as required by our role.

Puppet apply and check for idempotence
The remainder of this file is all in a single describe block:

describe 'role::es_data_node' do
...
end
(If you don’t already know what describe, context, spec files, it blocks are, perhaps start with an Rspec tutorial https://semaphoreci.com/community/tutorials/getting-started-with-rspec and then look at the Serverspec tutorial http://serverspec.org/tutorial.html to relate more specifically to what we’re doing here.)

The puppet apply command is:

context 'puppet apply' do
  it 'is expected to be idempotent and apply without errors' do
 
    apply_manifest pp, :catch_failures => true
 
    # test for idempotence
    expect(apply_manifest(pp, :catch_failures => true).exit_code).to be_zero
  end
end
We call the Beaker helper method apply_manifest http://www.rubydoc.info/github/puppetlabs/beaker/Beaker%2FDSL%2FHelpers%2FPuppetHelpers%3Aapply_manifest_on with :catch_failures => true to apply our role to our newly provisioned Vagrant host.

(Prior to this step running, the VM will be in the state our spec_helper_acceptance leaves it in, along with any other changes made automatically by Beaker.)

The second line expect(apply_manifest(pp, :catch_failures => true).exit_code).to be_zero applies the code a second time, expecting a zero exit code – i.e. the exit code that puppet apply emits when no changes are made. This is our test for idempotence.

Tests for installed packages
Next, we test that a bunch of packages are installed and have known versions:

context 'packages' do
 
  [
   ['java-1.8.0-openjdk',          '1.8.0'],
   ['java-1.8.0-openjdk-headless', '1.8.0'],
   ['elasticsearch',               '2.2.1'],
   ['elastic-curator',             '3.2.3'],
   ['python-elasticsearch',        '1.0.0'],
 
  ].each do |package, version|
 
    describe package(package) do
      it { is_expected.to be_installed.with_version(version) }
    end
 
  end
 
end
Is it a good idea to expect particular versions, considering that any day of the week, a new version of these could be released? Well, I think it is a good idea, because these tests will alert me to the fact that the versions of the software have changed. If the version of, say, Elasticsearch changes, I may well need to make other changes to my code. Other behaviours may change, other tests may fail as a result. It’s useful, to me, to have a test fail if a package version changes.

Tests for configuration files
In the next section I describe Elasticsearch’s configuration files:

context 'config files' do
  describe file('/etc/elasticsearch/es01/elasticsearch.yml') do
    its(:content) { is_expected.to match /MANAGED BY PUPPET/ }
  end
 
  describe file('/etc/elasticsearch/es01/logging.yml') do
    its(:content) { is_expected.to match /managed by Puppet/ }
  end
 
  describe file('/lib/systemd/system/elasticsearch-es01.service') do
    it { is_expected.to be_file }
  end
 
  describe file('/usr/lib/tmpfiles.d/elasticsearch.conf') do
    its(:content) { is_expected.to match /elasticsearch/ }
  end
end
These tests are really useful for Ops teams, as they document here, all in one place, the configuration files used on an Elasticsearch data node. If Elasticsearch fails in the middle of the night, and the Ops staff need to fix it, this information is undoubtedly useful.

Arguably, I could add comments to this file to provide further help to the operations staff. In my view, acceptance and integration tests should remove the need for a Wiki altogether. If an Ops staff makes an unusual discovery that he or she would like to document in the Wiki, why not instead write a new acceptance test instead to demonstrate the suprising discovery?

Of course, I could say more about these config files than I currently do. I would expect the elasticsearch.yml file to contain lines data: true and master: true because this is a master-eligible data node. I could explain that to my future Ops self by expanding on this as:

describe file('/etc/elasticsearch/es01/elasticsearch.yml') do
  its(:content) { is_expected.to match /MANAGED BY PUPPET/ }
  its(:content) { is_expected.to match /data: true/ }
  its(:content) { is_expected.to match /master: true/ }
end
Tests for log files
For the log files I have done just this:

context 'log files' do
  describe file('/var/log/elasticsearch/es01/es01.log') do
    its(:content) { is_expected.to match /starting .../ }
    its(:content) { is_expected.to match /publish_address.*127.0.0.1:9300/ }
    its(:content) { is_expected.to match /es01/ }
    its(:content) { is_expected.to match /new_master.*reason:.*elected_as_master/ }
    its(:content) { is_expected.to match /publish_address.*127.0.0.1:9200/ }
    its(:content) { is_expected.to match /started/ }
  end
 
  describe file('/var/log/elasticsearch/es01/es01_index_search_slowlog.log') do
    its(:size) { is_expected.to be_file }
  end
 
  describe file('/var/log/elasticsearch/es01/es01_index_indexing_slowlog.log') do
    its(:size) { is_expected.to be_file }
  end
 
  describe file('/var/log/elasticsearch/es01/gc.log.0.current') do
    its(:content) { is_expected.to match /OpenJDK 64-Bit Server VM/ }
  end
end
For the main log file I document exactly the lines in the log file that I care about, that indicate a successful cluster start. I also document all the other log files that should exist, that may be useful for troubleshooting.

Tests for commands
I skip ahead a bit here as most of the file is self-explanatory. But the commands section also deserves comment:

context 'commands' do
  describe command('curl localhost:9200') do
    its(:stdout) { is_expected.to match /cluster_name.*es01/ }
  end
 
  describe command('curl localhost:9200/_cluster/health?pretty') do
    its(:stdout) { is_expected.to match /green/ }
  end
end
I am sure I don’t need to explain what that’s saying — the beauty of Rspec is how human readable it is — – but I will note in passing how powerful, again for documentation purposes, the ability to describe command outputs in Rspec is. Again, any Elasticsearch API commands the Ops teams care about can be documented as tests.

Running the Beaker tests
To run the tests:

$ bundle exec rspec spec/acceptance/role_es_data_node_spec.rb
...
Finished in 3 minutes 10.3 seconds (files took 1 minute 36.31 seconds to load)
29 examples, 0 failures
Conclusion
In summary we have looked at how to build a simple Elasticsearch 2.2 cluster using the Elastic.co Puppet module, and the latest Puppet 4. Our cluster uses simple unicast discovery, and builds a cluster of 3 or more master-enabled Elasticsearch data nodes. We build a separate filesystem for the ES work dir and we set up a firewall to allow inbound port 9200. And we provide configuration data for a single node configuration as well. We have described the Librarian-puppet set up, the Puppet roles and profiles, and the Rspec-puppet and Beaker acceptance tests.

In the next part, we will look at how to build and test the Kibana node.
