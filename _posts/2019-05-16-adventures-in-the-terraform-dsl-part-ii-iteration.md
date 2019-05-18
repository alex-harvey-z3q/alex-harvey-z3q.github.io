---
layout: post
title: "Adventures in the Terraform DSL, Part II: Iteration"
date: 2019-05-16
author: Alex Harvey
tags: terraform
published: false
---

In this second part of my blog series, I look at iteration in the Terraform DSL, both in Terraform 0.11 and Terraform 0.12-beta2.

* ToC
{:toc}

## Overview

Iteration in Terraform has evolved in a similar way as it did in Puppet:

- Puppet 2005 (Terraform 2014): "Puppet (Terraform) is a declarative DSL. If you need iteration, you're doing it wrong."
- Puppet (Terraform) a bit later: "Well ok. If you declare an array (count) of resources that's kind of iteration isn't it. Don't do it too often."
- Puppet 2015 (Terraform 2020): "Puppet (Terraform) supports a clean, explicit iteration grammar borrowed from Ruby (Golang). It is considered bad style to declare an array (count) of resources the old way. Go forth and iterate!"

Well that's a [true story](https://puppet.com/docs/puppet/5.3/style_guide.html#multiple-resources) about the style guide in Puppet, and it should be true of Terraform by the end of 2019!

The first part of this post, if you like, is James Schubin's [Iteration in Puppet](https://ttboj.wordpress.com/2013/11/17/iteration-in-puppet/) much ranked 2013 post on iteration in Puppet in the bad old days - for Terraform 0.11. And in the second part, I look at iteration in Terraform 0.12-beta2.

## Iteration in Terraform 0.11

### Meta parameters

Before I get to Terraform's `count`, I want to mention its _meta parameters_, which are also known as _meta arguments_ in the 0.12 documentation. These are defined as special parameters that are accepted by all resources. These are similar to meta parameters in Puppet, and also what Amazon's documentation calls "additional resource attributes" in AWS CloudFormation.

The following are available to all Terraform resources:

- `count`: The number of identical resources to create.<sup>1</sup>
- `depends_on`: A list of explicit dependencies that a resource has. This is the same as `DependsOn` in CloudFormation.
- `provider`: Allows specification of a non standard provider for a resource.
- `lifecycle`: Allows customisation of the resource lifecycles with such options as `create_before_destroy`, to ensure that a new instance is created before the old one is destroyed; `prevent_destroy`, similar to what can be done with `DeletionPolicy` in CloudFormation; and `ignore_changes`, which is interesting, because it allows changes to these resources outside of Terraform to be ignored.

In addition to these, some resources accept:

- `timeouts`: block to enable users to configure the amount of time a specific operation is allowed to take before being considered an error.

### Count

#### The count meta parameter

Of course, this post is about iteration and `count` is Terraform 0.11 and earlier's answer to iteration. By specifying a `count` = _n_ against any resource, Terraform, under the hood, creates an array of _n_ instances of the resource. It is best to see this in some examples.

#### A count of identical resources

And when I say "identical" I am talking about their config in Terraform of course. In this first example, I create three random_ids, and I "print" them by declaring outputs.

```js
resource "random_id" "tf_bucket_id" {
  byte_length = 2
  count = 3
}
```

When I apply this, note the array created:

```js
▶ terraform apply

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  + random_id.tf_bucket_id[0]
      id:          <computed>
      b64:         <computed>
      b64_std:     <computed>
      b64_url:     <computed>
      byte_length: "2"
      dec:         <computed>
      hex:         <computed>

  + random_id.tf_bucket_id[1]
      id:          <computed>
      b64:         <computed>
      b64_std:     <computed>
      b64_url:     <computed>
      byte_length: "2"
      dec:         <computed>
      hex:         <computed>

  + random_id.tf_bucket_id[2]
      id:          <computed>
      b64:         <computed>
      b64_std:     <computed>
      b64_url:     <computed>
      byte_length: "2"
      dec:         <computed>
      hex:         <computed>


Plan: 3 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

random_id.tf_bucket_id[2]: Creating...
  b64:         "" => "<computed>"
  b64_std:     "" => "<computed>"
  b64_url:     "" => "<computed>"
  byte_length: "" => "2"
  dec:         "" => "<computed>"
  hex:         "" => "<computed>"
random_id.tf_bucket_id[1]: Creating...
  b64:         "" => "<computed>"
  b64_std:     "" => "<computed>"
  b64_url:     "" => "<computed>"
  byte_length: "" => "2"
  dec:         "" => "<computed>"
  hex:         "" => "<computed>"
random_id.tf_bucket_id[0]: Creating...
  b64:         "" => "<computed>"
  b64_std:     "" => "<computed>"
  b64_url:     "" => "<computed>"
  byte_length: "" => "2"
  dec:         "" => "<computed>"
  hex:         "" => "<computed>"
random_id.tf_bucket_id[1]: Creation complete after 0s (ID: U6k)
random_id.tf_bucket_id[2]: Creation complete after 0s (ID: ogs)
random_id.tf_bucket_id[0]: Creation complete after 0s (ID: m-I)

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.
```

These resources are created that 

---

<sup>1</sup> At the time of writing, Hashicorp's documentation lists `count` in a section "meta parameters available to all resources" but then states that `count` "doesn't apply to all resources." I understand this to mean that `count` is available to all resources, as long as the underlying provider supports creating multiple resources.
