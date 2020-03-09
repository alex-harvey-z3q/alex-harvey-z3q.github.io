---
layout: post
title: "Why ERB should be preferred to Jinja2 for DevOps templating"
date: 2020-03-06
author: Alex Harvey
tags: erb jinja2
---

The use of Jinja2 templating in DevOps has become a de facto standard after the popularisation of Ansible and Salt as configuration management tools and Python as a programming language. Jinja2 has largely displaced the earlier Ruby-based equivalent, ERB (Embedded Ruby), that was previously popular in Puppet and Chef.

In this post, I argue that Jinja2 has a number of flaws that make it not well-suited as a general purpose templating language.

- ToC
{:toc}

## Introduction

The Jinja2 template engine was inspired by Django and provides a Python-like language for securely generating HTML, XML, and other markup. Its benefits are said to be:

- sandboxed execution and optional automatic escaping for applications where security is important.
- portability among Python versions.
- elegance. "Jinja is beautiful".

{% raw %}
```jinja
{% extends "layout.html" %}
{% block body %}
  <ul>
  {% for user in users %}
    <li><a href="{{ user.url }}">{{ user.username }}</a></li>
  {% endfor %}
  </ul>
{% endblock %}
```
{% endraw %}

It is. And used as a web framework, as intended, I have no doubt that it is a powerful, elegant tool, as advertised.

But is it good for code generation in general? Because in DevOps, Jinja2 is not used for generating HTML web pages, but for configuration files, YAML documents, human readable text, Markdown source code, and so on.

In this post I compare some of Jinja2's features with ERB, and I argue that the community could do well to return to ERB.

## DevOps tools using Jinja2

Of DevOps tools I am aware of, Jinja2 has found its way as a templating language into all of the following systems:

