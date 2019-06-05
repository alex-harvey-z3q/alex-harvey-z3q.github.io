---
layout: post
title: "Adventures in the Terraform DSL, Part III: Iteration enhancements in Terraform 0.12"
date: 2019-06-02
author: Alex Harvey
tags: terraform
---

In this third part of my blog series on the Terraform DSL, I look at `for` and `for_each` expressions and briefly mention further iteration enhancements not available in Terraform 0.12.1<sup>1</sup> but promised to be coming soon.

- ToC
{:toc}

## Introduction

In [Part II](https://alexharv074.github.io/2019/05/16/adventures-in-the-terraform-dsl-part-ii-iteration.html), I covered traditional iteration in Terraform 0.11 and earlier. I looked at the `count` meta parameter and discussed the pattern of using the `length()` and `element()` functions to create a list of resources, in a similar way to what was done in Puppet 3 and earlier.

In this post, I look at the enhancements to iteration introduced in Terraform 0.12, notably `for` expressions, which are modelled on Python list comprehensions, and `for_each` expressions and dynamic nested blocks, which for the first time allow generation of nested blocks like `ingress` rules and so on.

There is also a new generalised splat operator, but that is going to have to wait until my Part IV.

## Iteration in Terraform 0.12

### Iteration V: Transforming lists and maps<sup>2</sup>

#### List comprehensions in Python

Terraform `for` expressions are grammatically similar to and actually modelled on the list comprehension feature of Python and Haskell, which was specifically requested in the original [feature request](https://github.com/hashicorp/terraform/issues/8439). And, for anyone unfamiliar with Python's list comprehension, it is similar to the map feature of other languages like Ruby and Perl 5.

A list comprehension in Python looks like this:

```python
>>> numbers = [1, 2, 3, 4]
>>> squares = [n**2 for n in numbers]
>>> squares
[1, 4, 9, 16]
```

And they can be further filtered by adding an `if` expression, like this:

```python
>>> even = [n for n in squares if n % 2 == 0]
>>> even
[4, 16]
```

#### For expressions

Terraform's `for` expression, meanwhile, is pretty much the same. A [`for` expression](https://www.terraform.io/docs/configuration/expressions.html):

> ... creates a complex type value by transforming another complex type value. Each element in the input value can correspond to either one or zero values in the result, and an arbitrary expression can be used to transform each input element into an output element.

#### Example 6: Transforming a list into another list

Here is an example:

```js
locals {
  arr = ["host1", "host2", "host3"]
}

output "test" {
  value = [for s in local.arr: upper(s)]
}
```

Applying that:

```text
▶ terraform012 apply

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

test = [
  "HOST1",
  "HOST2",
  "HOST3",
]
```

And for comparison, the same code in Python would be:

```python
>>> arr = ["host1", "host2", "host3"]
>>> value = [s.upper() for s in arr]
>>> value
['HOST1', 'HOST2', 'HOST3']
```

Very pythonic.

#### Example 7: Filtering a list

And again, as in Python, Terraform lists can also be filtered by adding an `if` in the `for` expression:

```js
locals {
  arr = [1,2,3,4,5,6,7,8,9,10]
}

output "test" {
  value = [for n in local.arr: n if n > 5]
}
```

And for reference, in Python, that would be:

```python
>>> arr = [1,2,3,4,5,6,7,8,9,10]
>>> value = [n for n in arr if n > 5]
>>> value
[6, 7, 8, 9, 10]
```

#### Example 8: Transforming a list into a map

Map transformations in Terraform are also Pythonic. If I change my Terraform code to:

```js
locals {
  arr = ["host1", "host2", "host3"]
}

output "test" {
  value = {for s in local.arr : s => upper(s)}
}
```

And apply that, I get:

```text
▶ terraform012 apply

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

test = {
  "host1" = "HOST1"
  "host2" = "HOST2"
  "host3" = "HOST3"
}
```

And again comparing this with Python:

```python
>>> arr = ["host1", "host2", "host3"]
>>> value = {s: s.upper() for s in arr}
>>> value
{'host3': 'HOST3', 'host2': 'HOST2', 'host1': 'HOST1'}
```

#### Example 9: Transforming a map into a list

To iterate over a map, Terraform provides a `keys()` and `values()` function, similar to corresponding methods in Python. Thus, this sort of thing is possible:

```js
locals {
  mymap = {
    "foo" = { "id" = 1 }
    "bar" = { "id" = 2 }
    "baz" = { "id" = 3 }
  }
}

output "test" {
  value = [for v in values(local.mymap): v["id"]]
}
```

Which is to Terraform as this is to Python:

```python
>>> mymap = {'foo': {'id': 1}, 'bar': {'id': 2}, 'baz': {'id': 3}}
>>> value = [v['id'] for v in mymap.values()]
>>> value
[1, 2, 3]
```

#### Example 10: A real life example

All of this is good and theoretical although the reader may want a real life example at this point. Here is one:

```js
variable "vpc_id" {
  description = "ID for the AWS VPC where a security group is to be created."
}

variable "subnet_numbers" {
  description = "List of 8-bit numbers of subnets of base_cidr_block that should be granted access."
  default = [1, 2, 3]
}

data "aws_vpc" "example" {
  id = var.vpc_id
}

resource "aws_security_group" "example" {
  name        = "friendly_subnets"
  description = "Allows access from friendly subnets"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = -1

    cidr_blocks = [
      for num in var.subnet_numbers:
      cidrsubnet(data.aws_vpc.example.cidr_block, 8, num)
    ]
  }
}
```

So, for each subnet number, use the `cidrsubnet()` function to generate a corresponding CIDR. The VPC's CIDR prefix is 10.1.0.0/16, it would yield `["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]`.

Since this was not really possible in Terraform 0.11 and earlier without a lot of violating DRY, it can immediately be seen that the `for` expressions are a big leap forward for the Terraform community.

### Iteration VI: Dynamic nested blocks

#### Blocks and nested blocks

The second big improvement in Terraform 0.12 is the `for_each` expression for _dynamic nested blocks_, which I'll get to shortly. Firstly, however, I need to back track a little, and mention what _blocks_ and _nested blocks_ are.

##### Blocks

A _block_ in Terraform is similar to blocks in other languages e.g. Bash, Perl, Ruby, Puppet. All of these allow blocks of code to be defined using `{ ... }` notation. In Terraform, a block is:

```js
resource "aws_security_group" "vault" {
  // resource attributes declared inside the block.
}
```

##### Nested blocks

A _nested block_ meanwhile is a block defined inside a block:

```js
resource "aws_security_group" "vault" {
  // other config.

  ingress {
    // this is a nested block. Ingress configuration in here.
  }
}
```

#### Dynamic block types

Which brings me to _dynamic nested blocks_. Terraform 0.12 has introduced the dynamic nested block, although no dynamic top-scope block. And it is in the context of the dynamic nested block that `for_each` expressions can be used. (Although, as mentioned below, they will eventually be available to resources, data blocks and modules too).

A dynamic block looks like this:

```js
resource "aws_security_group" "vault" {
  // other config.

  dynamic "ingress" {
    // this is a dynamic nested block. A for_each goes in here.
  }
}
```

#### For_each expressions

Now to the `for_each` expression.

From a grammar point of view, Terraform's `for_each` is a little surprising. In languages that have both a [`for`](https://en.wikipedia.org/wiki/For_loop) and a [`foreach`](https://en.wikipedia.org/wiki/Foreach_loop) loop, the for loop generally allows iteration over ranges of numbers or arbitrary conditions, whereas a foreach loop is specifically for iterating over collections such as arrays and maps.

In Terraform, however, the `for` and `for_each` expressions are both foreach loops in this sense as both iterate over collections.

The difference is that `for` _expressions_ generate values that can be assigned to resource attributes whereas `for_each` expressions generate a nested block of code instead.

As mentioned, the `for_each` (at the time of writing) can only be used in a dynamic nested block. It looks like this:

```js
resource "aws_security_group" "vault" {
  // other config.

  dynamic "ingress" {
    for_each = some_array
    // code to generate for each array element of the collection.
  }
}
```

#### Example 11: A dynamic nested ingress block

Here is a full example:

```js
variable "ingress_ports" {
  type        = list(number)
  description = "list of ingress ports"
  default     = [8200, 8201]
}

resource "aws_security_group" "vault" {
  name        = "vault"
  description = "Ingress for Vault"
  vpc_id      = aws_vpc.my_vpc.id

  dynamic "ingress" {
    for_each = var.ingress_ports
    content {
      from_port = ingress.value
      to_port   = ingress.value
      protocol  = "tcp"
    }
  }
}
```

This generates an `ingress` block for each port in the `ingress_ports` list.

#### Iterators

As can be seen in the examples above, the temporary variable used as the loop's iterator takes its name by default from the label of the dynamic block. In this example, I iterated over a list named `ingress_ports` in the context of a dynamic `ingress` block, and each element of the list was addressed as `ingress.value`. Since there is no necessary relationship between the name of the list and the label of the block, the code could become unreadable.

To avoid this, it is possible to name the temporary variable something else by using the `iterator` argument.

#### Example 12: Example with iterator

Rewriting the previous example with an iterator:

```js
variable "ingress_ports" {
  type        = list(number)
  description = "list of ingress ports"
  default     = [8200, 8201]
}

resource "aws_security_group" "vault" {
  name        = "vault"
  description = "Ingress for Vault"
  vpc_id      = aws_vpc.my_vpc.id

  dynamic "ingress" {
    for_each = var.ingress_ports
    iterator = "ingress_port"
    content {
      from_port = ingress_port.value
      to_port   = ingress_port.value
      protocol  = "tcp"
    }
  }
}
```

#### Example 13: Combining for and for_each

Having now covered off `for` and `for_each` it is useful to see how they can be combined. This example is copied from the [Terraform 0.12 Preview](https://www.hashicorp.com/blog/hashicorp-terraform-0-12-preview-for-and-for-each):

```js
variable "subnets" {
  default = [
    {
      name   = "a"
      number = 1
    },
    {
      name   = "b"
      number = 2
    },
    {
      name   = "c"
      number = 3
    },
  ]
}

locals {
  base_cidr_block = "10.0.0.0/16"
}

resource "azurerm_virtual_network" "example" {
  name                = "example-network"
  resource_group_name = azurerm_resource_group.test.name
  address_space       = [local.base_cidr_block]
  location            = "West US"

  dynamic "subnet" {
    for_each = [for s in subnets: {
      name   = s.name
      prefix = cidrsubnet(local.base_cidr_block, 4, s.number)
    }]

    content {
      name           = subnet.value.name
      address_prefix = subnet.value.prefix
    }
  }
}
```

As can be seen, a `for` expression transforms a list of maps into a different list of maps, and then each element of that list of maps is made available in the `content` block.

#### Best practices

I joked in Part II at the way attitudes changed in the Puppet community, from the early days, when it was thought that iteration should not ever be required in a declarative language - indeed, some argued against adding iteration in Puppet! - to the present day, where iteration is recommended in the style guide in preference to the earlier, declarative grammar.

All the same, at this time, Hashicorp's advice is to avoid dynamic nested blocks and the `for_each` where possible:

> We still recommend that you avoid writing overly-abstract, dynamic configurations as a general rule. These dynamic features can be useful when creating reusable modules, but over-use of dynamic behavior will hurt readability and maintainability. Explicit is better than implicit, and direct is better than indirect.

And in the [docs](https://www.terraform.io/docs/configuration/expressions.html):

> Overuse of `dynamic` blocks can make configuration hard to read and maintain, so we recommend using them only when you need to hide details in order to build a clean user interface for a re-usable module. Always write nested blocks out literally where possible.

### Iteration VII: Resource for_each (coming soon)

Hashicorp tell us in their preview post that the groundwork has been laid for supporting `for_each` inside resource and data blocks as a way of creating resources for each element in a list or map. Apparently, it will look something like this:

```js
resource "aws_subnet" "example" {
  for_each = var.subnet_numbers

  vpc_id            = aws_vpc.example.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(aws_vpc.example.cidr_block, 8, each.value)
}
```

A new object `each` with attributes `each.key` and `each.value` will allow access to the iterator in the `for_each` expression. Also, when this happens, the `count` and `count.index` methods of iteration will no longer be recommended for most cases.

### Iteration VIII: Module count and for_each (coming soon)

Likewise, a future release of Terraform will provide a `count` and `for_each` for modules. Although,

> This feature is particularly complicated to implement within Terraform's existing architecture, so some more work will certainly be required before we can support this. To avoid further breaking changes in later releases, 0.12 will reserve the module input variable names `count` and `for_each` in preparation for the completion of this feature.

Exciting stuff.

## Summary

That completes the third part of my series. I have looked at `for` expressions in Terraform 0.12 and noted that these are modeled on the list and dict comprehension from Python and shown some examples relating the two. I also showed how the `for_each` expression can be used to generate _dynamic nested blocks_, and briefly mentioned that a similar, but not identical, `for_each` grammar is coming soon for resources, data blocks and modules.

Stay tuned for Part IV of this series, where I amazingly continue with iteration in Terraform and discuss the splat operator both in Terraform 0.11 and the _generalised splat operator_ of Terraform 0.12.

## See also

- Martin Atkins, Jul 2018, [HashiCorp Terraform 0.12 Preview: For and For-Each](https://www.hashicorp.com/blog/hashicorp-terraform-0-12-preview-for-and-for-each).
- Documentation in the Terraform source code on [dynamic blocks](https://github.com/hashicorp/terraform/tree/master/vendor/github.com/hashicorp/hcl2/ext/dynblock).
- Map & list comprehensions feature request, 24 Aug 2016, [Issue #8439](https://github.com/hashicorp/terraform/issues/8439), where the Python list & map comprehension grammar was first requested.
- For_each feature request in GitHub Issues, 24 Jan 2018, [Issue #17179](https://github.com/hashicorp/terraform/issues/17179), where some of the motivations of the `for_each` feature is discussed.

---

<sup>1</sup> Note that since I began this series, Terraform 0.12 was in beta2 stage. At the time of writing this post, the current version is Terraform 0.12.1.<br>
<sup>2</sup> The numbering in this post continues the numbering in the previous post, so that these two posts (and the next one) can be read together as a complete treatment of iteration in Terraform 0.12.
