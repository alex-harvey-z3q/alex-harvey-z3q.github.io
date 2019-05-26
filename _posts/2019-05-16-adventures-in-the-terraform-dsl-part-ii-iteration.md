---
layout: post
title: "Adventures in the Terraform DSL, Part II: Iteration in Terraform 0.11 and earlier"
date: 2019-05-16
author: Alex Harvey
tags: terraform
---

In this second part of my blog series, I look at iteration in the Terraform 0.11 DSL and earlier. For iteration in Terraform 0.12-beta2, stay tuned for Part III of this series.

* ToC
{:toc}

## Introduction

Iteration in Terraform has evolved in a similar way as it did in Puppet:

- Puppet 2005 (Terraform 2014): "Puppet (Terraform) is a declarative DSL. If you need iteration, you're doing it wrong."
- Puppet (Terraform) a bit later: "Well ok. If you declare an array (count) of resources that's kind of iteration isn't it. Don't do it too often."
- Puppet 2015 (Terraform 2020): "Puppet (Terraform) supports a clean, explicit iteration grammar borrowed from Ruby (Golang). It is considered bad style to declare an array (count) of resources the old way. Go forth and iterate!"

Well that's a [true story](https://puppet.com/docs/puppet/5.3/style_guide.html#multiple-resources) about the style guide in Puppet, and it should be true of Terraform by the end of 2019!

This post, if you like, is James Schubin's [Iteration in Puppet](https://ttboj.wordpress.com/2013/11/17/iteration-in-puppet/) much ranked 2013 post on iteration in Puppet in the bad old days - but for Terraform 0.11. And in Part III, I look at iteration in Terraform 0.12-beta2.

## Iteration in Terraform 0.11

### Iteration I: A count of identical resources

#### Meta parameters

Before I get to Terraform's `count`, I want to mention its _meta parameters_ (which are now known as _meta arguments_ in the 0.12 documentation). These are defined as special parameters that are accepted by all resources. These are similar to meta parameters in Puppet, and also to what Amazon's documentation calls "additional resource attributes" in AWS CloudFormation.

The following are available to all Terraform resources:

- `count`: The number of identical resources to create.<sup>1</sup>
- `depends_on`: A list of explicit dependencies that a resource has. This is the same as `DependsOn` in CloudFormation.
- `provider`: Allows specification of a non standard provider for a resource.
- `lifecycle`: Allows customisation of the resource lifecycles with such options as `create_before_destroy`, to ensure that a new instance is created before the old one is destroyed; `prevent_destroy`, similar to what can be done with `DeletionPolicy` in CloudFormation; and `ignore_changes`, which is interesting, because it allows changes to these resources outside of Terraform to be ignored.

In addition to these, some resources accept:

- `timeouts`: block to enable users to configure the amount of time a specific operation is allowed to take before being considered an error.

#### Count

Of course, this post is about iteration and `count` is Terraform 0.11 and earlier's answer to iteration. By specifying a `count` = _n_ against any resource, Terraform, under the hood, creates an array of _n_ instances of the resource. It is best to see this in some examples.

#### Example 1: A pool of random_ids

And when I say "identical" I am talking about their configs in Terraform of course. In this first example, I create three random_ids, and I "print" them by declaring outputs.

```js
resource "random_id" "tf_bucket_id" {
  byte_length = 2
  count = 3
}
```

When I apply this, note the array created:

```text
▶ terraform apply
…
random_id.tf_bucket_id[1]: Creation complete after 0s (ID: U6k)
random_id.tf_bucket_id[2]: Creation complete after 0s (ID: ogs)
random_id.tf_bucket_id[0]: Creation complete after 0s (ID: m-I)

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.
```

And note also that the parallel creation of resources array and thus the random ordering.

#### Example 2: A pool of EC2 instances

Or, I could create a pool of identical EC2 instances. For example:

