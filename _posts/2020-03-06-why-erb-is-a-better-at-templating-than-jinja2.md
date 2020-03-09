---
layout: post
title: "Why ERB is better at code generation than Jinja2"
date: 2020-03-06
author: Alex Harvey
tags: erb jinja2
---

The use of Jinja2 templating in the DevOps community has become a de facto standard thanks to the popularity of both Ansible as a configuration management tool and Python as a programming language. Jinja2 has largely displaced the earlier Ruby-based equivalent, ERB (Embedded Ruby). In this post, I argue that Jinja2 has a number of flaws that make it not well-suited to DevOps templating.

- ToC
{:toc}

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

But is it good for code generation in general? Because in the DevOps community, Jinja2 is not used for generating HTML web pages, but for generating configuration files, YAML documents, human readable text, Markdown source code, and so on.

In this post I compare Jinja2's features with ERB, and I argue that the community could do well to return to ERB.

## Modern DevOps tools using Jinja2

Of DevOps tools I am aware of, Jinja2 has found its way in as a templating language in the following systems:

|Tool|Year|Description|
|----|----|-----------|
|[Pelican](https://docs.getpelican.com/en/stable/#)|2010|Static site generator|
|[Salt](https://www.saltstack.com)|2011|Configuration management|
|[Ansible](https://www.ansible.com)|2012|Configuration management|
|[Cookiecutter](https://github.com/cookiecutter/cookiecutter)|2013|Project templating|
|[MkDocs](http://www.mkdocs.org/)|2014|Static site generator|
|[Sceptre](https://github.com/Sceptre/sceptre)|2017|Configuration management of CloudFormation|

This is a short list, and I am sure there are many more. So it has found its way into many tools, mostly a result of Python's popularity.

## Jinja language compared to ERB

|Feature|Jinja2|ERB|
|-------|------|---|
|Basic language|Small, Python-like DSL|Ruby|

Jinja2 is a basic, Python-like DSL optimised to securely generate HTML, XML and other markup, as mentioned, whereas the Ruby in ERB is the real Ruby, a featureful, high-level programming language for data and text processing.

If your problem is securely generating web content, Jinja2's design is no doubt a good thing. Security is good and I am totally okay with having fewer features if more might be misused to generate insecure web content.

But if, on the other hand, your problem is code generating Markdown, configuration files, YAML documents, or other human readable text  - as is the case in tools like Cookiecutter, Ansible, Salt and Sceptre - a small, Python-like DSL is a limitation. Actually, it is a fairly accidental, arbitrary limitation. And the lack of DSL features creates difficulty in solving common code generation problems.

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

It should be immediately apparent that Jinja2 was not designed with text manipulation in mind.

## Built-in Jinja2 filters

Aside from basic language features, Jinja2 also has (at the time of writing) 50 built-in "filters". A filter is like a function in AWK and other programming languages. The full list of Jinja2 filters is [here](https://jinja.palletsprojects.com/en/2.11.x/templates/#list-of-builtin-filters). Some of these are great for text manipulation. The center and wordwrap filters are useful. But there are not so many useful filters.

The size of this language is comparable to AWK. [Here](https://www.gnu.org/software/gawk/manual/html_node/Built_002din.html#Built_002din)) is AWK's full list of built-in functions.

## Custom Jinja2 filters

But the casual users of Ansible and Salt may not realise how limited Jinja2 itself is, since both Ansible and Salt provide a rich set of (different) extensions to the built-in Jinja2 filters.

Ansible's filters are documented [here](https://docs.ansible.com/ansible/latest/user_guide/playbooks_filters.html) and, as can be seen, the list of custom filters is large. There are filters for text manipulation, munging data, set theory, regular expressions, and so on and on. The length of this list really speaks to how limited Jinja2 itself is.

Salt's similarly-large list of custom filters meanwhile is documented [here](https://docs.saltstack.com/en/latest/topics/jinja/index.html#filters).

## Comparing Ansible and Salt filters: regex_replace

Often, Ansible and Salt have chosen to implement similar filters with similar usage. Thus, both provide a `regex_replace` filter.

Let's have a look at the source code for these filters respectively.

### Ansible

```python
def regex_replace(value='', pattern='', replacement='', ignorecase=False, multiline=False):
    ''' Perform a `re.sub` returning a string '''

    value = to_text(value, errors='surrogate_or_strict', nonstring='simplerepr')

    flags = 0
    if ignorecase:
        flags |= re.I
    if multiline:
        flags |= re.M
    _re = re.compile(pattern, flags=flags)
    return _re.sub(replacement, value)
```

### Salt

```python
def regex_replace(txt, rgx, val, ignorecase=False, multiline=False):
    r'''
    Searches for a pattern and replaces with a sequence of characters.

    .. code-block:: jinja

{% raw %}
        {% set my_text = 'lets replace spaces' %}
        {{ my_text | regex_replace('\s+', '__') }}
{% endraw %}

    will be rendered as:

    .. code-block:: text

        lets__replace__spaces
    '''
    flag = 0
    if ignorecase:
        flag |= re.I
    if multiline:
        flag |= re.M
    compiled_rgx = re.compile(rgx, flag)
    return compiled_rgx.sub(val, txt)
```

So, we can see that both Ansible and Salt provide almost identical `regex_replace` custom filters, that are really thin wrappers around the Python [`re.compile`](https://docs.python.org/3/library/re.html#re.compile) function.

It goes without saying that this situation is far from ideal. Ansible users will find a similar but in some ways slightly different set of custom Jinja2 filters if they migrate to Salt. And too bad though if they find themselves using Cookiecutter or Sceptre, since none of these filters exist.

## Calling the shell

Sometimes when doing code generation, it simply makes sense to call the shell, or sed, AWK or some other external program. This probably won't make sense if you are generating HTML for a web site, but it might make sense if you are generation documentation from source code, for instance.

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

I have summarised the main problems that I am aware of as:

- No ability to call the shell or other languages
- No way to define functions
- No multiline Jinja2 code
- Inferior white space control
- A small number of built-in functions
- Confusion in forums like Stack Overflow as a result of Ansible's and Salt's custom set of filters.

For all of the reasons given above, I do not believe that Jinja2 is a good choice for DevOps templating. If used as originally intended, as a tool for code generating HTML and other web front end markup, I regard Jinja2 as an elegant solution. But when used to code generate configuration files, human readable text, Markdown, YAML documents, and so on, ERB leads to far more productive templating. This is not a small effect I am pointing to either. With Ruby in the template language, it is easy and fast to do most anything. Without it, hours are lost all the time researching problems that simply have no solution.

Is it too late to go back?

## See also

- [Jinja2](https://palletsprojects.com/p/jinja/) home page.