|Tool|Year|Description|
|----|----|-----------|
|[Pelican](https://docs.getpelican.com/en/stable/#)|2010|Static site generator|
|[Salt](https://www.saltstack.com)|2011|Configuration management|
|[Ansible](https://www.ansible.com)|2012|Configuration management|
|[Cookiecutter](https://github.com/cookiecutter/cookiecutter)|2013|Project templating|
|[MkDocs](http://www.mkdocs.org/)|2014|Static site generator|
|[Sceptre](https://github.com/Sceptre/sceptre)|2017|Configuration management of CloudFormation|

This is a short list, and I am sure there are many more. But it is used widely.

## Jinja language compared to ERB

|Feature|Jinja2|ERB|
|-------|------|---|
|Basic language|Small, Python-like DSL|Ruby|

Jinja2 is a basic, Python-like DSL, as mentioned, whereas Ruby in ERB is the real Ruby, a featureful, high-level programming language optimised for data and text processing.

Now, if your problem is securely generating web content, I have no opinion on Flask versus Ruby-on-Rails. I assume that Jinja2's design is a good thing. Security is good and I am totally okay with fewer features in the interest of secure content.

But DevOps engineers are generally not using Jinja2 to generate secure web content. As already mentioned, it is used in configuration management to code generate human-readable text, Markdown documents, configuration files, YAML documents, and so on. This is true in tools like Cookiecutter and Sceptre and also Ansible and Salt. Here, I argue that a small, Python-like DSL is a limitation. In fact, a fairly accidental, arbitrary limitation.

## A (very incomplete) Jinja versus ERB feature comparison

If we take a step back, we might consider the history of other programming languages designed with text and code generation in mind. Some of the best known ones are sed (1974), AWK (1975), Perl (1987), and Ruby (1993).

The following table shows a list of basic text manipulation features that are missing in Jinja2:

|Feature|Sed|AWK|Perl|Ruby/ERB|Jinja2|
|-------|---|---|----|--------|------|
|Regex|Yes|Yes|Yes|Yes|No|
|Split function|No|Yes|Yes|Yes|No|
|Read files from disk|Yes|Yes|Yes|Yes|No|
|Define functions inline|Yes|Yes|Yes|Yes|No|
|Call external programs|Yes|Yes|Yes|Yes|No|

It could be argued that the most basic feature of a tool for editing text and data is a regular expression engine. And yet Jinja2 does not have one. The lack of a split function is surprising.

It is obvious that Jinja2 is not designed to edit and manipulate text. The author's assumption is that the caller already edited the text prior to instantiation of the template.

## Jinja2's built-in filters

Jinja2's built-in filters solve some of the same problems that AWK's built-in functions solve. The two languages are comparable in size. Aside from basic language features, Jinja2 has (at the time of writing) 50 built-in "filters". The full list of Jinja2 filters is [here](https://jinja.palletsprojects.com/en/2.11.x/templates/#list-of-builtin-filters). Some of them are great for text manipulation. The center and wordwrap filters are great. But there are not many of them.

## Custom Jinja2 filters

### Custom filters in Ansible and Salt

Users of Ansible and Salt may or may not realise that many of the filters they rely are custom filters provided by Ansible and Salt respectively, rather than actual features of Jinja2.

Ansible's filters are documented [here](https://docs.ansible.com/ansible/latest/user_guide/playbooks_filters.html) and, as can be seen, the list of custom filters is large. There are filters for text manipulation, data transformation, set theory, regular expressions, and so on and on. The length of the list really speaks to how limited Jinja2 itself is.

Salt's similarly-large list of custom filters meanwhile is documented [here](https://docs.saltstack.com/en/latest/topics/jinja/index.html#filters).

### Comparing regex_replace in Ansible and Salt

Often, Ansible and Salt have chosen to implement similar filters with similar usage. Thus, both provide a `regex_replace` filter.

Let's have a look at the source code for these filters respectively.

#### Ansible version

```python
def regex_replace(value='', pattern='', replacement='', ignorecase=False, multiline=False):

    value = to_text(value, errors='surrogate_or_strict', nonstring='simplerepr')

    flags = 0
    if ignorecase:
        flags |= re.I
    if multiline:
        flags |= re.M
    _re = re.compile(pattern, flags=flags)
    return _re.sub(replacement, value)
```

#### Salt version

```python
def regex_replace(txt, rgx, val, ignorecase=False, multiline=False):

    flag = 0
    if ignorecase:
        flag |= re.I
    if multiline:
        flag |= re.M
    compiled_rgx = re.compile(rgx, flag)
    return compiled_rgx.sub(val, txt)
```

This code appears to have been copy/pasted from one tool to the other at some point, and both filters are thin wrappers around the Python [`re.compile`](https://docs.python.org/3/library/re.html#re.compile) function.

It goes without saying that this situation is far from ideal. As a user of Sceptre and Cookiecutter, it is frustrating, to say the least, to search on Stack Overflow and find a solution to a problem that only works in Ansible. It must be frustrating when migrating from Ansible to Salt and vice versa too.

None of this is the fault of Jinja2, but it does raise a red flag that Ansible and Salt spent so much development time in "fixing" Jinja2.

## Calling the shell

Sometimes when doing code generation, it simply makes sense to call the shell, or sed, AWK or some other external program. This probably won't make sense if you are generating HTML for a web site, but it might make sense if you are generating documentation from source code, for instance.

In this ERB example, I call an external Ruby script to auto-generate a Markdown table of contents:

```erb
<%= %x{ruby erb/toc.rb erb/README.erb} -%>
```

But without writing a custom filter, this would be impossible in Jinja2.

## Defining functions inline

Another feature of ERB that I use often is the ability to define a Ruby function inline to deal with repeated code. In this example, I define a function filter. Note that my Ruby function then calls sed.

```erb
<%
  # A method to reformat the examples source
  # code suitable for the public doc version.
  #
  def filter(remote, file_name)
    %x[sed -E '
      s!source( +)=.*!source\\1= "#{remote}"!
      /variable "bucket_name"/ {
        N
        N
        s/{.*}/{}/
      }
      ' #{file_name}]
  end

  remote = %x{git remote -v}.split("\n")[0].split[1]
-%>
```

Some might have concerns about using ERB to call Ruby to call sed. If so, I could rewrite that in pure Ruby in 10 minutes or so. In code generation, it is good to have options.

## Multiline code blocks

Notice in the above example how I have defined a function within a multi-line ERB tag. This is not possible in Jinja2. Consider this Jinja2 example:

{% raw %}
```jinja
do_bootstrap() {
  {% set args = "--kubelet-extra-args '--node-labels=nodegroup=" + node_group_name %}

  {%- if node_labels != "None" %}
    {%- set args = args + "," + node_labels %}
  {%- endif %}

  {%- if cni_custom_network == "Yes" %}
    zone=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
    {%- set args = args + ",k8s.amazonaws.com/eniConfig=pod-netconfig-$zone" %}
  {%- endif %}

  {%- if taints != "None" %}
    {%- set args = args + " --register-with-taints=" + taints %}
  {%- endif %}

  {%- set args = args + "'" -%}

  eval "/etc/eks/bootstrap.sh ${EKSClusterName} {{ args }}"
}
```
{% endraw %}

That code is quite unreadable and it would be nice if Jinja2 allowed me to define multiline code inside its tags. Like this:

{% raw %} 
```jinja 
do_bootstrap() { 
  {%-
    set args = "--kubelet-extra-args '--node-labels=nodegroup=" + node_group_name 
 
    if node_labels != "None" 
      set args = args + "," + node_labels 
    endif 

    if cni_custom_network == "Yes" %} 
      zone=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone) 
      {%- set args = args + ",k8s.amazonaws.com/eniConfig=pod-netconfig-$zone" 
    endif

    if taints != "None"
      set args = args + " --register-with-taints=" + taints
    endif

    set args = args + "'"
  %}

  eval "/etc/eks/bootstrap.sh ${EKSClusterName} {{ args }}"
}
```
{% endraw %}

## White space control

In the default configuration, Jinja2's white space control features are problematic, especially if you are code generating text to be read by humans, such as Markdown documentation, and you need full control of white space.

Consider the following block of code:

{% raw %}
```jinja
foo:
  bar: baz

  {% if qux is defined %}
  qux:
    {% for el in qux %}
    - {{ el }}
    {% endfor %}
  {% endif %}
```
{% endraw %}

If mylist contains quux and quuz, this code generates the following YAML, and I reveal white spaces using `sed l`.

```text
▶ sed -n l text
foo:$
  bar: baz$
$
  $
  qux:$
    $
    - quux$
    - quuz$
    $
  $
```

Of course, what I wanted is:

```text
▶ sed -n l text
foo:$
  bar: baz$
$
  qux:$
    - quux$
    - quuz$
```

I could try this:

{% raw %}
```jinja
foo:
  bar: baz

  {%- if qux is defined %}
  qux:
    {%- for el in qux %}
    - {{ el }}
    {%- endfor %}
  {%- endif %}
```
{% endraw %}

And now I get this:

```text
▶ sed -n l text
foo:$
  bar: baz$
  qux:$
    - quux$
    - quuz$
```

Notice that the new line between bar and qux is gobbled up by the Jinja2 white space trim mode.

In ERB, this would not be a problem. This does what I want:

```erb
foo:
  bar: baz

  <%- unless qux.nil? %>
  qux:
    <%- qux.each do |el| %>
    - <%= el %>
    <%- end %>
  <%- end %>
```

In fairness, this behaviour in Jinja2 can be configured, although I have only seen Jinja2 used in its default configuration.

## Discussion

This is really the tip of the iceberg. With full Ruby inside the templating engine, there is no limit on what can be done inside that template. Whereas in Jinja2, there is a quite severe and arbitrary limit.

I have summarised the main problems with Jinja2 that I personally encounter frequently:

- No ability to call the shell or other languages
- No way to define functions
- No multiline Jinja2 code
- Inferior white space control
- A small number of built-in functions
- Confusion in forums like Stack Overflow as a result of Ansible's and Salt's custom set of filters.

For all of the reasons given above, I do not believe that Jinja2 is a good choice for DevOps templating. If used as originally intended, as a tool for code generating HTML and other web front end markup, I regard Jinja2 as an elegant solution. But when used to code generate configuration files, human readable text, Markdown, YAML documents, and so on, ERB leads to far more productive templating.

This is not a small effect I am pointing to either. With Ruby in the template language, it is easy and fast to do most things. Without it, hours are frequently lost researching problems that simply have no solution.

Is it too late to go back?

## See also

- [Jinja2](https://palletsprojects.com/p/jinja/) home page.
