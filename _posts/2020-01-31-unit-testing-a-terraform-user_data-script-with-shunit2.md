---
layout: post
title: "Unit testing a Terraform user_data script with shUnit2"
date: 2020-01-31
author: Alex Harvey
tags: terraform shunit2 bash
---

In this post, which could be read as part II to an [earlier](https://alexharv074.github.io/2017/07/07/unit-testing-a-bash-script-with-shunit2.html) post, I document a method for unit testing a Terraform user_data script that is broken into functions.

- Toc
{:toc}

## Why test

Those unfamiliar with the practice of unit testing Bash shell scripts like UserData scripts are often confused about what we would test and why we would bother to do this. So let me set out here some of the reasons to unit test Bash UserData scripts.

|Use case|UserData example|
|--------|-----------------|
|Safely refactor code|Minor style improvements to a Bash UserData script should not require expensive end-to-end tests.|
|Quickly test complex Bash one-liners or complex logic|Some common examples include testing `jq`, `sed`, and `awk` one-liners.|
|Unit tests often force best practices on the code author|Badly-written Bash code is often not testable. Unit tests force this code to be refactored.|
|Unit tests provide a layer of code-as-documentation that otherwise would not exist|If a `jq` command is unreadable, for example, the tests for this will assist the reader understand what it does.|

## About the example code

### Example script

I begin with a typical-looking Bash UserData script that has a number of problems and is untestable in its initial form:

```bash
#!/usr/bin/env bash

echo "\
127.0.0.1   localhost localhost.localdomain $(hostname)" \
  >> /etc/hosts

# update system
yum -y update

# install deps
yum -y install aws-cli awslogs jq

# configure cloudwatch
read -r instance_id region <<< "$(
  curl -s http://169.254.169.254/latest/dynamic/instance-identity/document \
    | jq -r '[.instanceId, .region] | @tsv'
)"

cat > /etc/awslogs/awslogs.conf <<EOF
[general]
state_file = /var/lib/awslogs/agent-state

[/var/log/dmesg]
file = /var/log/dmesg
log_stream_name = $instance_id/dmesg
log_group_name = ${gitlab_runner_log_group_name}
initial_position = start_of_file

[/var/log/messages]
file = /var/log/messages
log_stream_name = $instance_id/messages
log_group_name = ${gitlab_runner_log_group_name}
datetime_format = %b %d %H:%M:%S
initial_position = start_of_file

[/var/log/user-data.log]
file = /var/log/user-data.log
log_stream_name = $instance_id/user-data
log_group_name = ${gitlab_runner_log_group_name}
initial_position = start_of_file
EOF

sed -i '
  s/region = us-east-1/region = '"$region"'/
' /etc/awslogs/awscli.conf

service awslogs start
chkconfig awslogs on

# generate config.toml
mkdir -p /etc/gitlab-runner
cat > /etc/gitlab-runner/config.toml <<EOF
${runners_config}
EOF

# install gitlab runner
curl -L \
  https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh | bash
yum -y install gitlab-runner-"${gitlab_runner_version}"
curl --fail --retry 6 -L \
  https://github.com/docker/machine/releases/download/v"${docker_machine_version}"/docker-machine-"$(uname -s)"-"$(uname -m)" > /tmp/docker-machine
chmod +x /tmp/docker-machine
cp /tmp/docker-machine /usr/local/bin/docker-machine
ln -s /usr/local/bin/docker-machine /usr/bin/docker-machine

# Create a dummy machine so that the cert is generated properly
# See: https://gitlab.com/gitlab-org/gitlab-runner/issues/3676
docker-machine create --driver none --url localhost dummy-machine

# register runner
token=$(aws ssm get-parameters --names "${runners_ssm_token_key}" \
  --with-decryption --region "${aws_region}" | jq -r '.Parameters[0].Value')

if [ "$token" == "null" ] ; then
  response=$(
    curl -X POST -L "${runners_url}/api/v4/runners" \
      -F "token=${gitlab_runner_registration_token}" \
      -F "description=${gitlab_runner_description}" \
      -F "locked=${gitlab_runner_locked_to_project}" \
      -F "maximum_timeout=${gitlab_runner_maximum_timeout}" \
      -F "access_level=${gitlab_runner_access_level}" \
  )

  token=$(jq -r .token <<< "$response")

  if [ "$token" == "null" ] ; then
    echo "Received the following error:"
    echo "$response"
    return
  fi

  aws ssm put-parameter --overwrite --type SecureString --name \
    "${runners_ssm_token_key}" --value "$token" --region "${aws_region}"
fi

sed -i 's/##TOKEN##/'"$token"'/' /etc/gitlab-runner/config.toml

# start gitlab runner
service gitlab-runner restart
chkconfig gitlab-runner on

# vim: set ft=sh:
```

### What it does

This is a script for an EC2 UserData script that installs a Gitlab Runner.

### Terraform declaration

Because this is a Terraform UserData script there will be a declaration in the Terraform code that looks like this for it:

```js
data "template_file" "user_data" {
  template = file("${path.module}/template/user-data.sh.tpl")

  vars = {
    aws_region                       = var.aws_region
    docker_machine_version           = local.docker_machine_version
    gitlab_runner_description        = var.gitlab_runner_registration_config["description"]
    gitlab_runner_access_level       = var.gitlab_runner_registration_config["access_level"]
    gitlab_runner_locked_to_project  = var.gitlab_runner_registration_config["locked_to_project"]
    gitlab_runner_maximum_timeout    = var.gitlab_runner_registration_config["maximum_timeout"]
    gitlab_runner_registration_token = var.gitlab_runner_registration_config["registration_token"]
    gitlab_runner_version            = local.gitlab_runner_version
    gitlab_runner_log_group_name     = local.gitlab_runner_log_group_name
    runners_config                   = data.template_file.runners.rendered
    runners_ssm_token_key            = local.runners_ssm_token_key
    runners_url                      = var.runners_url
  }
}
```

### Note about variable interpolation

Terraform interprets a notation `${ ... }` as a variable to be interpolated. Thus, `${aws_region}` will be interpolated as something like `ap-southeast-2` in the generated Bash script. Of course, Bash also understands `${aws_region}` to mean variable expansion, although it fortunately also allows `$aws_region`. My proposal for Terraform UserData scripts is therefore to never use the Bash `${ ... }` notation.

Note that Martin Atkins at HashiCorp has [recommended](https://github.com/hashicorp/terraform/issues/15933#issuecomment-325172950) a different approach:

> Sequences that look like interpolation sequences can be escaped by doubling the quotes:
>
> ```bash
> username=$${USERNAME:-deploy}
> ```
> To reduce the impact of such conflicts, I usually recommend splitting the logic and the variables into two separate files. The template would then just be a wrapper around the main script, which is uploaded verbatim without any template processing.

The problem with Martin's approach is that it becomes a bit unreadable and also means the testing method I am herein proposing will not work.

## What are we testing

As is often the case with such UserData scripts, a lot of it does not really need to be unit-tested. Consider a line:

```text
yum -y update
```

How could I "unit test" that? I would hope that the maintainers of the yum system do have good testing practices but from my end, the only testing I can do is at a system test level. Even then I can't really test much. Those who dare to run yum -y update must hope that upstream yum repos are working!

If I did want to cover this line in a unit test, I can replace it with a stub like so:

```bash
yum() { : ; }
```

This will allow the yum command to execute and do nothing. Still, I am not really "testing" anything when I do this.

What I really want to test is all those `curl`, `jq` and `sed` commands. But if I wrote tests in the script's current format, I would have a huge amount of setup for the sake of only a small amount of testing. If your setup leads to significantly more code than your tests, I consider that to be a bit of an anti-pattern.

So we must begin by refactoring this script into functions. That will make it both more readable, a better script, and testable.

## Refactor into functions

After refactoring the script into functions I end up with this:

```bash
#!/usr/bin/env bash

awslogs_conf='/etc/awslogs/awslogs.conf'
awscli_conf='/etc/awslogs/awscli.conf'
config_toml='/etc/gitlab-runner/config.toml'

update_hosts_file() {
  echo "\
127.0.0.1   localhost localhost.localdomain $(hostname)" \
  >> /etc/hosts
}

update_system() {
  yum -y update
}

install_deps() {
  yum -y install aws-cli awslogs jq
}

make_awslogs_conf() {
  local instance_id="$1"
  cat <<EOF
[general]
state_file = /var/lib/awslogs/agent-state

[/var/log/dmesg]
file = /var/log/dmesg
log_stream_name = $instance_id/dmesg
log_group_name = ${gitlab_runner_log_group_name}
initial_position = start_of_file

[/var/log/messages]
file = /var/log/messages
log_stream_name = $instance_id/messages
log_group_name = ${gitlab_runner_log_group_name}
datetime_format = %b %d %H:%M:%S
initial_position = start_of_file

[/var/log/user-data.log]
file = /var/log/user-data.log
log_stream_name = $instance_id/user-data
log_group_name = ${gitlab_runner_log_group_name}
initial_position = start_of_file
EOF
}

configure_cloudwatch() {
  local instance_id region

  read -r instance_id region <<< "$(
    curl -s http://169.254.169.254/latest/dynamic/instance-identity/document \
      | jq -r '[.instanceId, .region] | @tsv'
  )"

  make_awslogs_conf "$instance_id" > "$awslogs_conf"

  sed -i '
    s/region = us-east-1/region = '"$region"'/
  ' "$awscli_conf"

  service awslogs start
  chkconfig awslogs on
}

generate_config_toml() {
  mkdir -p /etc/gitlab-runner
  cat > "$config_toml" <<EOF
${runners_config}
EOF
}

install_gitlab_runner() {
  curl -L \
    https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh | bash
  yum -y install gitlab-runner-"${gitlab_runner_version}"
  curl --fail --retry 6 -L \
    https://github.com/docker/machine/releases/download/v"${docker_machine_version}"/docker-machine-"$(uname -s)"-"$(uname -m)" > /tmp/docker-machine
  chmod +x /tmp/docker-machine
  cp /tmp/docker-machine /usr/local/bin/docker-machine
  ln -s /usr/local/bin/docker-machine /usr/bin/docker-machine

  # Create a dummy machine so that the cert is generated properly
  # See: https://gitlab.com/gitlab-org/gitlab-runner/issues/3676
  docker-machine create --driver none --url localhost dummy-machine
}

register_runner() {
  token=$(aws ssm get-parameters --names "${runners_ssm_token_key}" \
    --with-decryption --region "${aws_region}" | jq -r '.Parameters[0].Value')

  if [ "$token" == "null" ] ; then
    response=$(
      curl -X POST -L "${runners_url}/api/v4/runners" \
        -F "token=${gitlab_runner_registration_token}" \
        -F "description=${gitlab_runner_description}" \
        -F "locked=${gitlab_runner_locked_to_project}" \
        -F "maximum_timeout=${gitlab_runner_maximum_timeout}" \
        -F "access_level=${gitlab_runner_access_level}" \
    )

    token=$(jq -r .token <<< "$response")

    if [ "$token" == "null" ] ; then
      echo "Received the following error:"
      echo "$response"
      return
    fi

    aws ssm put-parameter --overwrite --type SecureString --name \
      "${runners_ssm_token_key}" --value "$token" --region "${aws_region}"
  fi

  sed -i 's/##TOKEN##/'"$token"'/' "$config_toml"
}

start_gitlab_runner() {
  service gitlab-runner restart
  chkconfig gitlab-runner on
}

main() {
  update_hosts_file
  update_system
  install_deps
  configure_cloudwatch
  generate_config_toml
  install_gitlab_runner
  register_runner
  start_gitlab_runner
}

if [ "$0" == "$BASH_SOURCE" ] ; then
  main
fi

# vim: set ft=sh:
```

## Benefits of refactoring

This code is now testable. I can test the `configure_cloudwatch` and `register_runner` functions and ignore all the rest of the code. All those redundant comments like `# start gitlab runner` have been turned into the names of functions making the code self-documenting. Sometimes people will tell you, "comments are bugs". This refactoring exercise helps reveal why some comments really are "bugs". I also have a `main` function that summarises the logic of the UserData script at a high-level. This is a good piece of code-as-documentation that didn't otherwise exist.

So the discipline of unit testing has already led to a better piece of code - and I haven't written any tests yet!

## Writing the unit tests

### Installing shunit2

Because shUnit2 is still not released very often, it is, at the time of writing, necessary to get shunit2 from the master branch of the Git project like so:

```text
▶ curl \
  https://github.com/kward/shunit2/blob/c47d32d6af2998e94bbb96d58a77e519b2369d76/shunit2 \
  /usr/local/bin/shunit2
```

This is a version that I know works and has some patches e.g. for coloured output not yet in the released version.

### Project structure

I assume you will have a project structure like this:

```text
▶ tree
├── main.tf
├── shunit2
│   └── test_user_data.sh
└── template
    └── user-data.sh.tpl
```

### Test boilerplate

I started with a file `shunit2/test_user_data.sh` like this:

```bash
#!/usr/bin/env bash

if [ "$(uname -s)" == "Darwin" ] ; then
  if [ ! -x /usr/local/bin/gsed ] ; then
    echo "On Mac OS X you need to install gnu-sed:"
    echo "$ brew install gnu-sed"
    exit 1
  fi

  shopt -s expand_aliases
  alias sed='/usr/local/bin/gsed'
fi

script_under_test='template/user-data.sh.tpl'

setUp() {
  . "$script_under_test"
}

testConfigureCloudwatch() {
  true
}

. shunit2
```

Most of that is self-explanatory. If you're running this on Linux instead of Mac OS X you may not need to deal with gsed.

### testConfigureCloudwatch

#### function-under-test

So the `configure_cloudwatch` function looks like this:

```bash
awslogs_conf='/etc/awslogs/awslogs.conf'
awscli_conf='/etc/awslogs/awscli.conf'

configure_cloudwatch() {
  local instance_id region

  read -r instance_id region <<< "$(
    curl -s http://169.254.169.254/latest/dynamic/instance-identity/document \
      | jq -r '[.instanceId, .region] | @tsv'
  )"

  make_awslogs_conf "$instance_id" > "$awslogs_conf"

  sed -i '
    s/region = us-east-1/region = '"$region"'/
  ' "$awscli_conf"

  service awslogs start
  chkconfig awslogs on
}
```

I want to test the `jq` command and the `sed` command. I am also happy to indirectly test the `make_awslogs_conf` function. Some purists might say this is an anti-pattern and my tests should test these two functions separately. Meh. That would lead to more lines of test code for no additional benefit. Knowing the rules helps to know when to break them I suppose.

#### mocking the curl command

The first thing I want to test is the `read` then `curl` then `jq` contruction. Does that actually work? What does it do? So I log onto an EC2 instance and get myself some real output for the `curl` command in my script:

```text
▶ curl -s http://169.254.169.254/latest/dynamic/instance-identity/document
{
  "accountId" : "111111111111",
  "architecture" : "x86_64",
  "availabilityZone" : "ap-southeast-2a",
  "billingProducts" : null,
  "devpayProductCodes" : null,
  "marketplaceProductCodes" : null,
  "imageId" : "ami-08589eca6dcc9b39c",
  "instanceId" : "i-04a8628dca6b55a60",
  "instanceType" : "t2.micro",
  "kernelId" : null,
  "pendingTime" : "2020-02-02T05:38:21Z",
  "privateIp" : "172.31.14.8",
  "ramdiskId" : null,
  "region" : "ap-southeast-2",
  "version" : "2017-09-30"
}
```

Now I _could_ hard-code all of that data in my test, although I can see that since I filter the output through `jq -r` I actually only really care about the two keys `instanceId` and `region`. To keep my tests concise, I am going to set up the following mock:

```bash
curl() { echo '{"instanceId":"i-11111111","region":"ap-southeast-2"}' ; }
```

#### Mocking the service and chkconfig commands

Next I'll need to create a fake `service` and `chkconfig` command. Because they are incidental to the logic I am testing, I can replace them with stubs that don't do anything:

```bash
service() { : ; }
chkconfig() { : ; }
```

#### Mocking the awscli_conf and awslogs_conf files

Notice how I replaced the `/etc/awslogs/awslogs.conf` and `/etc/awslogs/awscli.conf` files with variables. If I had not done this, I would have testing problems because I probably will not have write access in my test environment to the `/etc` directory. And I certainly don't _want_ my tests to change stuff in there! I _could_ run the tests inside a jail or a Docker container, but that seems like way too much trouble.

By replacing these two file paths with variables, I can read them from elsewhere in the context of my tests, and I can replace them with fakes in my tests:

```bash
awslogs_conf='./test_awslogs.conf'
awscli_conf='./test_awscli.conf'

cat > "$awscli_conf" <<EOF
foo bar foo bar
region = us-east-1
baz qux baz qux
EOF
```

#### Putting this all together

I can then have my first test case as follows:

```bash
testConfigureCloudwatch() {
  curl() { echo '{"instanceId":"i-11111111","region":"ap-southeast-2"}' ; }

  service() { : ; }
  chkconfig() { : ; }

  awslogs_conf='./test_awslogs.conf'
  awscli_conf='./test_awscli.conf'

  cat > "$awscli_conf" <<EOF
foo bar foo bar
region = us-east-1
baz qux baz qux
EOF

  configure_cloudwatch

  assertTrue "$awslogs_conf does not contain instance_id" "grep -q i-11111111 $awslogs_conf"
  assertTrue "$awscli_conf does not contain region" "grep -q ap-southeast-2 $awscli_conf"

  rm -f "$awslogs_conf" "$awscli_conf"
}
```

Here I have tested that:

- My `read`, `curl` and `jq` construction has successfully read in the instance_id and region from the curl command.
- The `sed` command has correct replaced the region in `$awscli_conf`.
- The `$awslogs_conf` file contains the instance ID.

I could probably be a bit more verbose and pedantic about it but this is enough to convince myself that this function "works".

### testing the register_runner function

#### function-under-test

The other function to test is `register_runner`:

```bash
register_runner() {
  token=$(aws ssm get-parameters --names "${runners_ssm_token_key}" \
    --with-decryption --region "${aws_region}" | jq -r '.Parameters[0].Value')

  if [ "$token" == "null" ] ; then
    response=$(
      curl -X POST -L "${runners_url}/api/v4/runners" \
        -F "token=${gitlab_runner_registration_token}" \
        -F "description=${gitlab_runner_description}" \
        -F "locked=${gitlab_runner_locked_to_project}" \
        -F "maximum_timeout=${gitlab_runner_maximum_timeout}" \
        -F "access_level=${gitlab_runner_access_level}" \
    )

    token=$(jq -r .token <<< "$response")

    if [ "$token" == "null" ] ; then
      echo "Received the following error:"
      echo "$response"
      return
    fi

    aws ssm put-parameter --overwrite --type SecureString --name \
      "${runners_ssm_token_key}" --value "$token" --region "${aws_region}"
  fi

  sed -i 's/##TOKEN##/'"$token"'/' "$config_toml"
}
```

This one is more complex as it contains conditional logic and therefore multiple logical pathways. Those paths are reached depending on the value returned to `$token`. In this first test case, I let the value returned to `$token` be `null`.

#### test case 1

This time my first test looks like this:

```bash
testRegisterRunnerTokenNull() {
  aws() {
    case "${FUNCNAME[0]} $*" in

    "aws ssm get-parameters --names $runners_ssm_token_key --with-decryption --region $aws_region")
      echo '{"InvalidParameters":["'"$runners_ssm_token_key"'"],"Parameters":[]}' ;;

    "aws ssm put-parameter --overwrite --type SecureString --name $runners_ssm_token_key --value $token --region $aws_region")
      echo '{"Version":"1"}' ;;

    esac
  }

  curl() { echo '{"token":"ANOTHERSECRETTOKEN"}' ; }

  config_toml='./test_config.toml'

  cat > "$config_toml" <<EOF
foo bar foo bar
this line has ##TOKEN## in it
baz qux baz qux
EOF

  runners_ssm_token_key='/mykey'
  aws_region='ap-southeast-2'
  runners_url='https://gitlab.com'
  gitlab_runner_registration_token='XXXXXXXX'
  gitlab_runner_description='my runner'
  gitlab_runner_locked_to_project='true'
  gitlab_runner_maximum_timeout='10'
  gitlab_runner_access_level='debug'
  gitlab_runner_log_group_name='gitlab-runner-log-group'

  register_runner

  assertTrue "$config_toml does not have secret token in it" "grep -q ANOTHERSECRETTOKEN $config_toml"

  rm -f "$config_toml"
}
```

The only real conceptual difference between this test and the previous one is that my `aws` mock behaves differently depending on what the arguments passed to `aws` are. (See my earlier post [Testing AWS CLI scripts in shunit2](https://alexharv074.github.io/2018/09/07/testing-aws-cli-scripts-in-shunit2.html) for more info.)

#### test case 2

In the second test case, I allow the `curl` command to receive a difference response from the Gitlab API:

```bash
curl() { echo '{"message":{"tags_list":["can not be empty when runner is not allowed to pick untagged jobs"]}}' ; }
```

Obviously, I could only learn that it would respond in such a way from either experimentation or the API documentation etc. In my case, it was experimentation.

The full test is:

```bash
testRegisterRunnerWithError() {
  aws() {
    case "${FUNCNAME[0]} $*" in

    "aws ssm get-parameters --names $runners_ssm_token_key --with-decryption --region $aws_region")
      echo '{"InvalidParameters":["'"$runners_ssm_token_key"'"],"Parameters":[]}' ;;

    esac
  }

  curl() { echo '{"message":{"tags_list":["can not be empty when runner is not allowed to pick untagged jobs"]}}' ; }

  config_toml='./test_config.toml'

  cat > "$config_toml" <<EOF
foo bar foo bar
this line has ##TOKEN## in it
baz qux baz qux
EOF

  runners_ssm_token_key='/mykey'
  aws_region='ap-southeast-2'
  runners_url='https://gitlab.com'
  gitlab_runner_registration_token='XXXXXXXX'
  gitlab_runner_description='my runner'
  gitlab_runner_locked_to_project='true'
  gitlab_runner_maximum_timeout='10'
  gitlab_runner_access_level='debug'
  gitlab_runner_log_group_name='gitlab-runner-log-group'

  register_runner

  assertTrue "$config_toml has been unexpectedly edited" "grep -q '##TOKEN##' $config_toml"

  rm -f "$config_toml"
}
```

A quick note about these lines:

```bash
runners_ssm_token_key='/mykey'
aws_region='ap-southeast-2'
runners_url='https://gitlab.com'
gitlab_runner_registration_token='XXXXXXXX'
gitlab_runner_description='my runner'
gitlab_runner_locked_to_project='true'
gitlab_runner_maximum_timeout='10'
gitlab_runner_access_level='debug'
gitlab_runner_log_group_name='gitlab-runner-log-group'
```

These are all variables that are expected to be interpolated by Terraform itself in the generated Bash UserData script. But, because Terraform's notation is valid Bash code too, I can set global Bash variables for the values I expected Terraform to place there, and still know I'm testing the same code.

This second test, by the way, is really just documenting a known way that this automation can fail. If it does fail in this way, the user of the Terraform module will be thankful for this test that explains what went wrong.

### Running the tests

Another advantage of the tests is the user, on running them, sees what the expected output is from this UserData script:

```text
▶ bash shunit2/test_user_data.sh
testConfigureCloudwatch
testRegisterRunnerTokenNull
{"Version":"1"}
testRegisterRunnerWithError
Received the following error:
{"message":{"tags_list":["can not be empty when runner is not allowed to pick untagged jobs"]}}

Ran 3 tests.

OK
```

## Testing the tests

Ok. Let's prove that these tests add value. I want to refactor something. There is something I don't like about this code here:

```bash
read -r instance_id region <<< "$(
  curl -s http://169.254.169.254/latest/dynamic/instance-identity/document \
    | jq -r '[.instanceId, .region] | @tsv'
)"
```

The `@tsv` is a bit confusing. I find `join()` to be more readable. So I want to refactor this as:

```bash
read -r instance_id region <<< "$(
  curl -s http://169.254.169.254/latest/dynamic/instance-identity/document \
    | jq -r '[.instanceId, .region] | join(" ")'
)"
```

So I make that change:

```diff
diff --git a/template/user-data.sh.tpl b/template/user-data.sh.tpl
index 8507c6e..6f6d529 100644
--- a/template/user-data.sh.tpl
+++ b/template/user-data.sh.tpl
@@ -23,7 +23,7 @@ configure_cloudwatch() {

   read -r instance_id region <<< "$(
     curl -s http://169.254.169.254/latest/dynamic/instance-identity/document \
-      | jq -r '[.instanceId, .region] | @tsv'
+      | jq -r '[.instanceId, .region] | join(" ")'
   )"

   cat > "$awslogs_conf" <<EOF
```

And run the tests again:

```text
▶ bash shunit2/test_user_data.sh
testConfigureCloudwatch
testRegisterRunnerTokenNull
{"Version":"1"}
testRegisterRunnerWithError
Received the following error:
{"message":{"tags_list":["can not be empty when runner is not allowed to pick untagged jobs"]}}

Ran 3 tests.

OK
```

Great. My change is good and I can commit that and not worry about expensive end-to-end testing.

## Summary

In this post, I have documented a method of testing Terraform UserData scripts using shUnit2. This post could be read as a second part to my earlier post, [Unit testing a Bash script using shUnit2](https://alexharv074.github.io/2017/07/07/unit-testing-a-bash-script-with-shunit2.html), in so far as it shows how to do unit testing in Bash where the units are functions instead of scripts. I also have shown some Terraform-specific tricks for best practices with Bash `user_data` scripts.

## See also

My earlier posts on shUnit2:

- Jul 7, 2017, [Unit Testing a Bash Script with shUnit2](https://alexharv074.github.io/2017/07/07/unit-testing-a-bash-script-with-shunit2.html).
- Sep 7, 2018, [Testing AWS CLI scripts in shUnit2](https://alexharv074.github.io/2018/09/07/testing-aws-cli-scripts-in-shunit2.html).

And see also my Placebo library on GitHub, [Placebo for Bash](https://github.com/alexharv074/bash_placebo).
