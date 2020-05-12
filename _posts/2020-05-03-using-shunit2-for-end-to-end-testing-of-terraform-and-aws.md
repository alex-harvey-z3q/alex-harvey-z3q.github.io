---
layout: post
title: "Using shUnit2 for end-to-end testing of Terraform and AWS"
date: 2020-05-03
author: Alex Harvey
tags: shunit2 terraform aws
---

This article documents a pattern of end-to-end testing Terraform on AWS using the shUnit2 framework.

- ToC
{:toc}

## Introduction

In this post, I yet again document another use-case for the [shUnit2](https://github.com/kward/shunit2) Bash unit testing framework. This time, however, I am not using the framework for unit testing, but for end-to-end testing. I am going to show how to set this all up, given an example of simple end-to-end tests using a Terraform module that deploys a simple AWS EC2 instance, and then in the discussion section talk about what I love about this pattern, and I'll compare it to alternatives. My hope is that by the end of this, readers will also want to use this method!

## Code example

I have the simplest Terraform example I can think of, some code that just launches an AWS EC2 instance:

```js
provider "aws" {
  region = "ap-southeast-2"
}

variable "key_name" {
  type        = string
  description = "The name of the EC2 key pair to use"
  default     = "default"
}

variable "key_file" {
  type        = string
  description = "The private key for the ec2-user"
  default     = "~/.ssh/default.pem"
}

variable "instance_type" {
  type        = string
  description = "The EC2 instance type"
  default     = "t2.micro"
}

data "aws_ami" "ami" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name

  tags = {
    Name = "HelloWorld"
  }
}

output "id" {
  description = "The instance ID"
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "The instance ID"
  value       = aws_instance.web.public_ip
}

output "key_name" {
  description = "The instance ID"
  value       = aws_instance.web.key_name
}
```

## Code on GitHub

To download this code and play with it, it is on GitHub [here]().

## End to end tests

### What are end-to-end tests

End-to-end (E2E) testing is when we spin up an entire stack, an application, or a cluster of applications, and test that the whole thing really works from end to end. E2E tests are typically slower, and it is harder at this E2E level to prove that all code paths in the stack are truly tested. But on the other hand, only E2E tests can prove that the code solution as a whole really works.

### Designing the tests

When writing E2E tests, I normally want to test a representative set of configurations that I would actually use in development and production environments and ensure that this code builds them "correctly". Knowing what is "correct" of course is the challenge, although in the case of the arbitrarily simple example in this post, I will say that an EC2 instance that I can log into is what I'll consider "correct". So my tests will need to do these things:

- Test set up: Spin up the AWS resources.
- Test #1: Test that its state is "running".
- Test #2: Test that its key exists.
- Test #3: Test that I can login using the key.
- Test tear down: Destroy the stack again at the end.

Note that I don't consider these tests to be perfectly designed. This post is not about designing E2E tests, but is intended simply to document the shUnit2 pattern I use!

## Bash magic

I predict that one objection to using Bash for E2E testing could be that Bash lacks support for manipulating structured YAML and JSON data in the way people are familiar with in languages like Python and Ruby. That is to say, I can't just initialise a Hash or Dict in Bash with data returned from the AWS API. So how do we do it?

### JMESpath, jq and yq

It turns out that with just a little bit of knowledge of [JMESpath](https://jmespath.org), [jq](https://stedolan.github.io/jq/) and jq's YAML front-end [yq](https://github.com/mikefarah/yq), the data structures problem is really no problem at all.

In this section, I am going to provide a couple of examples of reading multiple values from the AWS CLI using JMESpath and jq. (yq of course is the same language as jq so an example would be redundant.)

### Example 1 - read muliple fields from a JMESpath query

Suppose I want to read the key name and key fingerprint for a key named default. Suppose also that this is the only call I want to make to the [describe-key-pairs](https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_DescribeKeyPairs.html) API endpoint.

The following snippet of Bash code can read these in one call:

```bash
read -r key_name key_fingerprint <<< "$(
  aws ec2 describe-key-pairs --output text --query \
    'KeyPairs[?KeyName==`default`].[KeyName,KeyFingerprint]'
)"
```

Let's break that down. First the query:

```text
▶ aws ec2 describe-key-pairs --query 'KeyPairs[?KeyName==`default`].[KeyName,KeyFingerprint]' --output text
default 70:e2:fa:b1:97:e3:68:5f:6a:63:93:17:09:5a:43:29:60:94:53:ab
```

That's the first trick. Writing a query that returns all the data I want, space-separated, on a single line.

Next the [here string](https://www.tldp.org/LDP/abs/html/x17837.html) namely the `<<<` operator in Bash. That's really just a fancy way of writing `echo something | something else`. I could rewrite the above command as:

```bash
aws ec2 describe-key-pairs --output text --query \
  'KeyPairs[?KeyName==`default`].[KeyName,KeyFingerprint]' | \
  read -r key_name key_fingerprint
```

If you prefer that, go ahead. I like to use the here string because I find it clearer to have the variables I am setting on the left-hand side.

Finally, the read command. The read command in Bash allows us to read in columns of input into separate variables in one line. For more information see [here](http://mywiki.wooledge.org/BashFAQ/001).

The hard part of course is knowing how to write the JMESpath query. That is beyond the scope of this article, although learning JMESpath as well as jq is something every DevOps engineer really needs to do anyway.

So, putting it all together:

```text
▶ read -r key_name key_fingerprint <<< "$(
    aws ec2 describe-key-pairs --output text --query \
      'KeyPairs[?KeyName==`default`].[KeyName,KeyFingerprint]'
  )"
▶ echo "$key_name"
default
▶ echo "$key_fingerprint"
70:e2:fa:b1:97:e3:68:5f:6a:63:93:17:09:5a:43:29:60:94:53:ab
```

Which is just what I wanted.

### Example 2 - read multiple fields from a JSON file in jq

Sometimes it is not sensible to try to read all values you need from a single JMESpath query, and to avoid making multiple slow calls to the AWS API, a JSON response file is better saved. Suppose I want info about the EC2 instance I created:

```text
▶ aws ec2 describe-instances --filters \
    "Name=tag:Name,Values=HelloWorld" > describe-instances.json
```

I now have all data about my EC2 instance saved in describe-instances.json. So suppose I want the fields VpcId, ImageId, NetworkInterfaces.MacAddress, and BlockDeviceMappings.DeviceName. I can get all that in one jq one-liner like this:

```text
▶ jq -r '.Reservations[].Instances[] |
    [.VpcId,.ImageId,.NetworkInterfaces[].MacAddress,.BlockDeviceMappings[].DeviceName] |
    join(" ")' describe-instances.json
vpc-07a59518ae4faa320 ami-0051f0f3f07a8934a 02:6f:ee:9b:fe:54 /dev/sda1
```

So these can all be read into Bash variables like this:

```bash
read -r vpc_id image_id mac_address device_name <<< "$(
  jq -r '.Reservations[].Instances[]
    | [
    .VpcId,
    .ImageId,
    .NetworkInterfaces[].MacAddress,
    .BlockDeviceMappings[].DeviceName
      ]
    | join(" ")' describe-instances.json
)"
```

## shUnit2 oneTimeSetUp and oneTimeTearDown

One of the things I love about shUnit2 for E2E testing is the simplicity of setup and teardown. All of the Python and Ruby frameworks I am familiar with, including Rspec (InSpec, ServerSpec), have somewhat confusing multi-pass DSLs making it sometimes non-obvious as to the ordering of things. Not so in shUnit2. This framework provides two functions that are perfect for a slow, E2E test setup and teardown:

- oneTimeSetUp

A function that gets run one, before the suite. This is the perfect place for running your terraform apply (or aws cloudformation create-stack etc).

- oneTimeTearDown

A function that gets run once, after the suite. This is where you would run your terraform destroy (or aws cloudformation delete-stack etc).

## Writing the tests

### Test setup and teardown

Thus I begin with this set up and tear down. I save this in a file `shunit2/test_web.sh`:

```bash
#!/usr/bin/env bash

# Usage: [PROVISION=false] [DESTROY=false] bash $0

oneTimeSetUp() {
  [ "$PROVISION" == "false" ] && return
  if ! terraform apply -auto-approve ; then
    fail "terraform did not apply"
    startSkipping
  fi

  aws ec2 describe-instances --filters \
    "Name=tag:Name,Values=HelloWorld" > describe-instances.json
}

oneTimeTearDown() {
  [ "$DESTROY" != "false" ] && \
    terraform destroy -auto-approve ; true
}

. shunit2
```

Notice some things here:

- I have implemented environment variables `$PROVISION` and `$DESTROY` (I took their names from Puppet's Beaker). This allows the following usage:

```text
Usage: [PROVISION=false] [DESTROY=false] bash $0
```

- The call to the shUnit2 `startSkipping` and `fail` functions to allow the suite to be skipped if Terraform fails to apply. That's just clean.

- Another slow step, the call to aws ec2 describe-instances is also called once, in the oneTimeSetUp. My expectation is that any slow step that only needs to be run once would run here.

### Test instance state and code

The first test I'll write I assert that the instance state is `running` with code `16`. To do that:

```bash
testInstanceStateAndCode() {
  local code name

  read -r code name <<< "$(jq -r \
    '.Reservations[].Instances[]
      | select(.State.Name=="running")
      | .State
      | [(.Code | tostring), .Name]
      | join(" ")' \
        describe-instances.json
  )"

  assertEquals "instance state code incorrect" "16" "$code"
  assertEquals "instance state name incorrect" "running" "$name"
}
```

### Test that the key exists

```bash
testDefaultKeyExists() {
  local key_fingerprint=$(aws ec2 describe-key-pairs \
    --query 'KeyPairs[?KeyName==`default`].KeyFingerprint' --output text)

  assertTrue "key fingerprint not found for default" \
    "grep -qE '^([a-f0-9][a-f0-9]:){19}[a-f0-9][a-f0-9]$' <<< $key_fingerprint"
}
```

### Test that login works

```bash
testLogin() {
  local public_ip=$(jq -r \
    '.Reservations[].Instances[] | select(.State.Name=="running") |
      .PublicIpAddress' describe-instances.json)

  ssh -i ~/.ssh/default.pem -o UserKnownHostsFile=/dev/null -o \
    StrictHostKeyChecking=no ec2-user@"$public_ip" date 2> /dev/null

  assertTrue "could not login" "$?"
}
```

## Makefile

To run the tests I have a very simple Makefile:

```make
.PHONY: test
test:
	@bash shunit2/test_backend.sh
```

## Running the tests

```text
▶ DESTROY=false make test                                   
data.aws_ami.ami: Refreshing state...                                                                                                                                                   
aws_instance.backend: Creating...                                     
aws_instance.backend: Still creating... [10s elapsed]                                           
aws_instance.backend: Still creating... [20s elapsed]                                                                                                                                   
aws_instance.backend: Provisioning with 'remote-exec'...                                                
aws_instance.backend (remote-exec): Connecting to remote host via SSH...
aws_instance.backend (remote-exec):   Host: 13.210.249.192               
aws_instance.backend (remote-exec):   User: ec2-user                                                                                                                                    
aws_instance.backend (remote-exec):   Password: false   
aws_instance.backend (remote-exec):   Private key: true                                                                                                                                 
aws_instance.backend (remote-exec):   Certificate: false                 
aws_instance.backend (remote-exec):   SSH Agent: true                                           
aws_instance.backend (remote-exec):   Checking Host Key: false                                                                                                             
...
aws_instance.backend: Creation complete after 1m46s [id=i-0e71f9e2871d5fbf9]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

id = i-0e71f9e2871d5fbf9
key_name = default
public_ip = 13.210.249.192
testLogin
Tue May 12 16:14:47 UTC 2020

Ran 1 test.

OK
```

## Discussion

So that covers most of my shUnit2 E2E testing pattern.

I find this is a really simple and powerful pattern for doing E2E (acceptance, integration etc testing). Bash is not everyone's favourite language and admittedly I do require a little bit more Bash of my reader than I can reasonably expect every DevOps engineer to know. But it has a number of advantages:

1. It's Bash. Because it's Bash, I can rely on Bash being there in every test environment.
1. Bash is actually powerful. For automated testing, Bash is actually very powerful. Bash scripts can call AWK, jq, sed and other purpose-built languages for data analysis and text manipulation and this is just what you want in a testing language.
1. shUnit2 is an extremely simple automated test framework that relies on a single, monolithic, 1000-or-so line script.
1. Ordering is simple. Compared to other frameworks (e.g. Rspec, InSpec, PyTest, Python Unittest, etc), the ordering and setup, teardown is actually really simple. Everything happens in the order you write it, because it's Bash!
1. shUnit2 has excellent features for E2E testing. I mentioned already the `oneTimeSetUp`, `oneTimeTearDown` functions, as well as all the jUnit-inspired `assertEquals`, `assertNotEquals` etc.
1. AWS CLI is a simpler interface to the AWS API than Python's Boto and Ruby's AWS SDK. (These being the others than I am familiar with.)
1. Fewer lines of setup and teardown code relative at least to Python, Golang etc. It's actually easier!

So I hope I have inspired a few people to give this method a try. If you have any comments or questions feel free to email!

## See also

My earlier posts on shUnit2:

- Jul 7, 2017, [Unit Testing a Bash Script with shUnit2](https://alexharv074.github.io/2017/07/07/unit-testing-a-bash-script-with-shunit2.html).
- Sep 7, 2018, [Testing AWS CLI scripts in shUnit2](https://alexharv074.github.io/2018/09/07/testing-aws-cli-scripts-in-shunit2.html).
- Jan 31, 2020, [Unit testing a Terraform user_data script with shUnit2](https://alexharv074.github.io/2020/01/31/unit-testing-a-terraform-user_data-script-with-shunit2.html).
- Apr 9, 2020, [Unit testing a CloudFormation UserData script with shunit2](alexharv074.github.io/2020/04/09/unit-testing-a-cloudformation-userdata-script-with-shunit2.html).

And see also my Placebo library on GitHub, [Placebo for Bash](https://github.com/alexharv074/bash_placebo).
