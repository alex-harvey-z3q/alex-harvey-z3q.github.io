---
layout: post
title: "Adventures in the Terraform DSL, Part IV: All about splats"
date: 2019-06-08
author: Alex Harvey
tags: terraform
---

In this Part IV of my adventures in the Terraform DSL, I finish my investigation of Terraform's iteration features and discuss the splat expression in detail.

- ToC
{:toc}

## Introduction

In [Part I](https://alexharv074.github.io/2019/05/12/adventures-in-the-terraform-dsl-part-i-structured-data.html), I looked at addressing data in both Terraform 0.11 and 0.12-beta2 and I briefly mentioned _splat_ expressions in Terraform 0.11 and said I would return them in Part II on iteration. However, iteration in Terraform turned out to be such a large topic that Part II became Parts II and III and I still haven't honoured my promise to discuss the splat!

That's what this post is about: the splat expression in Terraform 0.11 and 0.12.1.

## A brief history of splats<sup>1</sup>

It was Donald Knuth who said, "Programs are meant to be read by humans and only incidentally for computers to execute." And anyone who knows me knows that I take naming things seriously indeed! So, naturally, the first thing I wanted to understand is this:

Why is Terraform's "splat" called a "splat"?

### Splats in Ruby<sup>2</sup>

As far as I can tell, the idea of the _splat operator_ (`*`), at least as far as that name for that symbol is concerned, originated in Ruby. There, the splat is an implicit form of iteration for unpacking arrays. If I write this in Ruby:

```ruby
a, *b = [1, 2, 3, 4, 5]
```

Then `a` will be assigned the value 1 and `b` will be assigned the array `[2,3,4,5]`. Splat b is like saying, "just give me the rest as an array". You can have the splat on the right hand side too. If I write:

```ruby
a = [1, 2]
x, y, z = *a, 3
```

Then `x` = 1, `y` = 2 and `z` = 3.

But the splat is often used in method arguments too. This code here:

```ruby
def foo(bar, *baz)
  puts "#{bar}, #{baz}"
end

foo(1,2,3,4,5)
```

Emits:

```text
1, [2, 3, 4, 5]
```

And that's not the end of the story for splats in Ruby but it's more than enough in a post about Terraform!

### Splats in Puppet

On the subject of Terraform-like DSLs, Puppet also inherited Ruby's splat operator. If I write this in Puppet:

```js
$a = [1, 2]
[$x, $y, $z] = [*$a, 3]
notice($x, $y, $z)
```

I can see that it behaves similarly to the Ruby:

```text
▶ puppet apply test.pp
Notice: Scope(Class[main]): 1 2 3
```

### Wildcard expressions in JMESpath

And while not called a "splat", I also want to mention the _wildcard expression_ in JMESpath, which is used in the AWS CLI. In JMESpath, the notation `[*]` means all elements in a list.

Here is an example. Given this JSON:

```json
{
  "KeyPairs": [
    {
      "KeyName": "alex",
      "KeyFingerprint": "af:ef:61:07:42:f8:33:0a:e4:d6:89:cb:2b:bb:3a:2e:21:fb:16:19"
    },
    {
      "KeyName": "default",
      "KeyFingerprint": "70:e2:fa:b1:97:e3:68:5f:6a:63:93:17:09:5a:43:29:60:94:53:ab"
    }
  ]
}
```

I can obtain the key names as a list using the [jp](https://github.com/jmespath/jp) JMESpath CLI tool:

```text
▶ jp 'KeyPairs[*].KeyName' < JSON
[
  "alex",
  "default"
]
```

I will return to JMESpath throughout this post.

## Splats in Terraform

### Splat syntax in Terraform 0.11

#### The random_id example again

So much for splats. Now back to Terraform. So, it turns out that Terraform's splat isn't like Ruby's (or Puppet's) splat at all other than in the name and the asterisk (`*`) symbol and the implicit iteration over lists, although - as I will show - it is quite like the wildcard expression in JMESpath.

Here is the example Terraform code that I introduced in Part I, which shows the splat syntax and a resource with a `count` meta parameter:

```js
resource "random_id" "tf_bucket_id" {
  byte_length = 2
  count = 3
}

output "random_id" {
  value = "${random_id.tf_bucket_id.*.id}"
}
```

If I apply that with Terraform 0.11 I get:

```text
random_id = [
    tsA,
    qKs,
    6_0
]
```

Note that the Terraform 0.12 docs now refer to this as the _legacy (attribute-only) splat expression_, where the splat is indicated by the sequence `.*`. It is considered to be deprecated:

> An older variant of the splat expression is available for compatibility with code written in older versions of the Terraform language. This is a less useful version of the splat expression, and should be avoided in new configurations.

#### Comparison to JMESpath

And that syntax `random_id.tf_bucket_id.*.id` is to Terraform 0.11 as `random_id.tf_bucket_id[*].id` is to Terraform 0.12 and also to JMESpath. In fact, it's fun to show this. Given a JSON document with the following content:

```json
{
  "random_id": {
    "tf_bucket_id": [
      {
        "id": "tsA"
      },
      {
        "id": "qKs"
      },
      {
        "id": "6_0"
      }
    ]
  }
}
```

I can use the JMESpath CLI tool to get the IDs this way:

```text
▶ jp 'random_id.tf_bucket_id[*].id' < JSON
[
  "tsA",
  "qKs",
  "6_0"
]
```

#### General splat in 0.11?

Returning to Terraform 0.11, I can surely do this too right?

```js
locals {
  random_id = {
    tf_bucket_id = [
      {
        id = "tsA"
      },
      {
        id = "qKs"
      },
      {
        id = "6_0"
      }
    ]
  }
}

output "random_id" {
  value = "${local.random_id.tf_bucket_id.*.id}"
}
```

Well no. If I apply that I get:

```text
Error: Error loading /Users/alexharvey/git/home/terraform-test/test.tf:
  Error reading config for output random_id: Can't use dot (.) attribute
  access in local.random_id.tf_bucket_id.*.id; use square bracket indexing in:

${local.random_id.tf_bucket_id.*.id}
```

Use square bracket in indexing you say? So I try this:

```js
output "random_id" {
  value = "${local.random_id.tf_bucket_id[*].id}"
}
```

And I get:

```text
Error: Error loading /Users/alexharvey/git/home/terraform-test/test.tf:
  Error reading config for output random_id:
  parse error at 1:32: expected expression but found "*"
```

Hmm.

#### Reading the docs

Returning to the Terraform 0.11 [docs](https://www.terraform.io/docs/configuration-0-11/interpolation.html), it is documented that:

> If the resource has a `count` attribute set, you can access individual attributes with a zero-based index, such as `${aws_instance.web.0.id}`. You can also use the splat syntax to get a list of all the attributes: `${aws_instance.web.*.id}`.

Note the key there is _if_ (and only if) a resource has a `count` attribute set.

### Generalised splat operator in Terraform 0.12

#### JMESpath in Terraform 0.12

Terraform 0.12 has fixed all this and provided a splat grammar that is just like JMESpath. Turning my code to 0.12:

```js
locals {
  random_id = {
    tf_bucket_id = [
      {
        id = "tsA"
      },
      {
        id = "qKs"
      },
      {
        id = "6_0"
      }
    ]
  }
}

output "random_id" {
  value = local.random_id.tf_bucket_id[*].id
}
```

I apply that and it works fine:

```text
random_id = [
  "tsA",
  "qKs",
  "6_0",
]
```

Great.

#### Deeply nested data

What if I have this one:

```json
{
  "foo": [
    {
      "bar": [
        {
          "baz": 19
        },
        {
          "baz": 14
        },
        {
          "baz": 10
        }
      ]
    }
  ]
}
```

And I want all the `baz` keys as an array? In JMESpath, I can do this:

```text
▶ jp 'foo[*].bar[*].baz' < JSON
[
  [
    19,
    14,
    10
  ]
]
```

And in Terraform 0.12:

```js
locals {
  foo = [
    {
      bar = [
        {
          baz = 19
        },
        {
          baz = 14
        },
        {
          baz = 10
        }
      ]
    }
  ]
}

output "output" {
  value = local.foo[*].bar[*].baz
}
```

I get:

```text
▶ terraform012 apply

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:
[
  [
    19,
    14,
    10
  ]
]
```

And quite honestly I think that is pretty cool.

#### Relationship to for expressions

A final quick note that Terraform's docs in 0.12 describes the splat expression as:

> ... a more concise way to express a common operation that could otherwise be performed with a for expression.

```js
var.list[*].id
```

Is equivalent to:

```js
[for o in var.list: o.id]
```

And as noted in the docs an expression like:

```js
var.list[*].interfaces[0].name
```

Could also be written as:

```js
[for o in var.list : o.interfaces[0].name]
```

My feeling is that the for expression is to be preferred where possible and it probably is more readable.

## Summary

And that's it for Part IV, and that's it for my posts on iteration in Terraform too. In this post, I had a fun look at the history of splat operators in other languages, and noted that Terraform's splat really isn't that related to Ruby's splat and in the evolved Terraform 0.12 version it is now much more like the wildcard expressions in JMESpath. And I looked at a bunch of examples along the way.

Coming soon is Part V, where I will look at Terraform's conditional logic.

## See also

- Martin Atkins, Jul 19 2018, [HashiCorp Terraform 0.12 Preview: Generalized Splat Operator](https://www.hashicorp.com/blog/terraform-0-12-generalized-splat-operator).

---

<sup>1</sup> The reader can totally skip this section if they want to!<br>
<sup>2</sup> For the most part, this all works in Python too, although it isn't called "splat" in Python.