```js
resource "aws_instance" "web" {
  instance_type = "m1.small"
  ami           = "ami-b1cf19c6"

  // This will create 4 instances
  count = 4
}
```

### Iteration II: A count of resources that differ only by the array index

#### count.index

When the `count` meta parameter is used, the `count` object is available within the block that declared it. This object has one attribute, `count.index`, which provides the index number (starting with 0) for each instance. In this way, `count.index` gives you access to the Array indices that were seen printed on the screen in the previous examples.

#### Example 3: A pool of EC2 instances with unique Name tags

One use of `count.index` is to expose this attribute in a Name tag. For example:

```js
resource "aws_instance" "web" {
  instance_type = "m1.small"
  ami           = "ami-b1cf19c6"

  // This will create 4 instances
  count = 4

  tags {
    Name = "web-${count.index}"
  }
}
```

#### Example 4: Interpolating simple maths

You can even perform simple maths transformations inside a Terraform interpolation. Thus, this is also possible:

```js
resource "aws_instance" "web" {
  instance_type = "m1.small"
  ami           = "ami-b1cf19c6"

  // This will create 4 instances
  count = 4

  tags {
    Name = "${format("web-%03d", count.index + 1)}"
  }
}
```

### Interation III: Count, count.index and length

#### Digression: Iteration in Puppet 3 and earlier

Back in the bad old days of Puppet 3 and earlier, iteration in Puppet was done something like this:

```js
$rc_dirs = [
  '/etc/rc.d',       '/etc/rc.d/init.d','/etc/rc.d/rc0.d',
  '/etc/rc.d/rc1.d', '/etc/rc.d/rc2.d', '/etc/rc.d/rc3.d',
  '/etc/rc.d/rc4.d', '/etc/rc.d/rc5.d', '/etc/rc.d/rc6.d',
]

file { $rc_dirs:
  ensure => directory,
  owner  => 'root',
  group  => 'root',
  mode   => '0755',
}
```

And, to be honest, this was never called "iteration" in the Puppet community. It was just passing an array as a resource title and relying on some magic to create a file for each element of the array.

Well, it turns out that iteration in Terraform 0.11 and earlier is most of the time very similar to the old approach used in Puppet. This section expands on this to show how to declare an array of resources and have control over their attributes.

#### The length function

But firstly, a new function is needed. The built-in `length()` function returns either the length of a string or the length of a list. Thus, given the following Terraform code:

```js
locals {
  foo = ["bar", "baz", "qux"]
}

output "quux" {
  value = "${length(local.foo)}"
}
```

I see 3 when I apply:

```text
▶ terraform apply

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

quux = 3
```

It is also possible to declare lists on the fly using the `list()` function, so this also works:

```js
output "quux" {
  value = "${length(list("foo","bar","baz"))}"
}
```

#### Example 5: Declare a list of IAM users

Combining the `length()` function with the `count` meta parameter and its `count.index`, it is now possible to iterate over a list:

```js
locals {
  users = ["bill", "ted", "rufus"]
}

resource "aws_iam_user" "users" {
  count = "${length(local.users)}"
  name  = "${local.users[count.index]}"
}
```

Applying that, three users are created:

```text
aws_iam_user.users[2]: Creation complete after 3s (ID: rufus)
aws_iam_user.users[0]: Creation complete after 4s (ID: bill)
aws_iam_user.users[1]: Creation complete after 4s (ID: ted)

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.
```

And as can be seen, `aws_iam_user.users[0]` corresponds to `bill`, the first element of the list that was declared.

#### The element function

Be aware that many of the examples of iteration out on the Internet also use the `element()` function in the context of iteration. There are two reasons for this:

1. Until Terraform 0.10.4, the code I've provided above does not work.
1. Yevgeniy Brikman's influential [blog post](https://blog.gruntwork.io/terraform-tips-tricks-loops-if-statements-and-gotchas-f739bbae55f9) and book _Terraform Up and Running_ - written while Terraform 0.8 was current - uses it.

