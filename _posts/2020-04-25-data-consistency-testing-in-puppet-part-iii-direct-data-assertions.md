---
layout: post
title: "Data consistency testing in Puppet, Part III: Direct data assertions"
date: 2020-04-25
author: Alex Harvey
tags: puppet
category: puppet
---

In this third and probably the last part of this series, I look at the method of using Rspec to make direct assertions about Hiera data. Usually, the purpose of these assertions is to work around design flaws in a code base that cannot be easily corrected.

- ToC
{:toc}

## Introduction

In my experience of infrastructure-as-code solutions, whether written in Puppet or anything else, operational usability issues remain no matter how clean the code, no matter how many unit and integration tests, and no matter how good is the documentation. Writing an infrastructure-as-code solution is not easy, and design flaws find their way in. In this post, I assume that your Hiera design is not perfect, and in particular, I assume that the single-source-of-truth (SSoT) principle has been violated.

## Code example

The code example I use in this post comes from a modification of a code example I found online [here](https://blog.serverdensity.com/deploying-nginx-with-puppet/) for deploying Nginx:

```yaml
# common.yaml
---
nginx::config::vhost_purge: true
nginx::config::confd_purge: true

nginx::nginx_vhosts:
  'example.com':
    ensure: present
    rewrite_www_to_non_www: true
    www_root: /srv/www/example.com/
    try_files:
      - '$uri'
      - '$uri/'
      - '/index.php$is_args$args'

nginx::nginx_locations:
  'php':
    ensure: present
    vhost: example.com
    location: '~ .php$'
    www_root: /srv/www/example.com/
    try_files:
      - '$uri'
      - '/index.php =404'
    location_cfg_append:
      fastcgi_split_path_info: '^(.+\.php)(.*)$'
      fastcgi_pass: 'php'
      fastcgi_index: 'index.php'
      fastcgi_param SCRIPT_FILENAME: "/srv/www/example.com$fastcgi_script_name"
      include: 'fastcgi_params'
      fastcgi_param QUERY_STRING: '$query_string'
      fastcgi_param REQUEST_METHOD: '$request_method'
      fastcgi_param CONTENT_TYPE: '$content_type'
      fastcgi_param CONTENT_LENGTH: '$content_length'
      fastcgi_intercept_errors: 'on'
      fastcgi_ignore_client_abort: 'off'
      fastcgi_connect_timeout: '60'
      fastcgi_send_timeout: '180'
      fastcgi_read_timeout: '180'
      fastcgi_buffer_size: '128k'
      fastcgi_buffers: '4 256k'
      fastcgi_busy_buffers_size: '256k'
      fastcgi_temp_file_write_size: '256k'

  'server-status':
    ensure: present
    vhost: /srv/www/example.com/
    location: /server-status
    stub_status: true
    location_cfg_append:
      access_log: off
      allow: 127.0.0.1
      deny: all

serverdensity_agent::plugin::nginx::nginx_status_url: "http://example.com/server-status"

nginx::nginx_upstreams:
  'php':
    ensure: present
    members:
      - unix:/var/run/php5-fpm.sock

php::fpm: true

php::fpm::settings:
  PHP/short_open_tag: 'On'

php::extensions:
  json: {}
  curl: {}
  mcrypt: {}

php::fpm::pools:
  'www':
    listen: unix:/var/run/php5-fpm.sock
    pm_status_path: /php-status
```

## Code on GitHub

The source code for this blog post is available online at GitHub [here](https://github.com/alexharv074/data_consistency_part_iii).

## What are we testing and why

The code above shows how to configure an Nginx vhost using Puppet. And as it stands, this code is fine and doesn't really need to be tested any further if all the usual tests (e.g. end-to-end tests in Beaker) pass.

But what if this was to be the first of many Nginx vhosts, and an operational procedure is to copy this code and use it as the basis of new vhosts in the future? In this case, I can see this code being quite problematic. Here is what I think is going to happen:

1. People are going to make YAML errors such as indentation errors, duplicate keys, and so on.
1. The vhost domain `example.com` appears in 7 different places in the code. People are going to forget to update some of these.
1. By exposing so many of Nginx's configuration options, I expect that over time, a lot of invalid Nginx configurations will be accidentally set.

## Is there a better way

As far as duplication of the vhost domain in 7 places, there is almost always a better way to handle duplication than the method I am proposing in this post. In this case, we could refactor to add a key `vdomain` and replace each occurrence of the string `example.com` like this:

```yaml
vdomain: example.com

nginx::nginx_vhosts:
  "%{lookup('vdomain')}":
    ensure: present
    rewrite_www_to_non_www: true
    www_root: "/srv/www/%{lookup('vdomain')}/"
    try_files:
      - '$uri'
      - '$uri/'
      - '/index.php$is_args$args'
```

And so on.

But this could be harder if you already have 5,000 vhosts! Then what?

The key point here is this method I am proposing is often used as a work-around to design flaws. Fix those design flaws if you can. If you can't, consider this method as way better than nothing.

## Tests

### Yamllint

#### Overview

Use of Yamllint on any YAML files used in configuration management is in my opinion always recommended. Why? One reason alone makes it always worthwhile: the dreaded duplicate key issue. The duplicate key issue is often almost impossible to otherwise detect and can lead to the user believing their configuration is A when it is in fact B! If this happens, you can easily lose days or even have bugs that no one can find.

At this time, I am unaware of any other Yamllint utility than the [Python-based version](https://github.com/adrienverge/yamllint) by Adrien Vergé.

#### Rakefile

To ensure that the installation of Yamllint itself is automatic and the whole thing is easy to use, I begin with two Rake tasks in Rakefile:

```ruby
desc 'Install Yamllint'
task :install_yamllint do
  sh 'yamllint --version || bash venv.sh'
end

desc 'Yamllint Hiera files'
task :yamllint => :install_yamllint do
  sh 'yamllint -c yamllint.yml hieradata/*.yaml'
end
```

This refers to two other files that are expected to also exist, venv.sh, which installs Yamllint in a virtualenv, and yamllint.yml, Yamllint's configuration file.

#### venv.sh

This is a very simple shell script:

```bash
#!/usr/bin/env bash
virtualenv venv
. venv/bin/activate
pip install yamllint
```

#### yamllint.yml

Yamllint's configuration. Customise to your liking!

```yaml
---
rules:
  braces:
    min-spaces-inside: 0
    max-spaces-inside: 0
    min-spaces-inside-empty: -1
    max-spaces-inside-empty: -1
  brackets:
    min-spaces-inside: 0
    max-spaces-inside: 0
    min-spaces-inside-empty: -1
    max-spaces-inside-empty: -1
  colons:
    max-spaces-before: 0
    max-spaces-after: 1
  commas:
    max-spaces-before: 0
    min-spaces-after: 1
    max-spaces-after: 1
  document-end: disable
  document-start:
    level: error
    present: true
  empty-lines:
    max: 1
    max-start: 0
    max-end: 0
  empty-values:
    forbid-in-block-mappings: false
    forbid-in-flow-mappings: false
  hyphens:
    max-spaces-after: 1
  indentation:
    spaces: consistent
    indent-sequences: true
    check-multi-line-strings: false
  key-duplicates: enable
  key-ordering: disable
  new-line-at-end-of-file: enable
  new-lines:
    type: unix
  octal-values:
    forbid-implicit-octal: false
    forbid-explicit-octal: false
  trailing-spaces: enable
  truthy: disable
```

#### Running the test

To run the Yamllint tests:

```text
▶ bundle exec rake yamllint
yamllint --version || bash venv.sh
yamllint 1.11.1
yamllint -c yamllint.yml hieradata/*.yaml
```

What if I deliberately insert a duplicate key:

```diff
--- a/hieradata/common.yaml
+++ b/hieradata/common.yaml
@@ -73,3 +73,13 @@ php::fpm::pools:
   'www':
     listen: unix:/var/run/php5-fpm.sock
     pm_status_path: /php-status
+
+nginx::nginx_vhosts:
+  'example.com':
+    ensure: present
+    rewrite_www_to_non_www: true
+    www_root: /srv/www/example.com/
+    try_files:
+      - '$uri'
+      - '$uri/'
+      - '/index.php$is_args$args'
```

Run it again:

```text
▶ bundle exec rake yamllint                                                                   
yamllint --version || bash venv.sh
yamllint 1.11.1
yamllint -c yamllint.yml hieradata/*.yaml
hieradata/common.yaml
  77:1      error    duplication of key "nginx::nginx_vhosts" in mapping  (key-duplicates)

rake aborted!
Command failed with status (1): [yamllint -c yamllint.yml hieradata/*.yaml...]
/Users/alexharvey/git/home/data_consistency_part_iii/Rakefile:10:in `block in <top (required)>'
/Users/alexharvey/.rvm/gems/ruby-2.4.1/gems/rake-13.0.1/exe/rake:27:in `<top (required)>'
/Users/alexharvey/.rvm/gems/ruby-2.4.1/bin/ruby_executable_hooks:24:in `eval'
/Users/alexharvey/.rvm/gems/ruby-2.4.1/bin/ruby_executable_hooks:24:in `<main>'
Tasks: TOP => yamllint
(See full trace by running task with --trace)
```

Never underestimate the usefulness of this test!

### Rspec assertions about the data

But the point of this post is really about direct assertions about the data using Rspec. Here is the, hopefully easy to understand, Rspec code:

```ruby
#!/usr/bin/env ruby

require "spec_helper"
require "yaml"

data = YAML.load_file("hieradata/common.yaml")

describe "Nginx data" do
  data["nginx::nginx_vhosts"].keys.each do |vhost|

    context "nginx::nginx_vhosts.#{vhost}" do
      ref = data["nginx::nginx_vhosts"][vhost]
      it "www_root" do
        expect(ref["www_root"]).to eq "/srv/www/#{vhost}/"
      end
    end

    context "nginx::nginx_locations.'php'" do
      ref = data["nginx::nginx_locations"]["php"]

      it "vhost" do
        expect(ref["vhost"]).to eq vhost
      end

      it "www_root" do
        expect(ref["www_root"]).to eq "/srv/www/#{vhost}/"
      end

      context "location_cfg_append" do
        inner_ref = ref["location_cfg_append"]
        it "fastcgi_param SCRIPT_FILENAME" do
          expect(
            inner_ref["fastcgi_param SCRIPT_FILENAME"]
          ).to eq "/srv/www/#{vhost}$fastcgi_script_name"
        end
      end
    end

    context "nginx::nginx_locations.'server-status'" do
      ref = data["nginx::nginx_locations"]["server-status"]
      it "vhost" do
        expect(ref["vhost"]).to eq "/srv/www/#{vhost}/"
      end
    end

    context "serverdensity_agent::plugin::nginx::nginx_status_url" do
      it do
        expect(
          data["serverdensity_agent::plugin::nginx::nginx_status_url"]
        ).to eq "http://#{vhost}/server-status"
      end
    end
  end
end
```

### Assertions against Nginx docs

What if I want to take this even further, and make assertions about Nginx [directives](http://nginx.org/en/docs/http/ngx_http_fastcgi_module.html#directives) based on documentation? Let's do that too:

```diff
--- a/spec/data_spec.rb
+++ b/spec/data_spec.rb
@@ -33,6 +33,18 @@ describe "Nginx data" do
             inner_ref["fastcgi_param SCRIPT_FILENAME"]
           ).to eq "/srv/www/#{vhost}$fastcgi_script_name"
         end
+
+        it "fastcgi_intercept_errors" do
+          expect(
+            ["on","off"].include?(inner_ref["fastcgi_intercept_errors"])
+          ).to be true
+        end
+
+        it "fastcgi_ignore_client_abort" do
+          expect(
+            ["on","off"].include?(inner_ref["fastcgi_ignore_client_abort"])
+          ).to be true
+        end
       end
     end
```

### Run the tests

Running the tests is shown in the following screenshot:

![Run the tests]({{ "/assets/run_tests.png" | absolute_url }})

Notice one of the cool things about the Rspec framework for testing nested YAML data is the way I can also easily nest the tests using contexts to create a nice, readable output like this.

## Discussion

This post has introduced three layers of direct Hiera data testing that can be used in Puppet. In all cases, the tests have a bit of work to write them in the first place, but after that, should be quite maintainable. The cost-benefit ratio will differ in each case. I daresay that the benefit of having the Yamllint layer of testing will always outweigh the cost of writing it and the maintenance. It would only need to capture a single duplicate key to payoff the cost of setting it up. And because Yamllint is highly configurable, the tests can be made as pedantic or as forgiving as fits the personality of a team.

The direct assertions about YAML data keys is likely to be more contentious. Some will say this is an anti-pattern and you shoud not directly test your data. I am not sure where that idea originated but I have heard it said before. I would disagree obviously. But anyone who has an operational procedure to cut new Nginx or similar configurations by copying and editing data, I expect they will immediately find tests of the sort I have written here useful. And that has been my experience where I set these up for clients in the past. This layer of testing proved to be both useful and popular.

The third layer of making assertions against Nginx configuration documentation is probably taking things further than I would tend to myself, but I simply show what is possible. No one should test for the sake of it but it is good to know what is possible.

Finally, note well that while this post is ostensibly about Puppet, the methods shown here can be extended to any configuration management tool that uses YAML data files. I may at some point write a separate post showing how I have applied these methods in CloudFormation, Ansible and so on.

As always I welcome feedback and discussion if anyone has any so send me an email if you have comments.

## See also

- Paul Hammond and Samantha Stoller, Jul 28 2016, [Data Consistency Checks](https://slack.engineering/data-consistency-checks-e73261318f96) (Slack Engineering).
