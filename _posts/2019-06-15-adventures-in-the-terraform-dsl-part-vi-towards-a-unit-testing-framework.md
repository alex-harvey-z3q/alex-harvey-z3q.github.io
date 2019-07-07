---
layout: post
title: "Adventures in the Terraform DSL, Part VI: Towards a unit testing framework"
date: 2019-06-15
author: Alex Harvey
tags: terraform
---

This post introduces a first of its kind unit testing framework for the Terraform DSL called "terraform testing eval", based on an unmerged feature branch based on Terraform 0.12.2 written by Martin Atkins.

- ToC
{:toc}

## Introduction

This post, which I have included as part VI of my ongoing blog series on the Terraform DSL, introduces for the first time (as far as I know anyway) a unit testing framework called, for now anyway, "terraform testing eval" that was written by Martin Atkins at HashiCorp as a prototype test framework for [Issue #21628](https://github.com/hashicorp/terraform/issues/21628) that I raised. In the post I show how to set it all up and write real unit tests using Rspec or Python's unittest framework. I hope to generate some interest and demand for the concept in the hope that people will upvote the issue and cause HashiCorp to prioritise merging this important feature!

## Why unit test

The fact that the Terraform DSL has made it through 12 beta releases and 5 years of use in production without a unit testing framework shows, I think, a lack of demand in the DevOps community for real unit testing frameworks for their infrastructure code. Indeed, competing products also have never provided real unit test frameworks either - e.g. Ansible, Salt, AWS CloudFormation. Puppet has had a unit testing framework - [Rspec-puppet](https://github.com/rodjek/rspec-puppet) - since 2011, although, even there, it is used only by a niche of engineers.<sup>1</sup>

It appears, therefore, that many DevOps engineers either do not see the point of unit testing - or, for whatever reason, choose to not do it.

I also often hear it said that slow integration tests that spin up real infrastructure are preferrable to fast unit tests because unit tests can never prove that your application actually "works".

Well, I see unit testing of Terraform and other infrastructure code as essential in at least all of the following scenarios:

|Use case|Terraform example|
|--------|-----------------|
|Safely refactor code|Given Terraform 0.7 code prove that nested replace functions are correctly replaced by Terraform 0.12 conditional expressions|
||Prove that Terraform templates expand into expected text for a set of inputs|
||Prove that for and for_each expressions code generate expected Terraform resources|
|As a learning aid|Experiment with unfamiliar syntax without the cost of creating real Cloud resources|
||Given an unfamiliar code base unit tests can be used to study its behaviour|
|Rapidly change code|With complete unit test coverage it is possible to write more code quickly without each change slowed down by infrastructure build costs|
|Additional code as documentation|Unit tests show how code behaves in response to inputs in a way that the code itself often does not|

These are some and not all of the benefits that unit testing brings to infrastructure and any code. And while not everyone will agree, I personally consider a unit testing framework a must-have feature for any code that will run in production.

## Similarities and differences with Puppet

The designs of Puppet and Terraform have many obvious similarities: both are declarative DSLs for infrastructure code; both provide resource abstraction layers with a type and provider model; both build directed acyclic graphs to order the configuration of resources; both take a human-readable source code and "compile" it into a "catalog" (Puppet) or "plan" (Terraform).

But there are some key differences, and these differences no doubt made it easier to provide a unit testing framework in Puppet than in Terraform:

1. Terraform's state file caches known state information and provides input into the Terraform plan, whereas Puppet's only knowledge of state at the time of catalog compilation are the facts sent by the Puppet agent. Mocking these facts is a smaller problem than mocking state in Terraform.
1. Terraform's providers actually send inputs to the plan as well. Puppet's providers meanwhile only operate after the catalog is already compiled.

For more information be sure to carefully read all of Martin's comments in the [GitHub issue](https://github.com/hashicorp/terraform/issues/21628). The problems are not insurmountable.

## The proof of concept

It is now time to look at the proof of concept I have written for the "terraform testing eval" framework. The feature came about, as mentioned, after I raised a GitHub issue requesting a Terraform unit testing framework. And, to my surprise, Martin Atkins had [implemented](https://github.com/hashicorp/terraform/commit/760ec68a5c587340abb87e95b42b4cc56e0f7ab4) one within a few hours. He named the prototype "terraform testing eval". He also demonstrated its use in Python [here](https://github.com/hashicorp/terraform/issues/21628#issuecomment-499939509).

Also, note that Martin's example unit tests in Python are on the [unit-testing-prototype](https://github.com/terraformnet/terraform-aws-vpc-region/tree/unit-testing-prototype) branch of the [terraform-aws-vpc-region](https://github.com/terraformnet/terraform-aws-vpc-region) module.

## Building a modified terraform

Building a custom Terraform 0.12 from the [testing eval](https://github.com/hashicorp/terraform/tree/f-testing-eval-prototype) branch is easy (these instructions are for Mac OS X):

Install the dependencies:

```text
▶ brew install golang
```

Clone and checkout the branch:

```text
▶ git clone git@github.com:hashicorp/terraform.git
▶ cd terraform/
▶ git checkout f-testing-eval-prototype
```

And make a dev Terraform binary:

```text
▶ make dev
==> Checking that code complies with gofmt requirements...
GO111MODULE=off go get -u golang.org/x/tools/cmd/stringer
GO111MODULE=off go get -u golang.org/x/tools/cmd/cover
GO111MODULE=off go get -u github.com/golang/mock/mockgen
GOFLAGS=-mod=vendor go generate ./...
2019/06/15 17:15:42 Generated command/internal_plugin_list.go
# go fmt doesn't support -mod=vendor but it still wants to populate the
# module cache with everything in go.mod even though formatting requires
# no dependencies, and so we're disabling modules mode for this right
# now until the "go fmt" behavior is rationalized to either support the
# -mod= argument or _not_ try to install things.
GO111MODULE=off go fmt command/internal_plugin_list.go > /dev/null
go install -mod=vendor .
▶ ~/go/bin/terraform -v
Terraform v0.12.3-dev
```

## Terraform testing eval

Then to use the testing eval command:

```text
▶ export PATH=~/go/bin:$PATH
▶ terraform testing eval
Usage: terraform testing eval MODULE-DIR REF-ADDR DATA-FILE

  A plumbing command that evaluates a single object identified by
  REF-ADDR from the module in MODULE-DIR using values from
  DATA-FILE as a mock dataset for expression evaluation.

  The result is printed in JSON format on stdout. If the data
  on stdout is not valid JSON, stderr may contain a human-
  readable description of a general initialization error.
```

## Testing the unit testing framework

### Example code

My proof of concept code is online [here](https://github.com/alexharv074/terraform-unit-testing-poc) and the final version of all the code discussed in this post can be seen from there. The reader may also clone that and try it themself.

So as to have an example of something to actually test I have written a simple Terraform module that spins up an AWS EC2 instance:

```js
// main.tf
locals {
  key_name = "default"
}

resource "aws_instance" "this" {

  count = var.instance_count

  ami           = var.ami
  instance_type = var.instance_type
  key_name      = local.key_name

  dynamic "ebs_block_device" {

    for_each = var.ebs_block_device
    iterator = e

    content {
      device_name = e.value.device_name

      encrypted   = lookup(e.value, "encrypted",   null)
      iops        = lookup(e.value, "iops",        null)
      snapshot_id = lookup(e.value, "snapshot_id", null)
      volume_size = lookup(e.value, "volume_size", null)
      volume_type = lookup(e.value, "volume_type", null)

      delete_on_termination = lookup(
                 e.value, "delete_on_termination", null)
    }
  }

  user_data = templatefile("${path.module}/user-data.sh.tmpl", {
    merged = [
      for index, x in var.ebs_block_device:
      merge(x, {"mount_point" = var.mount_point[index]})
    ]
  })
}
```

And the template file `user-data.sh.tmpl` looks like this:

```text
#!/usr/bin/env bash
%{for e in merged ~}
mkfs -t xfs ${e.device_name}
mkdir -p ${e.mount_point}
mount ${e.device_name} ${e.mount_point}
%{endfor ~}
```

### Notes on the evaluation logic

As can be seen, my example module uses the following logic features of the Terraform DSL:

- A dynamic nested block to code generate the EBS volumes via Terraform 0.12's `for_each`.
- A `count` of resources that can be used to conditionally disable the resource.
- A complicated `for` expression to merge two data sources together.
- A for loop in the `templatefile()`'s template language to generate the `user_data`.

### Some test cases

So before I show any actual test code I'd like to think through what I'd like to actually test.

- The module accepts an input `var.instance_count`.
    * I would expect nothing to be created if this is variable is set to 0.
    * And I would expect one EC2 instance to be created if this is set to 1.
- The module also accepts an optional map of EBS block devices.
    * If I pass in `var.instance_count` of 1 and a `var.ebs_block_device` of an empty map, I expect:
        1. One EC2 instance with no EBS block devices.
        1. A UserData shell script that will contain just the shebang line! And that should work fine. Not a bug!
    * If I pass in `var.instance_count` of 1 and a `var.ebs_block_device` that is not empty but say has 2 EBS volumes in it, it gets more interesting:
        1. If there is no `block_device` I expect an error.
        1. If there is no `mount_point` I also expect an error.
    * If I pass a minimal, complete EBS block device list (with a `block_device` and `mount_point` but nothing else):
        1. I expect other attributes not supported by the module but supported by the provider - like `iops` - to be `null`.
        1. I expect other attributes supported by the module but not configured here - like `volume_size` - to also be `null`.
    * If I pass in a typo to the EBS block device list:
        1. I expect an error to be raised.
    * If I set all the supported options to the EBS block device list:
        1. I expect them all to actually do something. I should check the value of at least one.
        1. I expect the list of EBS block devices to be of length 2.
        1. I also expect a certain `user_data` script:
              - It should have a valid mkfs line.
              - It should have a valid mkdir line.
              - It should have a valid mount line.

The process above is, by the way, known as _white box testing_, the process of writing down and systematically testing all logical pathways through code. I suspect that many DevOps engineers have never thought through such a process as the above whereas in practice it almost always leads to the discovery of bugs - at least in the edge cases. On this occasion, for instance, although not a "bug" I nevertheless had not realised that the `mount_point` if not supplied would cause Terraform to error out.

So, even in the absence of a test framework, the process of white box testing still adds value. But of course, we want the tests to be automated, not on paper.

### Using terraform testing eval

The modified Terraform has a new command, `terraform testing eval` as mentioned above. As the name suggests, its purpose is for testing Terraform's evaluation logic. It has (again) the following usage:

```text
▶ terraform testing eval
Usage: terraform testing eval MODULE-DIR REF-ADDR DATA-FILE

  A plumbing command that evaluates a single object identified by
  REF-ADDR from the module in MODULE-DIR using values from
  DATA-FILE as a mock dataset for expression evaluation.

  The result is printed in JSON format on stdout. If the data
  on stdout is not valid JSON, stderr may contain a human-
  readable description of a general initialization error.
```

So we can pass in a `REF-ADDR` - a single Terraform resource like `aws_instance.this` - and a `DATA-FILE` - a JSON file specifying the variables we want to pass in, and also - and this is a bit of a gotcha - the values of any locals.

In my case, I have created some example JSON files in my proof-of-concept [here](https://github.com/alexharv074/terraform-unit-testing-poc/blob/master/spec/fixtures/simplest_instance_count_1.json). For example:

```json
{
  "variables": {
    "instance_count": 1,
    "ami": "ami-08589eca6dcc9b39c",
    "instance_type": "t2.micro",
    "ebs_block_device": [],
    "mount_point": []
  },
  "locals": {
    "key_name": "default"
  }
}
```

These are the data inputs for my tests. Now I can run `terraform testing eval` using these as follows:

```text
▶ terraform testing eval . aws_instance.this spec/fixtures/simplest_instance_count_1.json
```

This then outputs, in Martin's words:

> ...a JSON representation of the configuration object that resulted from evaluating the body of the given resource block against the given mock data.

### Rspec helpers

To be sure, the JSON representation is a little confusing, which is why Martin also wrote some [Python code](https://github.com/terraformnet/terraform-aws-vpc-region/blob/unit-testing-prototype/unittests/test_subnets.py#L85-L135) to make sense of it.

I chose to rewrite these Python helpers in Ruby so that I could use Rspec instead. My thinking is that Rspec is already known to many DevOps engineers, and is the basis of Serverspec, Test Kitchen, Rspec-puppet, Chefspec, InSpec and not to mention an old project [rspec-terraform](https://github.com/bsnape/rspec-terraform). And I also believe that Ruby's flexibility - a language that has evolved from sed, AWK & Perl - makes it a good language for automated testing. But, of course, the choice of framework here isn't a key consideration. I like Rspec. Others may feel free to use something else.

The source code for these are [here](https://github.com/alexharv074/terraform-unit-testing-poc/blob/master/spec/spec_helper.rb#L8-L63).

```ruby
class TerraformTesting
  @@terraform = "#{ENV['HOME']}/go/bin/terraform"

  def eval(path, addr, mock_data)
    command = "#{@@terraform} testing eval #{path} #{addr} -"
    stdout, status = Open3.capture2(command, stdin_data: mock_data.to_json)

    result_raw = JSON.parse(stdout)

    if result_raw.has_key?('diagnostics')
      raise_diagnostics(result_raw["diagnostics"])
    end

    return prepare_result(result_raw["value"], result_raw["type"])
  end

 private

  def raise_diagnostics(diags)
    errs = []
    diags.each do |diag|
      errs << diag if diag["severity"] == "error"
    end
    raise RuntimeError, errs if errs.length > 0
  end

  def prepare_result(value, type)
    if value.nil?
      return nil
    end

    if type.is_a?(Array)
      case type[0]
      when "object"
        ret = Object.new
        value.each do |k,v|
          ret.singleton_class.instance_eval { attr_reader k.to_sym }
          ret.instance_variable_set("@#{k}", prepare_result(v, type[1][k]))
        end
        return ret
      when "tuple"
        ret = []
        value.each_with_index do |v, i|
          ret << prepare_result(v, type[1][i])
        end
        return ret
      when "list"
        ret = []
        value.each do |v|
          ret << prepare_result(v, type[1])
        end
        return ret
      when "map"
        ret = {}
        value.each do |k,v|
          ret[k] = prepare_result(v, type[1])
        end
        return ret
      when "set"
        ret = []
        value.each do |v|
          ret << prepare_result(v, type[1])
        end
        return ret
      end
    end

    return value
  end
end
```

### Using the supporting code

With this helper, I can then use Ruby to call `terraform testing eval` with this interface:

```ruby
TerraformTesting.new.eval(".", "aws_instance.this", {
  "variables": {
    "instance_count": 1,
    "ami": "ami-08589eca6dcc9b39c",
    "instance_type": "t2.micro",
    "ebs_block_device": []
  },
  "locals": {
    "key_name": "default"
  }
})
```

### Writing the test cases

#### Spec file structure

I will have to assume a little bit of Rspec of my reader from this point on, but not too much. I made the decision to structure my tests with a single Terraform resource inside a `describe` block and then for each data set passed in - that is, for each `DATA-FILE` argument to `terraform testing eval` - a new `context` block.

So all of my tests sit inside a `describe` block like this:

```ruby
require 'spec_helper' # The help code above comes from here.

describe "aws_instance.this" do
  # All test cases in here.
end
```

I also use explicit `subjects` to capture each of the calls to `terraform testing eval`.

#### Test case 1 - with instance_count 0

The simplest test case is for a 0 `instance_count`. My code looks like this:

```ruby
  context "with instance_count 0" do
    subject do
      TerraformTesting.new.eval(".", "aws_instance.this", {"variables": {"instance_count": 0}})
    end

    it "should be an empty list" do
      expect(subject).to eq []
    end
  end
```

Well this makes enough sense. With an `instance_count` of 0, the evaluation object is essentially empty. To execute the test:

```text
▶ bundle exec rspec spec/aws_ec2_instance_spec.rb

aws_instance.this
  with instance_count 0
    should be an empty list

Finished in 0.87809 seconds (files took 0.08449 seconds to load)
1 example, 0 failures
```

#### Test case 2 - with an instance_count of 1 and no EBS volumes

A slightly more interesting test case is the next one. An `instance_count` of 1 so that something actually gets created, but an empty list of EBS volumes. The code looks like this:

```ruby
  context "with instance_count 1" do
    context "with no EBS volumes" do
      subject do
        TerraformTesting.new.eval(".", "aws_instance.this", {
          "variables": {
            "instance_count": 1,
            "ami": "ami-08589eca6dcc9b39c",
            "instance_type": "t2.micro",
            "ebs_block_device": [],
            "mount_point": []
          },
          "locals": {
            "key_name": "default"
          }
        })[0]
      end

      it "should have AMI ami-08589eca6dcc9b39c" do
        expect(subject.ami).to eq "ami-08589eca6dcc9b39c"
      end

      it "should have instance_type t2.micro" do
        expect(subject.instance_type).to eq "t2.micro"
      end

      it "should have user_data with just the shebang line" do
        expect(subject.user_data.chomp).to eq "#!/usr/bin/env bash"
      end
    end
  end
```

#### Inspecting the subject with pry

Using the Ruby debugger, `pry`, it is interesting to have an actual look at some of the returned state. To do that, I can add a debugging line inside an `it` block:

```ruby
  it do
    require 'pry'; binding.pry
  end
```

Then when I execute:

```text
▶ bundle exec rspec spec/aws_ec2_instance_spec.rb

aws_instance.this
  with instance_count 0
    should be an empty list
  with instance_count 1
    with no EBS volumes

From: /Users/alexharvey/git/home/terraform-unit-testing-poc/spec/aws_ec2_instance_spec.rb @ line 36 :

    31:           }
    32:         })[0]
    33:       end
    34: 
    35:       it do
 => 36:         require 'pry'; binding.pry
    37:       end
    38:     end
    39:   end
    40: end
```

And I can inspect the Rspec "subject" - i.e. the Terraform evaluation object - like this:

```ruby
[1] pry(#<RSpec::ExampleGroups::AwsInstanceThis::WithInstanceCount1::WithNoEBSVolumes>)> subject                                                                      
=> #<Object:0x007fb1a6105090
 @ami="ami-08589eca6dcc9b39c",
 @arn=nil,
 @associate_public_ip_address=nil,
 @availability_zone=nil,
 @cpu_core_count=nil,
 @cpu_threads_per_core=nil,
 @credit_specification=[],
 @disable_api_termination=nil,
 @ebs_block_device=[],
 @ebs_optimized=nil,
 @ephemeral_block_device=[],
 @get_password_data=nil,
 @host_id=nil,
 @iam_instance_profile=nil,
 @id=nil,
 @instance_initiated_shutdown_behavior=nil,
 @instance_state=nil,
 @instance_type="t2.micro",
 @ipv6_address_count=nil,
 @ipv6_addresses=nil,
 @key_name="default",
 @monitoring=nil,
 @network_interface=[],
 @network_interface_id=nil,
 @password_data=nil,
 @placement_group=nil,
 @primary_network_interface_id=nil,
 @private_dns=nil,
 @private_ip=nil,
 @public_dns=nil,
 @public_ip=nil,
 @root_block_device=[],
 @security_groups=nil,
 @source_dest_check=nil,
 @subnet_id=nil,
 @tags=nil,
 @tenancy=nil,
 @timeouts=nil,
 @user_data="#!/usr/bin/env bash\n",
 @user_data_base64=nil,
 @volume_tags=nil,
 @vpc_security_group_ids=nil>
```

The `nil` is Ruby's equivalent of Terraform's `null` by the way. And if I want to inspect a specific attribute:

```ruby
[2] pry(#<RSpec::ExampleGroups::AwsInstanceThis::WithInstanceCount1::WithNoEBSVolumes>)> subject.user_data
=> "#!/usr/bin/env bash\n"
```

That there is my UserData script, of course, which I noted earlier would contain just a shebang line in the case of an empty array of EBS block devices.

> The general idea here would be to select some evaluatable sub-portion of the module (which could be a whole resource block, or an individual argument in a resource block, depending on what we think is useful) and evaluate it against a fake static data scope to get the value that Terraform would normally pass to the provider as the "configuration object".

#### Test case 3 - expecting errors

I won't of course be able to show all of the above test cases because there are too many, but I would like to show an example of expecting an error. In this case I look at a list of 2 EBS block devices where a mandatory parameter is missing:

```ruby
  context "EBS volumes with no block_device" do
    subject do
      TerraformTesting.new.eval(".", "aws_instance.this", {
        "variables": {
          "instance_count": 1,
          "ami": "ami-08589eca6dcc9b39c",
          "instance_type": "t2.micro",
          "ebs_block_device": [
            {"volume_size": 5},
            {"volume_size": 10}
          ],
          "mount_point": ["/data", "/home"]
        },
        "locals": {
          "key_name": "default"
        }
      })
    end

    it "should raise an error" do
      expect { subject }
        .to raise_error /This map does not have an element with the key.*device_name/
    end
  end
```

#### Test case 4 - testing user_data

The last example I am going to look at is testing the user_data string. This is interesting because now I am testing the logic of the `templatefile()` function's templating language.

```ruby
  context "complete with 2 EBS volumes" do
    subject do
      TerraformTesting.new.eval(".", "aws_instance.this", {
        "variables": {
          "instance_count": 1,
          "ami": "ami-08589eca6dcc9b39c",
          "instance_type": "t2.micro",
          "ebs_block_device": [
            {"device_name": "/dev/sdg"},
            {"device_name": "/dev/sdh"}
          ],
					"mount_point": ["/data", "/home"]
        },
        "locals": {
          "key_name": "default"
        }
      })[0]
    end

    context 'user_data' do
      before do
        @lines = subject.user_data.split("\n")
      end
      it "should have a mkfs line" do
        expect(@lines[1]).to match %r{mkfs -t xfs /dev/.*}
      end
      it "should have a mkdir line" do
        expect(@lines[2]).to match %r{mkdir -p /.*}
      end
      it "should have a mount line" do
        expect(@lines[3]).to match %r{mount /.* /.*}
      end
    end
  end
```

### The full suite

The full proof of concept and all of the unit tests I wrote are in GitHub [here](). To run them in the end:

```text
▶ bundle exec rspec spec/aws_ec2_instance_spec.rb                                                           

aws_instance.this
  with instance_count 0
    should be an empty list
  with instance_count 1
    with no EBS volumes
      should have AMI ami-08589eca6dcc9b39c
      should have instance_type t2.micro
      should have user_data with just the shebang line
    with two EBS volumes
      EBS volumes with no block_device
        should raise an error
      EBS volumes with no mount_point
        should raise an error
      minimal working with 2 EBS volumes
        ebs_block_device should have an attribute iops from the provider
        volume_size should be null
      with an unknown EBS volume option
        unknown attributes passed to ebs_block_device will be ignored unless their method is called
      complete with 2 EBS volumes
        should have an ebs_block_device list
        should have two ebs_block_devices
        device_name 0 should be /dev/sdg
        user_data
          should have a mkfs line
          should have a mkdir line
          should have a mount line

Finished in 13.21 seconds (files took 0.20484 seconds to load)
15 examples, 0 failures
```

## Limitations

At first glance it might seem that all of what can be done for Puppet in Rspec-puppet is now possible in Terraform. However, that is not the case and there are - currently - key differences and limitations relative to Rspec-puppet. Of course, these problems can be solved and I suspect they are not hard to solve either. Although, I am not familiar enough with the implementation of Terraform to be sure.

### Unit defined as the resource instead of module

Martin Atkins wrote in the comments [here]():

> I previously was thinking about doing this at the whole-module level, but I think in practice that would lead us back to my more recent idea of writing test doubles for all of the providers, because I think fake static data would not be sufficient in most real-world cases.

I must admit I don't fully understand what Martin meant here or why unit testing on resources rather than modules hasn't been made possible and this is certainly a key departure from the way Rspec-puppet works.

This may not be as big an issue as it first would appear, since, unlike Puppet, there is (currently anyway) no support in Terraform for control flow (if statements, for loops etc) at the module level- all the logic does occur inside resource declarations.

One consequence though is that [logic inside a locals declaration](https://github.com/hashicorp/terraform/issues/21628#issuecomment-508026165) can't be tested.

### No automatic mocking of defaults

Users of Rspec-puppet would notice that the requirement to provide fake data for all mandatory parameters is onerous. This again seems to follow from the decision to not test as the level of the whole module. I am not sure if reimplementing "terraform testing eval" would mean that module defaults would be automatically available or not. But we can all agree that it would be better if these defaults were available, whatever the implementation.

### No cache

In order to perform better, Rspec-puppet implements a "catalog cache" to ensure that compilation - which can be slow - occurs only once. There is no such thing in my proof of concept as yet and so these tests are much slower than the Rspec-puppet tests are.

### None of Rspec-puppet's conveniences

A minor issue to be sure is that all of this is done so far is pure Rspec and I need to explicitly define the subject, whereas Rspec-puppet hides all this in an implicit subject and a bunch of Puppet-specific matchers. Actually it could be argued that this is good and bad, because hiding so much Rspec from the user has led to far fewer Puppet users actually understanding Rspec!

## Concluding thoughts

Part of my motivation for writing this post is to show how close we are to making real unit testing possible in Terraform and to provide incentive for HashiCorp to finish off the feature and merge it. At the moment, Martin Atkins has said that delivering this feature is not high on HashiCorp's priorities, although it took only a couple of hours to implement this prototype.

In my own view, a tool like Terraform that lacks a unit testing framework is not safe for production. It is not a matter of if, but only when, a code base, whether written in the Terraform DSL or any other language, will require extensive refactoring. And, as things are, there will be so safe way to actually do that refactoring in Terraform when that point is reached. So, at the moment, my only recommendation would be to not use Terraform in production, ever. There are safer options: [Pulumi](https://www.pulumi.com), [AWS CDK](https://docs.aws.amazon.com/cdk/latest/guide/home.html), and I have written about [Troposphere](https://alexharv074.github.io/2018/12/01/configuration-management-with-troposphere-and-jerakia.html) here before.

If you are reading this, go and upvote the related issue and let HashiCorp know that it is not safe to use Terraform in production until they deliver this feature.

---

<sup>1</sup> In fact, even Puppet's professional services team prefers to use a tool [Onceover](https://github.com/dylanratcliffe/onceover) in lieu of real unit tests in Rspec-puppet.