Using Terraform 0.9.11 for example, the code I provided above errors out with this:

```text
▶ terraform0911 apply
Failed to load root config module: Error loading /Users/alexharvey/git/home/terraform-test/test.tf: Error reading config for aws_iam_user[users]: local.users: resource variables must be three parts: TYPE.NAME.ATTR in:

${local.users[count.index]}
```

So, if you are using a Terraform that's even earlier than 0.10.4 - or if you simply want to align to the style used in most examples - use the `element()` function as follows:

```js
locals {
  users = ["bill", "ted", "rufus"]
}

resource "aws_iam_user" "users" {
  count = "${length(local.users)}"
  name  = "${element(local.users, count.index)}"
}
```

### Iteration IV: Splat notation

#### Addressing resource attributes

In the above examples, I created a list of IAM users. The attributes of those users can be addressed using the notation `"${TYPE.NAME.INDEX.ATTRIBUTE}"`. For example:

```js
output "bills_arn" {
  value = "${aws_iam_user.users.0.arn}"
}
```

And if I apply again I'll see:

```text
▶ terraform apply
aws_iam_user.users[1]: Refreshing state... (ID: ted)
aws_iam_user.users[2]: Refreshing state... (ID: rufus)
aws_iam_user.users[0]: Refreshing state... (ID: bill)

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

bills_arn = arn:aws:iam::123456789012:user/bill
```

#### Addressing a list of resource attributes using splat

And if I want all of the ARNs returned as a list, I can use Terraform's splat (`*`) notation:

```js
output "arns" {
  value = "${aws_iam_user.users.*.arn}"
}
```

And if I apply that:

```text
▶ terraform apply
aws_iam_user.users[0]: Refreshing state... (ID: bill)
aws_iam_user.users[2]: Refreshing state... (ID: rufus)
aws_iam_user.users[1]: Refreshing state... (ID: ted)

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

arns = [
    arn:aws:iam::123456789012:user/bill,
    arn:aws:iam::123456789012:user/ted,
    arn:aws:iam::123456789012:user/rufus
]
```

#### Wrapping the splat in a list declaration

Another historical legacy that deserves a note is the wrapping of the splat inside a list, which may appear redundant. The code I just wrote is usually written this way:

```js
output "arns" {
  value = ["${aws_iam_user.users.*.arn}"]
}
```

And that's confusing, because if `$aws_iam_user.users.*.arn` is a list, then you would expect `["${aws_iam_user.users.*.arn}"]` to be a list of lists. But no, it's still just a list, and if I apply:

```text
▶ terraform apply
...
arns = [
    arn:aws:iam::123456789012:user/bill,
    arn:aws:iam::123456789012:user/ted,
    arn:aws:iam::123456789012:user/rufus
]
```

This is because until Terraform 0.9, this code here:

```js
output "arns" {
  value = "${aws_iam_user.users.*.arn}"
}
```

Would yield this error here:

```text
▶ terraform088 apply
module root: 1 error(s) occurred:                          
                                                          
* output 'arns': use of the splat ('*') operator must be wrapped in a list declaration
```

## Summary

And on that note I'm wrapping up Part II of this series. In this post, I have covered all the tricks of doing iteration in Terraform 0.11 and earlier. I've looked at the `count` meta parameter, its attribute `count.index`, the `length()` function, the splat (`*`) notation, and how to combine all this to iterate over lists of resources, with some examples. Along the way I've discussed some of the historical quirks such as use of the `element()` function and why splats are usually seen wrapped in apparently redundant list declaration.

In Part III, I will be looking at the brave new world of real iteration using Golang-like `for` and `for each` loops as are now available in Terraform 0.12-beta2.

---

<sup>1</sup> At the time of writing, Hashicorp's documentation lists `count` in a section "meta parameters available to all resources" but then states that `count` "doesn't apply to all resources." I understand this to mean that `count` is available to all resources, as long as the underlying provider supports creating multiple resources.
