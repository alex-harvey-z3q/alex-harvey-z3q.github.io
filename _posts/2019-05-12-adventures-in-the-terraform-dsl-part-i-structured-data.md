---
layout: post
title: "Adventures in the Terraform DSL, Part I: Structured data"
date: 2019-05-12
author: Alex Harvey
tags: terraform
---

This is a blog series aimed at experienced developers who want to learn the Terraform DSL quickly. I assume that the reader has finished the official [Getting Started](https://learn.hashicorp.com/terraform/?track=getting-started#getting-started) tutorial, has created and destroyed some cloud resources using Terraform, and probably also knows other high-level programming languages like Python or Ruby.

In this first part, I look at Terraform's data types, the `lookup()` and `element()` functions, how to address the elements of lists inside maps of lists, and how to address the keys of maps inside lists of maps. Along the way I introduce Terraform's three types of variables and its data types.

- ToC
{:toc}

## What is the problem

Addressing structured data in languages like Python, Ruby or Perl is trivial. Given a list `mylist`, its `n`th element can be addressed using the familiar notation `mylist[n]`. And given a map `mymap`, the value associated with a key `key` can be addressed using the notation `mymap[key]`. Then, nested data can be addressed by combining these notations. Thus, the first element of a list associated with the key `key` in a map `mymap` can be addressed as `mymap[key][0]`; and the value associated with key `key` in the map in the third element of a list `mylist` can be addressed as `mylist[2][key]`. And so on.

In Terraform 0.11, the notations `mylist[n]` and `mymap[key]` are supported, but, when combined, are not. For example, you might expect this to work:

```tf
# test.tf

locals {
  foo = [{bar = "baz"}]
}

output "qux" {
  value = "${local.foo[0]["bar"]}"
}
```

Testing:

```text
▶ terraform apply

Error: Error loading test.tf: Error reading config for output foo: parse error at 1:15: expected "}" but found "["
```

In Terraform 0.12-beta2 however it works fine:

```text
▶ terraform012 apply

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

bar = baz
```

This post, therefore, is about the workaround. How to use the `lookup()` and `element()` functions to workaround these problems, and how in general to access nested data in Terraform.

## Input variables, output variables and local values

### Definitions

Terraform has three different kinds of variables: _input variables_ which serve as parameters in Terraform modules; _output values_ that are returned to the user when Terraform applies and can be queried using the terraform output command; and _local values_ which, strictly-speaking, assign a name to an _expression_. Or, if an analogy to a function is preferred, then, as the docs note, input variables are analogous to function arguments, output values are analogous to function return values, and local values are analogous to a function's local variables.

### Declaring input variables

Here is an example of declaring an input variable in a module:

```tf
variable "zones" {
  type = "list"
  default = ["us-east-1a", "us-east-1b"]
}
```

If that variable is an input to a module, `mymodule`, then the module can be called and a value passed to that variable like this:

```tf
module "mymodule" {
  source "./mymodule"
  zones = ["ap-southeast-2"]
}
```

And if nothing was specified for zones, then the default would be used. Specification of the variable type is optional but recommended. It will cause Terraform to fail with a more helpful message if data of an unexpected type is passed in.

### Addressing an input variable

To address an input variable, use the notation `var.<NAME>`. For example:

```tf
variable "key" {
  type = "string"
}

output "key" {
  value = "${var.key}"
}
```

### Declaring a local value

Now, here is an example of declaring a local value instead:

```tf
locals {
  common_tags = {
    PowerMgt     = "business_hours"
    Environment = "production"
  }
}
```

There is no way to declare the type of a local value, and Terraform will infer its type.

Note that local values are also referred to in the docs as _local named variables_, or as _variables_, or as _temporary variables_.

### Addressing a local value

To address a local value, use the notation `local.<NAME>`. For example:

```tf
locals {
  foo = "bar"
}

output "baz" {
  value = "${local.foo}"
}
```

### Declaring an output value

The examples above have already introduced the output value. Once again:

```tf
output "addresses" {
  value = ["${aws_instance.web.*.public_dns}"]
}
```

(Note that the splat notation there will be covered in part II on iteration.)

## Terraform data types

As we have seen by now, Terraform has a number of data types. These are:

- `string`: a sequence of Unicode characters representing some text, like "hello".
- `number`: which, perhaps surprisingly, can represent both integers like 42, and floats like 3.14.
- `bool`: a boolean, i.e. true or false.
- `list`: a sequence of ordered values, like `["us-west-1a", "us-west-1c"]`.
- `set`: similar to a list, but an unordered collection of unique values.
- `map`: a collection of values identified by keys, like a dict in Python or a Hash in Ruby, Perl etc, e.g. `{name = "Mabel", age = 52}`.

Terraform's documentation refers to strings, numbers and bools as _primitive types_ and to lists, maps and sets as _collection types_. In addition to these, there are also _structural types_:

- object: a map with a schema, for example `object({ name=string, age=number })`.
- tuple: a list with a schema, for example `tuple([string, number, bool])`.

The purpose of these types is, much as in Puppet for those familiar with Puppet, validating input data.

In this post, however, I am only interested in strings, lists and maps.

## Addressing structured data

For the remainder of this article, I explore the various permutations of the problem of addressing structured data in Terraform 0.11 and 0.12-beta2. As mentioned already, I do this because I take it to be the problem that an experienced developer will need to get their head around when picking up the Terraform DSL.

### Addressing a list

In this example I declare a local list and then address the whole list in an output value. (I use output values throughout this post, because Terraform prints those during a terraform apply. It is the closest there is to a "print" statement in Terraform.)

```tf
locals {
  foo = ["bar", "baz", "qux"]
}

output "quux" {
  value = "${local.foo}"
}
```

Note also the requirement in Terraform 0.11 and earlier to _interpolate_ `local.foo` inside a string. As I'll explain later, that is no longer required in Terraform 0.12.

Now, to test:

```text
▶ terraform apply

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

quux = [
    bar,
    baz,
    qux
]
```

### Addressing an element in a list

Addressing an _element_ in a list is also no big deal. Here's how it's done:

```tf
locals {
  foo = ["bar", "baz", "qux"]
}

output "quux" {
  value = "${local.foo[1]}"
}
```

Testing:

```text
▶ terraform apply

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

quux = baz
```

### Addressing a map

Next, I am going to create a local map variable and reference it to address a whole map:

```tf
locals {
  foo = {
    bar = "baz"
    qux = "quux"
  }
}

output "quuz" {
  value = "${local.foo}"
}
```

Testing:

```text
▶ terraform apply

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

quuz = {
  bar = baz
  qux = quux
}
```

### Addressing a key in a map

To address a key in a map, we can again use notation familiar to us from other languages like Python and Ruby. Assuming the same local `foo`, I can address the `bar` key as:

```tf
output "quuz" {
  value = "${local.foo["bar"]}"
}
```

Note also that, like Bash, Terraform allows interpolation of double quotes inside double quotes.

### Addressing a list of maps

The fun starts when there is nested data, that is, lists of maps, maps of lists and so on. In this example, I create an output value that outputs a list of maps:

```tf
locals {
  foo = [
    {
      bar = "baz"
      qux = "quux"
    },
    {
      quuz = "corge"
      grault = "garply"
    },
  ]
}
```

Now, addressing the whole data structure is, as usual, fine:

```tf
output "waldo" {
  value = "${local.foo}"
}
```

### Addressing an element of a list of maps

Addressing one element of a list of maps is also fine:

```tf
output "waldo" {
  value = "${local.foo[0]}"
}
```

Testing:

```text
▶ terraform apply

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

waldo = {
  bar = baz
  qux = quux
}
```

### Addressing a key in an element of a list of maps

But, if I try to address the key `bar`, I get a parse error:

```tf
output "waldo" {
  value = "${local.foo[0]["bar"]}"
}
```

Applying:

```text
▶ terraform apply

Error: Error loading terraform-test/test.tf: Error reading config for output waldo: parse error at 1:15: expected "}" but found "["
```

### Addressing an element in a key in a map of lists

Before I continue, I also wish to introduce the parallel problem of the element within a key of a map of lists. Consider:

```tf
locals {
  foo = {
    bar = ["baz", "qux", "quux"]
    quuz = ["corge", "grault", "garply"]
  }
}
```

Once again, addressing the whole structure is fine; addressing one key of that structure is fine:

```tf
output "waldo" {
  value = "${local.foo["bar"]}"
}
```

Which leads to:

```text
▶ terraform apply

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

waldo = [
    baz,
    qux,
    quux
]
```

But addressing an element of that key within the structure also leads to a parse error:

```tf
output "waldo" {
  value = "${local.foo["bar"][1]}"
  }
```

And:

```text
▶ terraform apply

Error: Error loading terraform-test/test.tf: Error reading config for output waldo: parse error at 1:19: expected "}" but found "["
```

## Good news - Terraform 0.12-beta2

In the forthcoming Terraform 0.12 this problem appears to be resolved. If I switch to my Terraform 0.12-beta2 binary:

```tf
locals {
  foo = [
    {
      bar = "baz"
      qux = "quux"
    },
    {
      quuz = "corge"
      grault = "garply"
    },
  ]
}

output "waldo" {
  value = "${local.foo[0]["bar"]}"
}
```

And I get:

```text
▶ terraform012 apply

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

waldo = baz
```

In fact, in Terraform 0.12 there are [first-class expressions](https://www.hashicorp.com/blog/terraform-0-12-preview-first-class-expressions), meaning it is no longer necessary to wrap the expression in double quotes. Thus, this also works:

```js
output "waldo" {
  value = local.foo[0]["bar"]
}
```

And if I try the other case:

```tf
locals {
  foo = {
    bar = ["baz", "qux", "quux"]
    quuz = ["corge", "grault", "garply"]
  }
}

output "waldo" {
  value = local.foo["bar"][1]
}
```

I get:

```text
▶ terraform012 apply

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

waldo = qux
```

Even something arbitrarily complex like this works in 0.12:

```tf
locals {
  foo = {
    bar = [
      {
        baz = "qux"
        quux = ["quuz", "corge"]
      }
    ]
  }
}

output "waldo" {
  value = local.foo["bar"][0]["quux"][1]
}
```

## The lookup and element functions

### Using lookup

In the mean time, the normal way of working around this problem in Terraform is via the `lookup()` and `element()` functions. Switching back to Terraform 0.11 and this example:

```tf
locals {
  foo = [
    {
      bar = "baz"
      qux = "quux"
    },
    {
      quuz = "corge"
      grault = "garply"
    },
  ]
}
```

I can access the key "bar" using the lookup function as follows:

```tf
output "waldo" {
  value = "${lookup(local.foo[0], "bar")}"
}
```

That's quite inconvenient and ugly of course and I expect that the release of Terraform 0.12 will lead to code like this being gradually refactored. For the moment, that's how it's done.

### Using element

Switching to the other example:

```tf
locals {
  foo = {
    bar = ["baz", "qux", "quux"]
    quuz = ["corge", "grault", "garply"]
  }
}
```

And I can use element as:

```tf
output "waldo" {
  value = "${element(local.foo["bar"], 1)}"
}
```

### More complex

Returning to the arbitrarily complex example from before:

```tf
locals {
  foo = {
    bar = [
      {
        baz = "qux"
        quux = ["quuz", "corge"]
      }
    ]
  }
}
```

Unfortunately, it appears impossible to deal with that even using lookup/element. Because:

```tf
output "waldo" {
  value = "${element(local.foo["bar"], 0)}"
}
```

Leads to:

```text
▶ terraform apply

Error: output.waldo: element: element() may only be used with flat lists, this list contains elements of type map in:

${element(local.foo["bar"], 0)}
```

Similar restrictions apply on the lookup function too.

## Summary

That is the end of part 1. If you are new to Terraform, you may like to just wait for Terraform 0.12! If on the other hand, you need to, or want to, learn Terraform 0.11 and earlier, I have shown in this post how to address complex, nested data in the Terraform DSL, and some of the limitations. Along the way, I covered the Terraform variable types and its data types.

Stay tuned for Part II, where I will look at iteration in the Terraform DSL.
