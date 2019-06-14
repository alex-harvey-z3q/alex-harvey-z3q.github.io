---
layout: post
title: "Adventures in the Terraform DSL, Part V: Conditional logic"
date: 2019-06-09
author: Alex Harvey
tags: terraform
---

In this post, I look at the evolution of conditional logic and truthiness in Terraform.

- ToC
{:toc}

## Introduction

Conditional logic has always been a pain point in Terraform, as the titles of some of the references below reveal.

In this Part V of my blog series, I look into all of this. I look at "truthiness" in Terraform, and follow the evolution of conditional logic in the Terraform DSL from the earliest days, through introduction of the ternary operator in Terraform 0.8, to the recent improvements in Terraform 0.12.

## Conditional logic in Terraform 0.7 and earlier

### Conditional logic I: A count of 0 or 1 resources

#### Count, true and false

In the dark days of early Terraform, the Terraform DSL had no conditional logic at all. And, although the underlying HashiCorp Configuration Language (HCL) converted the bare words `true` and `false` into the strings `1` and `0` respectively, it meant nothing to Terraform itself. It had no concept of `true` and `false`.

Instead, Terraform had - as seen throughout this blog series so far - a `count` meta parameter. And there's one bit I haven't mentioned about `count` yet, which is what happens if you set `count = 0`? Well, it causes Terraform to simply not create that resource - or, if it is already created, it causes Terraform to destroy it again.

And until Terraform 0.8 was released in December 2016, that was Terraform's "if" statement! 

#### Example 1: Conditionally create a random_id

I'll dive right in and provide an example. Using a Terraform 0.7 binary, I can demonstrate this early form of conditional logic. I create a file `test.tf` as usual:

```js
variable "create_id" {
  default = true
}

resource "random_id" "test" {
  count = "${var.create_id}" // Remember that Terraform converts
  byte_length = 2            // true into "1".
}

output "create_id" {
  value = "${var.create_id}"
}
```

And then I apply that and I see:

```text
▶ terraform0713 apply
random_id.test: Creating...
  b64:         "" => "<computed>"
  b64_std:     "" => "<computed>"
  b64_url:     "" => "<computed>"
  byte_length: "" => "2"
  dec:         "" => "<computed>"
  hex:         "" => "<computed>"
random_id.test: Creation complete

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

The state of your infrastructure has been saved to the path
below. This state is required to modify and destroy your
infrastructure, so keep it safe. To inspect the complete state
use the `terraform show` command.

State path: terraform.tfstate

Outputs:

create_id = 1
```

So I used a default value of `true` that was converted into the string `1` in the `count` meta parameter and a `random_id` was created. And if I now change it to `false`:

```js
variable "create_id" {
  default = false  // I just changed this line.
}
...
```

And apply again:

```text
▶ terraform0713 apply
random_id.test: Refreshing state... (ID: Yt4)
random_id.test: Destroying...
random_id.test: Destruction complete

Apply complete! Resources: 0 added, 0 changed, 1 destroyed.

Outputs:

create_id = 0
```

The `random_id` I "created"<sup>1</sup> before is "destroyed" again.

### Conditional logic II: The replace function

#### The replace function

Having a `1` and `0` worked well in the 60s and 70s but what if you want to test a string? What if I want to say, "if instance_type begins with t, do X; else, do Y"?  I mentioned already that Terraform 0.7 did not understand `true` and `false` at all so naturally it had no comparison operators either!

