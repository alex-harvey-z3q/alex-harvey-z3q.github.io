---
layout: post
title: "Adventures in the Terraform DSL, Part VII: Resource for_each in Terraform 0.12.6"
date: 2019-09-17
author: Alex Harvey
tags: terraform
---

A discussion of the resource for_each feature that was added in Terraform 0.12.6 and comparison to Puppet's create_resources and resource iteration.

- ToC
{:toc}

## Introduction

I was excited about Terraform's resource for_each feature when it was announced because I frequently use the comparable create_resources feature in Puppet. Puppet's resource for_each was introduced in Puppet 2.6 in 2011. It is particularly useful if you have a number of resources that are like data more than config.

In this post, I look in detail at Terraform's new resource for_each feature, which was released recently in Terraform 0.12.6, and I cover off what it can do and compare it to the Puppet 2.6 create_resources feature as well as the Puppet 4 resource iteration. In the end I conclude that it is not possible to emulate Puppet's resource iteration and discuss therefore how Terraform could be improved.

Note that I focus more specifically on how to use Terraform's for_each back in [Part III]() so I don't repeat myself too much here.

## Resource iteration in Puppet

### The create_resources feature

The create_resources function was [committed](https://github.com/puppetlabs/puppet/commit/49059568d0e4e00bbc35d6f9b2a6cd23e7d00f46) by Dan Bode in March 2011 and released in Puppet 2.6. It has since somewhat divided the Puppet community, with some - like me - loving it and others hating it. But even those who hate it don't hate what it can do - the disagreement is over whether it is best to use create_resources or to use Puppet's DSL iteration features to achieve the same outcome.

The feature is most useful when you have a list of resources that feel just like 100% data and 0% config. Canonical examples might include lists of users, lists of firewall rules, and so on - whenever all the attributes in a resource declaration seem data-like and variable and none can be hard-coded.

So for example given a Hash of users:

```js
// A hash of user resources:
$myusers = {
  'nick' => { uid    => '1330',
              gid    => allstaff,
              groups => ['developers', 'operations', 'release'], },
  'dan'  => { uid    => '1308',
              gid    => allstaff,
              groups => ['developers', 'prosvc', 'release'], },
}
```

You can declare them all in one line using:

```puppet
create_resources(user, $myusers)
```

### Using resource iteration

And for those who hate create_resources I feel obligated to also show how it's done using the Puppet DSL's resource iteration:

```js
$myusers.each |$user,$data| {
  user { $user:
    * => $data
  }
}
```

Some find that to be more explicit whereas heathens like myself find it to be overly verbose! Either way, we end up with the same outcome - our users can be treated as data and moved off to wherever all the other data lives.

### Externalising in YAML

And because we typically keep our data in YAML files in Puppet, we probably have our users list looking like this:

```yaml
---
myuserclass::myusers:
  nick:
    uid: 1330
    gid: allstaff
    groups:
      - developers
      - operations
      - release
  dan:
    uid: 1308
    gid: allstaff
    groups:
      - developers
      - prosvc
      - release
```

And a class:

```puppet
class myuserclass($myusers) {
  create_resources(user, $musers)
}
```

## Terraform's resource for_each

Terraform's resource for_each is similar to the nested dynamic blocks for_each that I covered in more detail in the earlier post in this series, although it has two forms - a for_each resource in a map and for_each resource in a set. The original feature request for this is [here](https://github.com/hashicorp/terraform/issues/17179).

### map for_each

I will cover the same examples given in the Terraform [docs](https://www.terraform.io/docs/configuration/resources.html#for_each-multiple-resource-instances-defined-by-a-map-or-set-of-strings), although I've refactored this for clarity. Here is a map for_each that creates Azure resource groups:

```js
locals {
  azurerm_resource_groups = {
    a_group = "eastus"
    another_group = "westus2"
  }
}

resource "azurerm_resource_group" "rg" {
  for_each = local.azurerm_resource_groups
  name     = each.key
  location = each.value
}
```

What this will do is for each key-value pair in local.azurerm_resource_groups a azurerm_resource_group resource is created mapping the key onto the name attribute and value onto the location attribute.

_Notice that the structure of the data in the variable azurerm_resource_groups doesn't match the structure of the actual resource._

### set for_each

Terraform also allows resources to be declared for each element in a set. Use of sets rather than maps allows resources that differ by a single attribute to be declared for each element in a set. As in this example:

```js
variable "subnet_ids" {
  type = list(string)
}

resource "aws_instance" "server" {
  for_each = toset(var.subnet_ids)

  ami           = "ami-a1b2c3d4"
  instance_type = "t2.micro"
  subnet_id     = each.key // note: each.key and each.value are the same for a set

  tags {
    Name = "Server ${each.key}"
  }
}
```

Note that the toset() function needs to be used because there is no other way to declare a set in Terraform.

Also note well that comment there in the code, which I copied from the docs:

> each.key and each.value are the same for a set

Beware of this! This seems quite surprising and could lead to quite confusing code, especially if each.key and each.value are both used. I would be inclined to only ever use each.value to keep the code readable.

## Resource syntax in Terraform

In both of the above examples, data is transformed from either a map or set into a resource data by the for_each construct. This is very different to Puppet, where data is always passed as-is into the create_resources function.

Why is that?

Allow me a digression as I discuss a peculiarity of HCL's "blocks".

Consider a Terraform declaration of an AWS security group:

```js
resource "aws_security_group" "web_traffic" {
  name        = "web_traffic"
  description = "Allow inbound traffic"
  vpc_id      = "vpc-07a59518ae4faa320"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "-1"
    cidr_blocks = "10.0.0.0/8"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "-1"
    cidr_blocks = "10.0.0.0/8"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

Imagine I want to represent that as a map. Naively, I might try something like this:

```js
locals {
  aws_security_groups = {
    web_traffic = {
      description = "Allow web traffic"
      vpc_id      = "vpc-07a59518ae4faa320"
      ingress     = {
        from_port   = 80
        to_port     = 80
        protocol    = "-1"
        cidr_blocks = "10.0.0.0/8"
      }
      ingress     = {
        from_port   = 80
        to_port     = 80
        protocol    = "-1"
        cidr_blocks = "10.0.0.0/8"
      }
      egress      = {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
      }
    }
  }
}

output "output" {
  value = local.aws_security_groups
}
```

What I love about this is that the shape of the map exactly matches the shape of the original resource declaration. There is no need for any mind-bending transformations of the data when reading this code.

But if I apply it I'll see this:

```text
▶ terraform apply

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

output = {
  "web_traffic" = {
    "description" = "Allow inbound traffic"
    "egress" = {
      "cidr_blocks" = [
        "0.0.0.0/0",
      ]
      "from_port" = 0
      "protocol" = "-1"
      "to_port" = 0
    }
    "ingress" = {
      "cidr_blocks" = "10.0.0.0/8"
      "from_port" = 80
      "protocol" = "-1"
      "to_port" = 80
    }
    "name" = "allow_tls"
    "vpc_id" = "vpc-07a59518ae4faa320"
  }
}
```

Notice how one of my ingress blocks just disappeared because - yes, that's right - a map in Terraform, as with maps and hashes in other languages, is not able to contain duplicate keys. But a Terraform resource with multiple nested blocks like ingress declarations is exactly like that - a map or Hash that _is_ allowed to contain duplicated keys!

## Emulating Puppet's create_resources

As mentioned above, if the Puppet DSL could be used to solve this problem, we would store the resources in a map (a hash in Puppet's terminology) and pass it directly to create resources. We would have one line:

```puppet
create_resources(aws_security_group, $aws_security_groups)
```

In Terraform this is going to be a lot of work. 

### Replacing nested blocks with lists

Since it isn't going to be possible to represent a Terraform resource using a data structure that exactly matches the resource declarations I next tried just replacing the nested blocks with lists like this:

Data:

```js
locals {
  aws_security_groups = {
    web_traffic = {
      description = "Allow inbound traffic"
      vpc_id      = "vpc-07a59518ae4faa320"
      ingress     = [
        {
          from_port   = 80
          to_port     = 80
          protocol    = "-1"
          cidr_blocks = "10.0.0.0/8"
        },
        {
          from_port   = 80
          to_port     = 80
          protocol    = "-1"
          cidr_blocks = "10.0.0.0/8"
        },
      ]
      egress = {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
      }
    }
  }
}
```

Code:

```js
resource "aws_security_group" "aws_security_groups" {
  for_each    = local.aws_security_groups

  name        = each.key  // Emulate Puppet's Namevar
  description = each.value.description
  vpc_id      = each.value.vpc_id

  dynamic "ingress" {
    for_each  = each.value.ingress  // NOT ALLOWED!
    iterator  = "ing"
    content {
      from_port   = ing.value.from_port
      to_port     = ing.value.to_port
      protocol    = ing.value.protocol
      cidr_blocks = ing.value.cidr_blocks
    }
  }

  egress {
    from_port   = each.value.egress.from_port
    to_port     = each.value.egress.to_port
    protocol    = each.value.egress.protocol
    cidr_blocks = each.value.egress.cidr_blocks
  }
}
```

But this fails with an error 'There is no variable named "each"':

```text
▶ terraform apply

Error: Unknown variable

  on test.tf line 39, in resource "aws_security_group" "aws_security_groups":
  39:     for_each  = each.value.ingress

There is no variable named "each".
```

## Discussion - a possible solution

So, using Terraform 0.12.6 and the resource for_each, it appears that Puppet's create_resources function still cannot be emulated, at least without great difficulty and so much code complexity that it is probably not worth doing.

Is it an actual problem? Some Terraform true believers may say it is fine. And I remember only too well how so many in the Puppet community once said - "don't add iteration! It's not required!" Let me just say this. There is no problem defining sets or maps of data in Puppet and transforming them into resources. And in all the time I've used Puppet, I have never, ever seen anyone actually do that. So, I do think it is a real problem and the Terraform DSL is forcing the community to write code that is going to be unreadable.

Could it be fixed though?

Yes, if Terraform supported an alternative syntax for declaring nested blocks like this:

```js
resource "aws_security_group" "web_traffic" {
  name        = "web_traffic"
  description = "Allow inbound traffic"
  vpc_id      = "vpc-07a59518ae4faa320"

  ingress     = [   // A PROPOSAL ONLY. DOES NOT ACTUALLY WORK !!
    {
      from_port   = 80
      to_port     = 80
      protocol    = "-1"
      cidr_blocks = "10.0.0.0/8"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "-1"
      cidr_blocks = "10.0.0.0/8"
    },
  ]

  egress     = [{
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }]
}
```

While I am not familiar enough with Terraform's code base to be certain, I suspect it would be easy enough to implement it all the same. Actually, it looks really easy to fix! That's all I have to say about this.

## Conclusion

Today I have looked in detail at the Terraform 0.12.6 resource for_each and compared it specifically to the related features in Puppet. For anyone simply wanting to know how to use the feature, I had covered most of that in [Part III](https://alexharv074.github.io/2019/06/02/adventures-in-the-terraform-dsl-part-iii-iteration-enhancements-in-terraform-0.12.html) of this series, whereas today I have focused on what the feature still can't do, and I've proposed a way for HashiCorp to make it possible in a future release.

Stay tuned for Part VIII - yes, there is a Part VIII coming! - where I look at the Terraform Puppet provisioner.
