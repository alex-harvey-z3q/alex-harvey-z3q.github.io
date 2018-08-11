Building a highly available ELK solution with Puppet, Part I: Introduction
by Alex Harvey | Feb 18, 2016 | blogs | 2 comments

NOTE: this series is a work-in-progress that will be finished in due course.  I leave it up here because the code and approach is likely to be nonetheless useful to people engaged in building a similar ELK / Puppet solution.

In this series of blog posts I show how to build a simple, highly available ELK (Elasticsearch, Logstash, Kibana) stack using Puppet.  In doing so, I am inspired by the efforts of Larry Smith Jr., who wrote a great series of blog posts (here, here, here, and here) showing how you can do the same using Ansible.

In this series, I describe a suite of Puppet Roles and Profiles for building a number of example configurations of ELK, from a single node configuration through to highly available, horizontally scalable configurations, as well the CI/CD pipeline, including basic unit tests in Rspec-puppet and more complex acceptance and integration tests in Beaker/Serverspec.

Our ELK stack consists of the Elastic.co components, the Filebeat log shipper; the Logstash broker (also sometimes called the “shipper” for historical reasons); the Logstash Indexer; the Elasticsearch cluster; and the Kibana front end. In addition we have an HA proxy, a Redis cache, and an Nginx reverse proxy.

The code is available in Github.  Feel free to send feedback and pull requests, although I expect users will fork this code and customise it. The code is licensed under the MIT license.

Architectures
1. “All on one node” configuration for development and testing
The “all in one” configuration has everything running on a single VM and is most useful for developers writing logstash filters, or creating Kibana dashboards, learning how to use Logstash, and is used by the Beaker tests for integration testing.

The role includes an HA proxy, a lightweight Filebeat log shipper, a Logstash Broker instance, a Redis cache, a Logstash Indexer instance, an Elasticsearch data node, and Elasticsearch client node, the Kibana 4 frontend, and an Nginx reverse proxy to make Kibana available on port 80.

A single role is provided for this configuration, role::elk_node_test.

This architecture is shown in the following simple figure:

ELK all in one

2. “All on one node” production variant
The “all on one node” configuration above would run fine in production too, but the HA proxy would introduce another point of possible failure, without providing any functionality, so for users who do want to run ELK on a single node in production, we provide a variation of the above configuration with the HA proxy removed. We call this one role::elk_node.

3. Clustered Elasticsearch configuration
The heart of your ELK stack is of course the Elasticsearch database, and that’s the first candidate for scaling.

It is recommended that an Elasticsearch cluster consists of at minimum 3 nodes, to avoid a possible split-brain condition. As such, this configuration requires a minimum of 5 nodes: 3 for the ES cluster; 1 for the Kibana viewer, and 1 for the Logstash node.

The associated roles are the role::es_data_node, role::kibana_node and role::logstash_node.

ELK with clustered ES

4. Cluster Elasticsearch, clustered indexer configuration
If a system is itself under huge load, but has a Logstash Indexer doing a lot of processing, it’s possible that clustering at both the ES database and Indexer level will be desired.

The associated roles are role::es_data_node, role::kibana_node, role::ls_indexer_node and role::ls_shipper_node.

ELK stack, clustered indexer, clustered ES

5. Clustered Logstash, clustered Elasticsearch
If the whole system is under load, and the indexers are not doing a huge amount of work, then a clustered logstash with the brokers and indexers on the same nodes might be a good choice.

The roles for this one are role::es_data_node, role::kibana_node, role::logstash_node and role::haproxy_node.

Clustered logstash, clustered ES

Clustered broker, clustered indexer, clustered Elasticsearch
The above configuration still potentially fails when the Logstash Indexer process fails. In addition, we may want to tune the OS differently for the Indexer and the Shipper.  To build resiliency there, and facilitate different OS tunings for the different Logstash roles, we can moved to a clustered broker, clustered indexer, clustered Elasticsearch configuration.

The roles are role::es_data_node, role::kibana_node, role::ls_shipper_node, role::ls_indexer_node and role::haproxy_node.

Clustered logstash, clustered ES

We could of course go on.  The Redis cache still presents a possible point of failure, as does the ES client node.  Some may simply have a policy of 1 VM for 1 component.  I think, however, the six configurations above are going to address the needs of most users.  And if not, I expect that it won’t be hard to adapt this code to your specific needs.

Profiles
The beauty of the Roles and Profiles pattern is that the above six configurations (and more yet configurations are possible) all reuse the following Profiles:

profile::kibana: includes the Kibana web application.
profile::nginx: includes the Nginx reverse proxy for proxying port 80 to the Kibana app on port 5601.
profile::elasticsearch::client_node: includes the client instance for connecting a Kibana instance to an elasticsearch cluster.
profile::elasticsearch::data_node: configures an Elasticsearch data node instance.
profile::logstash::indexer: includes a logstash indexer instance
profile::logstash::shipper: includes a logstash shipper (broker) instance and a redis instance
profile::haproxy: includes the HA proxy
profile::filebeat: includes the Filebeat log tailer
profile::base: includes some basic linux configuration, including NTP, and the firewall base configuration.
Puppet Forge modules
The profiles in turn use the following Puppet Forge modules:

puppetlabs/stdlib
puppetlabs/ntp
alexharvey/disable_transparent_hugepage
alexharvey/firewall_multi
puppetlabs/firewall
puppetlabs/lvm
puppetlabs/haproxy
arioch/redis
elasticsearch/logstash
elasticsearch/elasticsearch
pcfens/filebeat
lesaux/kibana4
jfryman/nginx
In the following posts we’ll describe the profiles, the Hiera data that you’ll need to feed into them for the various configurations, and then the unit-testing and Beaker work.

2 Comments
Dean Smith
Dean Smith	on March 9, 2016 at 11:36 pm
The github link is to an empty repo, is it correct ?

Reply
Alex Harvey
Alex Harvey	on March 13, 2016 at 11:47 pm
It’s updated now, to the point where we can build a working Elasticsearch cluster with a Kibana 4 frontend. Second part of this series should be up in a few days.
