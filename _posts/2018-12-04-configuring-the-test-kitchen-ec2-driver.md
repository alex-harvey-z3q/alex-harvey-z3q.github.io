---
layout: post
title: "Configuring the Test Kitchen EC2 driver"
date: 2018-12-04
author: Alex Harvey
tags: test-kitchen
---

This is an update of sorts to my earlier blog post [Integration testing using Ansible and Test Kitchen](https://alexharv074.github.io/2016/06/13/integration-testing-using-ansible-and-test-kitchen.html) after I spent the day figuring out how to configure the [kitchen-ec2](https://github.com/test-kitchen/kitchen-ec2) driver.

## Use of .kitchen.local.yml

Since some of the data for configuring the EC2 plugin is likely to be somewhat sensitive, I have used the .kitchen.local.yml override mechanism and redacted data in this post.

## Gemfile

To install kitchen-ec2 I had to add the following line to Gemfile:

```ruby
gem 'kitchen-ec2'
```

I also deleted the kitchen-vagrant line for the driver it replaces.

## Authentication

In the demo, I used an EC2 instance that already had the right IAM credentials to manage other EC2 instances. As such, there was no need to configure anything here.

## Changes to the platform config

In the platform -> driver section, I specified an AMI ID:

```yaml
platforms:
  - name: centos-7.2
    driver:
      image_id: ami-123456780abcdef12
```

## Changes to the driver config

In order to tell AWS of the VPC to in which to launch the EC2 instance, I provided a subnet ID and a region in .kitchen.local.yml.

I also specified the Instance Type here, and the SSH Key Pair to use. Note that I had to specify both the Key Pair name on the AWS side, and the path to the actual key file, and the user to login as. Finally, I also found I could specify instance tags here. I ended up with this:

```yaml
# .kitchen.yml
driver:
  name: ec2
  instance_type: t2.medium

transport:
  ssh_key: /home/alexharvey/.ssh/id_rsa
  username: ec2-user
```

```yaml
# .kitchen.local.yml
driver:
  region: ap-southeast-2
  subnet_id: subnet-1234567890abcdef0
  iam_profile_name: instance-profile
  instance_type: t2.medium
  aws_ssh_key_id: key-pair-name
  tags:
    foo: bar
    baz: qux
```

## Troubleshooting

I lost some time on some confusing Test Kitchen error messages. This sections documents those learnings.

### The image id does not exist

At one point I encountered a confusing error message:

```text
Failed to complete #create action: [The image id '[ami-123456780abcdef12]' does not exist] on master-centos-72
```

I found [this](https://github.com/test-kitchen/kitchen-ec2/issues/230) thread that appeared relevant, that explained that the error message can be misleading.

Next I tried connecting directly from the Ruby SDK:

```ruby
require 'aws-sdk'
client = Aws::EC2::Client.new(region: 'ap-southeast-2', credentials: Aws::InstanceProfileCredentials.new)
client.describe_images({image_ids: ['ami-123456780abcdef12']})
```

That proved that the SDK itself could connect and list images.
Eventually I found I could just unconfigure the authorisation credentials completely and it just worked.

### EC2 instance terminated outside of Test Kitchen

Also confusing: If you terminate the EC2 instance outside of the `kitchen destroy` workflow, [this](https://github.com/test-kitchen/test-kitchen/issues/796) issue will be encountered. To fix up from that, it was necessary to just delete the YAML file in `.kitchen`. After that, `kitchen list` showed the `not created` state again.

## Running the tests

After this setup, it was then possible to run the tests normally using:

```text
bundle exec kitchen test master-centos-72
```
