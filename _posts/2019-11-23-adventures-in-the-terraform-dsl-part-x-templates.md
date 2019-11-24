---
layout: post
title: "Adventures in the Terraform DSL, Part X: Templates"
date: 2019-11-23
author: Alex Harvey
tags: terraform
---

Part X of my blog series on the Terraform DSL, where I look at Terraform's templates.

* ToC
{:toc}

## Introduction

The feature "basic templating" was introduced in Terraform 0.5 in May 2015. And in those days it really was basic. The original intention was to allow results of other resources to be used in scripts to provision other resources. The feature was actually a community contribution by Josh Bleecher Snyder a.k.a [@josharian](https://www.linkedin.com/in/josharian/). The early discussions with Mitchell Hashimoto and others are in [Issue #215](https://github.com/hashicorp/terraform/issues/215).

In this post, I look at the history and usage of this feature, starting with this Terraform 0.5 version, its change to a data source in Terraform 0.7, the Template provider introduced in Terraform 0.10, and then the introduction of the `templatefile()` function and full templating language in Terraform 0.12 and the motivation for the deprecation of the data source.

Along the way I write and test a number of code examples, making this a useful resource if you just want to know how to write a template to do X.

## Templates in Terraform 0.5

### The template_file resource

The [release notes](https://www.hashicorp.com/blog/terraform-0-5/) for Terraform 0.5 noted:

> Terraform 0.5 has support for rendering templates as inputs to other resources. The major use case for this is using the results of other resources to populate scripts to provision other resources.

This was implemented as the `template_file` logical resource. Since I mentioned a lot about logical resources in Part IX of my series, I will simply provide a code example and move on. Here is one:

```js
resource "template_file" "init" {
  filename = "init.tpl"

  vars {
    consul_address = "${aws_instance.consul.private_ip}"
  }
}

resource "aws_instance" "web" {
  // ...

  user_data = "${template_file.init.rendered}"
}
```

Note use there of the exported `rendered` attribute. That, of course, returns the rendered form of the template as text.

### The template language

Actually, there was no template language at all, and this remained the case from Terraform 0.5 through to 0.11. All that you could do in templates was to interpolate strings using the notation `${ ... }`. This is useful to be aware of if you have inherited code written in Terraform 0.11 or earlier!

## Templates in Terraform 0.7

As mentioned in the previous post, Terraform 0.7 replaced the `template_file` resource with a `template_file` data source. And although deprecated, it appears to be (at the time of writing) still more widely used than the Terraform 0.12 `templatefile` function. As mentioned before, the above code would be rewritten (using Terraform 0.12 syntax) as:

```js
data "template_file" "init" {
  filename = "init.tpl"

  vars {
    consul_address = aws_instance.consul.private_ip // TF 0.12 interpolation syntax.
  }
}

resource "aws_instance" "web" {
  // ...

  user_data = template_file.init.rendered
}
```

## Templates in Terraform 0.10: the code split

Terraform 0.10 of course introduced a code split that separated out Terraform's built-in providers into their own code bases. I will look into this more in a future post. The template provider is one of those that moved, and Terraform 0.10 also saw the release of version 0.1.0 of the template provider.

Aside from that, nothing else changed. But be aware that the provider saw three releases during the life of Terraform 0.10, and these were 0.1.0, 0.1.1 and 1.0.0. But none of these releases changed any of the actual functionality. So if you have template provider v0.1.0 or v1.0.0 you have the same code.

## Templates in Terraform 0.12

### A template language

If not for the release of Terraform 0.12 there would be nothing much to write about on Terraform's template language. And to be sure, it is still a simple template language, but it now has some of the basic features that users from say Jinja 2 might expect - including conditionals and loops.

### Deprecatation of provider 2.0.0 in favour of templatefile

The release of Terraform 0.12 saw the simultaneous release of Template provider 2.0.0 while at the same time the template provider was deprecated! The explanation for this is given by Martin Atkins in this comment [here](https://github.com/hashicorp/terraform/issues/16628#issuecomment-510263706):

> Terraform 0.12 now includes [template syntax](https://www.terraform.io/docs/configuration/expressions.html#string-templates) ... This extends the existing interpolation syntax to include conditionals and repetition.
>
> The `template_file` data source has these new capabilities in the template provider versions 2.0.0 an later.
>
> However, because these features are just part of the string template syntax built into the main language, you can just use them inline as part of an argument value if your "template" is relatively simple:
>
> ```js
> user_data <<-EOT
>   %{ for ip in aws_instance.example.*.private_ip ~}
>   server ${ip}
>   %{ endfor ~}
> EOT
> ```
>
> For situations where a template is complex enough to warrant separating it into a separate file, Terraform 0.12 also introduces the function [`templatefile`](https://www.terraform.io/docs/configuration/functions/templatefile.html), which is essentially the template_file data source reworked into a built-in function. We recommend using this new function instead of the template_file data source for all new configurations targeting Terraform 0.12 or later, because that way the function call can appear closer to the context where the template will be used, and also crucially can refer to contextual values like count.index when needed.

Key points to note here:

- Much of the source code from the `template_file` data source has been duplicated inside the `templatefile` function.
- A logical consequence of the above is that different versions of Terraform and the Template provider can now lead to edge cases where the functionality inside `templatefile` is not identical to the functionality inside the `template_file` data source!

Martin says that the reason for the deprecation is so that "the function call can appear closer to the context where the template will be used". I find that to be a bit dubious on purely software engineering grounds. I think the real reason for the deprecation is so that the code duplication in `template_file` and `templatefile` can be eventually resolved. Indeed, there is a [comment](https://github.com/terraform-providers/terraform-provider-template/blob/5333ad92003c5a18a0cb3452a0b61b24cd6185d2/template/datasource_template_file.go#L125-L131) in the code that says just that:

```js
// We borrow the functions from Terraform itself here. This is convenient
// but note that this is coming from whatever version of Terraform we
// have vendored in to this codebase, not from the version of Terraform
// the user is running, and so the set of functions won't always match
// between Terraform itself and this provider.
// (Over time users will hopefully transition over to Terraform's built-in
// templatefile function instead and we can phase this provider out.)
```

So much for the reasons why the `template_file` data source has been deprecated.

### Template providers >= 2.1

Users of the template provider may wonder why there was a 2.1.0 release followed by a number of .z releases 2.1.1 and 2.1.2. This is explained in the template provider's [CHANGELOG](https://github.com/terraform-providers/terraform-provider-template/blob/master/CHANGELOG.md). Version 2.0.0 was not actually compatible with Terraform 0.12 and thus was never used - you should not be using provider 2.0.0 therefore for anything apparently. And release 2.1.1 and 2.1.2 resolved drift between the HCL2 and the external provider. Just always use the latest seems sensible advice.

### Template language specification

Another interesting point to note is that the release of Terraform 0.12 not only moved the templating functionality into the HCL language itself, but it also got a formal specification at that time. What many will not know is that the formal specification has more complete documentation of the template syntax. Those docs are [here](https://github.com/hashicorp/hcl2/blob/master/hcl/hclsyntax/spec.md#templates).

### The templatefile function

Thus Terrform 0.12 introduced the `templatefile` function to replace the deprecated `template_file` data source, as discussed and for the reasons mentioned above. HashiCorp recommend that you refactor code like this:

```js
data "template_file" "init" {
  filename = "init.tpl"

  vars {
    consul_address = aws_instance.consul.private_ip
  }
}

resource "aws_instance" "web" {
  // ...

  user_data = template_file.init.rendered
}
```

To call the `templatefile` function instead like this:

```js
resource "aws_instance" "web" {
  // ...

  user_data = templatefile("init.tpl", {
    consul_address = aws_instance.consul.private_ip
  })
}
```

I agree with HashiCorp that this often will lead to more readable code, as it has done here. But if the template has a long list of variables, I would not want my resource declaration to be cluttered with details relating to the call to the templatefile. This can perhaps be avoided using local variables. I have an example below in [example 3](#example-3-interpolating-variables-using-the-templatefile-function).

### Template syntax

#### Interpolated variables

Now it is time for some template code examples.

##### Example 1: Interpolating variables in a heredoc

As mentioned above, the only features of the early template language of Terraform 0.5 was the ability to interpolate variables using `${ ... }` notation.

In this simplest template, I use a heredoc to create a hello world string:

```js
locals {
  name = "world"
}

output "hello" {
  value = <<-EOF
    Hello, ${local.name}!
  EOF
}
```

If I apply that:

```text
▶ terraform apply

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

hello = Hello, world!
```

##### Example 2: Interpolating variables in a template_file

To refactor the above using the `template_file` data source:

```js
data "template_file" "hello" {
  template = file("hello.tpl")
  vars     = {
    name = "world"
  }
}

output "hello" {
  value = data.template_file.hello.rendered
}
```

And I create a file hello.tpl:

```text
Hello, ${name}!
```

I will need to run terraform init to load the template provider:

```text
▶ terraform init

Initializing the backend...

Initializing provider plugins...
- Checking for available provider plugins...
- Downloading plugin for provider "template" (hashicorp/template) 2.1.2...

The following providers do not have any version constraints in configuration,
so the latest version was installed.

To prevent automatic upgrades to new major versions that may contain breaking
changes, it is recommended to add version = "..." constraints to the
corresponding provider blocks in configuration, with the constraint strings
suggested below.

* provider.template: version = "~> 2.1"

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

And then to apply that:

```text
▶ terraform apply
data.template_file.hello: Refreshing state...

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

hello = Hello, world!
```

Things to note here:

- Note that by convention Terraform templates have the file extension `.tpl`.
- Note also the necessary call to the [`file()`](https://www.terraform.io/docs/configuration/functions/file.html) function.

##### Example 3: Interpolating variables using the templatefile function

Now refactoring that to illustrate use of the recommended `templatefile` function:

```js
locals {
  hello = templatefile("hello.tpl", {
    name = "world"
  })
}

output "hello" {
  value = local.hello
}
```

And to apply that:

```text
▶ terraform apply

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

hello = Hello, world!
```

#### Directives

Terraform's template language introduces the concept of the _directive_. This terminology is consistent with other templating languages, e.g. ERB, that also refers to such sequences as "directives".

A `%{ ... }` sequence is referred to as a directive, and it allows for conditionals and iteration over collections to be interpolated.

Note that this is in reverse from what users of Jinja2 (in Python, Ansible, Salt etc) and Liquid (what I use for this blog!) might expect. In Jinja2 and Liquid and probably others, that would be {% raw %}`{% ... %}`{% endraw %}.

#### Conditionals

The `if <BOOL>/else/endif` directive allows generation of text in the template based on a boolean expression.

##### Example 4: If else endif example

Here is an example:

```js
variable "name" {}

output "hello" {
  value = <<-EOF
    Hello, %{ if var.name != "" }${var.name}%{ else }world%{ endif }!
  EOF
}
```

Apply that passing various values for the name variable:

Empty string:

```text
▶ TF_VAR_name= terraform apply

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

hello = Hello, world!
```

Something else:

```text
▶ TF_VAR_name=Alex terraform apply

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

hello = Hello, Alex!
```

#### Strip markers

To allow template directives to be formatted for readability without adding unwanted spaces and newlines to the result, all template sequences can include the optional strip markers (`~`), immediately after the opening characters or immediately before the end. When a strip marker is present, the template sequence consumes all of the literal whitespace (spaces and newlines) either before the sequence (if the marker appears at the beginning) or after (if the marker appears at the end).

Other templating languages like Jinja2 and ERB have this same feature, also called "strip" in Jinja2 and "trim" in ERB.

##### Example 5: Refactoring using strip markers

Refactoring the last example to use strip markers:

```js
variable "name" {}

output "hello" {
  value = <<EOF
Hello, %{~ if var.name != "" ~}
 ${var.name}
%{~ else ~}
 world
%{~ endif ~}
!
EOF
}
```

##### Example 6: More on the strip marker

Just for fun I include use of the strip marker without interpolating a variable:

```js
output "hello" {
  value = <<-EOF
    Hello, ${~ "world"}!
  EOF
}
```

Output:

```text
▶ terraform apply

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

hello = Hello,world!
```

#### Iteration

The `for <NAME> in <COLLECTION> / endfor` directive meanwhile iterates over elements of a collection and evaluates a template for each element, concatenating the results together.

##### Example 7: The for loop

A simple for loop example:

```js
locals {
  fruits = ["apple", "banana", "pear"]
}

output "fruits" {
  value = <<-EOF
    My favourite fruits are:
    %{ for fruit in local.fruits ~}
  - ${ fruit }
    %{ endfor ~}
  EOF
}
```

Apply that:

```text
▶ terraform apply

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

fruits = My favourite fruits are:
  - apple
  - banana
  - pear
```

#### Escape sequences

Sometimes the most frustrating part of using a templating language is not knowing the escape sequence to use when you want a literal string that includes one of the templating language's tags. In this section I list all of those escape sequences.

Note that at the time of writing (Terraform 0.12.16 is the latest Terraform at the time of writing), these escape sequences are not documented in [string templates](https://www.terraform.io/docs/configuration/expressions.html#string-templates) section of the docs but they _are_ documented in the ["template literals" section](https://github.com/hashicorp/hcl2/blob/master/hcl/hclsyntax/spec.md#template-literals) of the template language specification document.

The escape sequences are:

|literal string|escape sequence|
|--------------|---------------|
|`${`|`$${`|
|`%{`|`%%{`|

### Bash variables and interpolation in Bash templates

A popular use of Terraform's templates is to create EC2 instance UserData scripts. And a problem that anyone is to run into quickly is the conflict between Bash's `${ ... }` notation and the Terraform template language's identical notation.

Martin Atkins' advice on what to do here can be found in GitHub at [this](https://github.com/hashicorp/terraform/issues/15933#issuecomment-325172950) link here. He offers two solutions:

1. Use the `$${` notation from above.
1. Split the "logic" and "variables" into two files. For example:

    ```js
    data "template_file" "setup_server" {
      template = file("../scripts/setup-server.sh.template")

      vars {
        project_name       = var.project_name
        aws_ecr_access_key = var.aws_ecr_access_key
        aws_ecr_secret_key = var.aws_ecr_secret_key

        logic = file("../scripts/setup-server-logic.sh")
      }
    }
    ```

    Personally, I find that second cure to be worse than the disease! That's why I am going to offer a third solution:

3. Just try very hard not to use the `${ ... }` notation in Bash! This is also a necessary approach if you wish to write Bash unit tests for your Bash scripts.

## Conclusion

This has been another long post where I have discussed the history of the templating features in Terraform from the early days of Terraform 0.5 through all the changes to where we are today in Terraform 0.12. I have discussed the `template_file` resource and then its replacement as a data source, the creation of the template provider in the 0.10 code split, the `templatefile` function in Terraform 0.12 and why the `template_file` data source was deprecated, and then provided a number of code examples.

Stay tuned for part XI. I am not sure yet what is going to be in that but I'm sure it's going to happen!

## See also

- Aurynn Show, 23rd Feb 2017, [Fun with Terraform Template Rendering](https://blog.aurynn.com/2017/2/23-fun-with-terraform-template-rendering).
- @russroy, 12th Nov 2017, [Issue #16628](https://github.com/hashicorp/terraform/issues/16628) where the design of the 0.12 templating is discussed.
- HCL2 [Templates](https://github.com/hashicorp/hcl2/blob/master/hcl/hclsyntax/spec.md#templates) specification.
- The [template_file](https://www.terraform.io/docs/providers/template/d/file.html) data source.
- The [template syntax](https://www.terraform.io/docs/configuration/expressions.html#string-templates) in the main docs.
- The [templatefile](https://www.terraform.io/docs/configuration/functions/templatefile.html) function.
- Justin Campbell, 3rd Jul 2019, [templatefile examples](https://github.com/justincampbell/terraform-templatefile-examples) in GitHub.