This all changed with what I'm going to call "the replace hack". I believe it originated in Yevgeniy Brikman's [blog series](https://blog.gruntwork.io/terraform-tips-tricks-loops-if-statements-and-gotchas-f739bbae55f9) and book, _Terraform: Up and Running_.

Terraform 0.4 introduced the `replace()` function, which took 3 parameters:

> `replace(string, search, replace)` - Does a search and replace on the given string. All instances of `search` are replaced with the value of `replace`. If `search` is wrapped in forward slashes, it is treated as a regular expression. If using a regular expression, replace can reference subcaptures in the regular expression by using `$n` where `n` is the index or name of the subcapture. If using a regular expression, the syntax conforms to the re2 regular expression syntax.

And what else does a regular expression do? It compares strings!

#### Example 2: Add a metrics alarm if instance_type begins with "t"

This led to the abuse of the replace function to do string comparisons in Terraform. I hope it didn't happen _too_ much and I really hope this code isn't still out there, but just in case, here is an example taken from the aforementioned blog post.

Imagine I want to add a CPU alarm but only on my AWS t-class EC2 instances. Consider this code:

```text
variable "instance_type" {
  default = "t2.nano"
}

resource "aws_cloudwatch_metric_alarm" "low_cpu_credit_balance" {

  count = "${replace(replace(var.instance_type,
    "/^[^t].*/", "0"), "/^t.*/", "1")}"

  metric_name = "CPUCreditBalance"
  dimensions = {
    InstanceId = "${aws_instance.example.id}"
  }
  threshold = 10
  unit = "Count"
  comparison_operator = "LessThanThreshold"
}
```

Note the nested calls to the `replace()` function!

The inner call is:

```text
replace(var.instance_type, "/^[^t].*/", "0")
```

It says, if the instance_type does _not_ begin with `"t"`, replace the whole string with `"0"`. Otherwise, fall through to the outer call to `replace()`.

Then, the outer call is:

```text
replace(<INNER>, "/^t.*$/", "1")
```

This one says, if the instance_type _does_ begin with `"t"`, replace the whole string with `"1"`.

So, there are two ways out: the inner call replaces the string with `"0"`, or the outer one then replaces it with `"1"`.

Ones and zeros!

### Conditional logic III: Maths interpolations for if-else

#### Simple maths in interpolations

Well Yevgeniy Brikman calls it an "if-else" although I would call it an "exclusive-or" (XOR). It turns out that Terraform allows simple maths to be performed in interpolations. The supported operations are:

The supported operations are:

- Add (`+`), Subtract (`-`), Multiply (`*`), and Divide (`/`) for float types
- Add (`+`), Subtract (`-`), Multiply (`*`), Divide (`/`), and Modulo (`%`) for integer types

#### Example 3: Simple maths

Consider this simple piece of Terraform 0.7 code:

```js
output "math" {
  value = "${2 * (4 + 3) * 3}"
}
```

Apply that and you will see:

```text
Outputs:

math = 42
```

#### Example 4: The if-else

If `true` equals `1` and `false` equals `0`, then `1 - true = 1 - 1 = 0 = false`. (Again, I call this an XOR.) Thus, we can have an if-else this way:

```js
variable "create_id" {
  type = "string"
  default = true
}

resource "random_id" "id1" {
  count = "${var.create_id}"
  byte_length = 2
}

resource "random_id" "id2" {
  count = "${1 - var.create_id}"
  byte_length = 2
}
```

This could be read as saying, if `create_id`, then create `id1`, else create `id2`. Testing it:

```text
▶ terraform0713 apply
random_id.id1: Creating...
  b64:         "" => "<computed>"
  b64_std:     "" => "<computed>"
  b64_url:     "" => "<computed>"
  byte_length: "" => "2"
  dec:         "" => "<computed>"
  hex:         "" => "<computed>"
random_id.id1: Creation complete
```

And then I change `create_id` to `false` and try again and see:

```text
▶ terraform0713 apply
random_id.id1: Refreshing state... (ID: X5s)
random_id.id1: Destroying...
random_id.id1: Destruction complete
random_id.id2: Creating...
  b64:         "" => "<computed>"
  b64_std:     "" => "<computed>"
  b64_url:     "" => "<computed>"
  byte_length: "" => "2"
  dec:         "" => "<computed>"
  hex:         "" => "<computed>"
random_id.id2: Creation complete
```

## Conditional logic in Terraform 0.8 to 0.11

### Conditional logic IV: Ternary and comparison operators

Terraform 0.8 introduced the ternary operator in interpolations and there was much rejoicing. The ternary had first appeared in the C programming language and has made its way into many modern languages like Ruby, Perl, Golang etc. The ternary has the form:

```text
condition ? true_val : false_val
```

To support the ternary, Terraform 0.8 also for the first time introduced comparison operators. These are (they haven't changed):

- Is equal to: `==`
- Is not equal to: `!=`
- Numerical comparison: `>`, `<`, `>=`, `<=`
- Booleans: `&&`, `||`, and unary `!`.

I think these are all self-explanatory so I'll move on.

#### Truthiness in Terraform 0.8 to 0.11

Considering Terraform now has comparison operators it makes sense to next look at "truthiness" in Terraform, that is, what else Terraform considers to be true and false in a boolean context. The following table summarises truthiness in Terraform 0.8 to 0.11:

|Value|Truthiness|
|=====|=============|
|"1"|truthy|
|"0"|falsey|
|true|truthy|
|false|falsey|
|"true"|truthy|
|"false"|falsey|

Meanwhile other values like integers, lists, maps and other strings are all neither truthy nor falsey and considered by Terraform to be just "not of type bool" and thus cannot be used in a boolean context (and, remember, in Terraform, when I say, "in a boolean context", there is only one boolean context, namely the condition in the ternary, so that's what I mean).

#### Comparison operators in Terraform 0.8 to 0.11

When comparing values with true or false, it is necessary to remember that Terraform converts `true` and `false` into the strings `1` and `0` respectively. As a result, comparing values with `true` or `false` can be surprising.

The comparison operators in the following table are all intuitive enough:

|Value|Truthiness|
|=====|==========|
|true == true|true|
|false == false|true|
|"x" == "x"|true|
|"x" == "y"|false|
|!true|false|
|!!true|true|

But these ones may be surprising:

|Value|Truthiness|
|=====|==========|
|true == "true"|false|
|"1" == true|false|
|"0" == false|false|
|false == "false"|false|

To make matters worse (at least I think it has made matters worse), some but not all of this surprising behaviour changed in Terraform 0.12! A full table appears later in the post.

Kevin Gillette has given the following recommendations in his blog post [_Terraform Boolean Evaluation: Unexpected implementation semantics_](https://medium.com/@xtg/terraform-boolean-evaluation-b866b528e90b):

> 1. Never use the `==` or `!=` operators to compare Boolean values, since these perform string comparisons, and cannot handle the multiple possible synonyms of true and false. For example, instead of:
> ```
> var.x == true ? var.y : var.z
> ```
> simply use:
> ```
> var.x ? var.y : var.z
> ```
>
> 2. Normalize your modules’ Boolean outputs with double negation:
> ```
> output "out" { value = "${!!var.in}" }
> ```
> This will result in module output values that are consistently either "true" or "false".

Well I agree with the first of these recommendations whereas I remain undecided on the second. I guess it's up to others to decide if the risk of surprising behaviour in the code is worth the loss of readability involved in adding double negations everywhere.

#### Example 5: The if-else again with the ternary

Anyway, after all that it is time to try out the ternary. Here, I rewrite the above "if-else" code for the random_id using Terraform 0.8's ternary operator:

```js
variable "create_id" {
  default = true
}

resource "random_id" "id1" {
  count = "${var.create_id ? "1" : "0"}"
  byte_length = 2
}

resource "random_id" "id2" {
count = "${var.create_id ? "0" : "1"}"
  byte_length = 2
}
```

And then I apply it with Terraform 0.8:

```text
▶ terraform088 apply
random_id.id1: Creating...
  b64:         "" => "<computed>"
  b64_std:     "" => "<computed>"
  b64_url:     "" => "<computed>"
  byte_length: "" => "2"
  dec:         "" => "<computed>"
  hex:         "" => "<computed>"
random_id.id1: Creation complete
```

And it looks good and then I change the default value of `create_id` to `false` and apply it again and:

```text
▶ terraform088 apply
random_id.id1: Refreshing state... (ID: uS4)
random_id.id1: Destroying...
random_id.id1: Destruction complete
random_id.id2: Creating...
  b64:         "" => "<computed>"
  b64_std:     "" => "<computed>"
  b64_url:     "" => "<computed>"
  byte_length: "" => "2"
  dec:         "" => "<computed>"
  hex:         "" => "<computed>"
random_id.id2: Creation complete
```

And voila, there you have an "if-else". Or sort of.

#### Limitations of the Terraform 0.8 ternary

##### Maps and lists not supported

As noted in [Issue #12453](https://github.com/hashicorp/terraform/issues/12453), the Terraform 0.8 ternary statement worked only on primitive types and not lists and maps. For example, you probably would think I could do this:

```js
locals {
  is_foo = true
}

output "test" {
  value = ["${local.is_foo ? list("foo","bar","baz") : list()}"]
}
```

But if I apply that with Terraform 0.11 (the locals weren't introduced until 0.10.3):

```text
▶ terraform011 apply

Error: output.test: At column 3, line 1: conditional operator cannot be used with list values in:

${local.is_foo ? list("foo","bar","baz") : list()}
```

##### Both branches of the conditional evaluated

Another big gotcha, as noted in [Issue #15605](https://github.com/hashicorp/terraform/issues/15605), is that both branches of the conditional would be always evaluated. This would lead to code like this failing unexpectedly:

```js
variable "file_path" {
  default = ""
}

data "template_file" "template" {
  vars = {
    file_contents = "${length(var.file_path) > 0 ? file("${var.file_path}") : ""}"
  }
}
```

Applying that leads to:

```text
▶ terraform011 apply

Error: data.template_file.template: 1 error(s) occurred:

* data.template_file.template: file: open : no such file or directory in:

${length(var.file_path) > 0 ? file("${var.file_path}") : ""}
```

To workaround that, you would just have to find a way of rewriting so that both branches could be safely evaluted. For instance:

```js
variable "file_path" {
  default = "/dev/null"
}

data "template_file" "template" {
  vars = {
    file_contents = "${var.file_path != "/dev/null" ? file("${var.file_path}") : ""}"
  }
}
```

Not ideal.

## Conditional logic in Terraform 0.12

### Conditional expression

Note that ternary operators are now referred to as _conditional expressions_ in the Terraform 0.12 docs. And thanks to Terraform 0.12's first-class expressions, they have a cleaner syntax too. And both of the above issues have been resolved.

Thus, it is now possible to use lists and maps in a ternary like this:

```js
locals {
  is_foo = true
}

output "test" {
  value = (local.is_foo ? list("foo","bar","baz") : list())
}
```

And there the branches of the conditional expression are only evaluated as required. So this also works:

```js
variable "file_path" {
  default = ""
}

data "template_file" "template" {
  vars = {
    file_contents = (length(var.file_path) > 0 ? file(var.file_path) : "")
  }
}
```

So, it is more readable, more functional and not broken. Some big wins here.

### Conditional logic V: Conditionally set an attribute

Another big problem in Terraform 0.11 and earlier was the lack any equivalent of Puppet's `undef` value, which made it impossible to conditionally set attributes on resources while otherwise allowing the resource's default behaviour for that attribute. This was raised in Terraform [Issue #17968](https://github.com/hashicorp/terraform/issues/17968). 

In Puppet, it has always been possible to write code like this:

```js
class user (
  $uid = undef,
  )
  user { 'myuser':
    ensure => present,
    uid    => $uid, // Use the provider's default behaviour
  }                 // if $uid is not set.
}
```

This is now possible in Terraform 0.12 too with the introduction of the `null` value, which is just like Puppet's `undef`. Thus, it is now possible to do something like this:

```js
variable "private_ip" {
  type    = string
  default = null
}

resource "aws_instance" "example" {
  ami           = "ami-08589eca6dcc9b39c"
  instance_type = "t2.micro"
  key_name      = "default"
  private_ip    = var.private_ip // Use provider's default behaviour
}                                // if var.private_ip not set.
```

And considering how many times I have needed to do that in Puppet, I think that's another big win for Terraform!

### Truthiness in Terraform 0.12

#### Testing truthiness

I was surprised to discover while testing Terraform's truthiness in its various versions that `true` == `"true"` in earlier versions of Terraform, whereas `true` != `"true"` in Terraform 0.12. The 0.12 [docs](https://www.terraform.io/docs/configuration/expressions.html) do say that:

> Terraform automatically converts number and bool values to strings when needed. It also converts strings to numbers or bools, as long as the string contains a valid representation of a number or bool value.
>
> `true` converts to `"true"`, and vice-versa<br>
> `false` converts to `"false"`, and vice-versa<br>
> 15 converts to "15", and vice-versa

In any case, I put together a table of comparisons to show evaluations of truth and truthiness in Terraform 0.11 and 0.12.

(Note that the code that generated this table is available [here](https://gist.github.com/alexharv074/123d5bfdce3eaf4e0dccc760669bb0b0).)

When reading this table, note that the `-` means a syntax error would be seen in a boolean context (the actual errors seen change from version to version). And the highlighted lines show the behaviour that changed from 0.11 to 0.12.

|Value|Terraform 0.11|Terraform 0.12|
|=====|=============|==============|
|"1"|truthy|truthy|
|"0"|falsey|falsey|
|true|true|true|
|false|false|false|
|"true"|truthy|truthy|
|"false"|falsey|falsey|
|1|-|-|
|0|-|-|
|"2"|-|-|
|"hello"|-|-|
|""|-|-|
|true == true|true|true|
|false == false|true|true|
|__true == "true"__|__true__|__false__|
|__false == "false"__|__true__|__false__|
|__true != "true"__|__false__|__true__|
|__false != "false"__|__false__|__true__|
|"1" == true|false|false|
|"0" == false|false|false|
|"1" == "true"|false|false|
|"0" == false|false|false|
|"x" == "x"|true|true|
|"x" == "y"|false|false|
|!true|false|false|
|!false|true|true|
|!!true|true|true|
|!!false|false|false|

#### The tobool function

Terraform 0.12 has also introduced a number of type conversion functions, including the [`tobool()`](https://www.terraform.io/docs/configuration/functions/tobool.html) function, whose purpose is convert `"true"` and `"false"` to `true` and `false` respectively.

The motivation for the feature is explained in the [Git log](https://github.com/hashicorp/terraform/commit/b85bb09fb46f828b60562a12237b6e4d75d3d3f5):

> conversions are useful in a few specialized cases:
>
> - When defining output values for a reusable module, it may be desirable
>   to force a "cleaner" output type than would naturally arise from a
>   computation, such as forcing a string containing digits into a number.
> - Our 0.12upgrade mechanism will use some of these to replace use of the
>   undocumented, hidden type conversion functions in HIL, and force
>   particular type interpretations in some tricky cases.
> - We've found that type conversion functions can be useful as _temporary_
>   workarounds for bugs in Terraform and in providers where implicit type
>   conversion isn't working correctly or a type constraint isn't specified
>   precisely enough for the automatic conversion behavior.

So takeaway of all this for me is that `tobool()` shouldn't normally be used at all, but it's good to know that it's there.

## Summary and concluding thoughts

As far as I can tell, I have now covered all of Terraform's conditional logic features. Migrants from high-level programming languages and also those from the comparable Puppet DSL (or Chef's Ruby DSL) might find that Terraform's support for conditional logic remains inadequate. While many languages have a ternary operator like Terraform, they are used infrequently in those languages compared to if/else. For example, I just counted ~ 11,000 if statements in the Puppet source code (i.e. a mature Ruby project) compared to only 1,000 ternary statements.

Personally, I would like a real if/elsif/else and I wouldn't turn down a case or switch statement either! Of course, it may be that the brilliant Martin Atkins and his team at HashiCorp are hemmed in by Terraform's earliest design choices and turning Terraform into a real language is harder than I realise.

In any case, I hope that this post has been helpful to those learning Terraform 0.12 and also to those maintaining earlier Terraforms.

I have covered the evolution of conditional logic in Terraform from the earliest versions where a count of 0 or 1 resources was Terraform's conditional logic through the evolution of the ternary operator in 0.8 to 0.11 and the recent enhancements in 0.12. I also have had a quite detailed look at truthiness in Terraform.

The next part of this series should be interesting, because I am going to do a proof of concept of real unit testing in Terraform 0.12 using an unmerged feature branch that Martin Atkins made for me! It will be the first of its kind. Stay tuned.

## See also

- Dave Konopka, Mar 7 2016, [Terraform conditionals. Sort of](http://www.davekonopka.com/2016/terraform-conditionals.html).
- Kevin Gillette, May 30, 2018, [Terraform Boolean Evaluation: Unexpected implementation semantics](https://medium.com/@xtg/terraform-boolean-evaluation-b866b528e90b).
- Martin Atkins, Jul 26, 2018, [HashiCorp Terraform 0.12 Preview: Conditional Operator Improvements and Conditionally Omitted Arguments](https://www.hashicorp.com/blog/terraform-0-12-conditional-operator-improvements).
- Mitchell Hashimoto, Dec 13, 2016, [HashiCorp Terraform 0.8](https://www.hashicorp.com/blog/terraform-0-8).

---

<sup>1</sup> Of course, the "random_ids" aren't real resources in AWS like EC2 instances, which is the main reason I like using them for testing.<br>
