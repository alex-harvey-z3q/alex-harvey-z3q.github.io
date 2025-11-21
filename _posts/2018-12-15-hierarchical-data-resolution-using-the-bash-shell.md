---
layout: post
title: "Hierarchical data lookups using the Bash shell"
date: 2018-12-15
author: Alex Harvey
tags: bash
---

This post documents a pattern of hierarchical data lookups similar to Puppet's Hiera using only the Bash shell.

* Table of contents
{:toc}

## Overview

Shell scripts are a fact of life and it is hard to imagine a technological future that has no role for the Bash shell, whether in Dockerfiles, UserData scripts, CI/CD pipelines, and so on. Another common use-case for the Bash shell is wrapper scripts around Packer bakes and AWS CloudFormation stacks.

But what do you do about data?

Configuration management solutions like Puppet, Chef and Ansible all support externalised data in YAML files that are looked up hierarchically. The idea began with Puppet's Hiera and the basic idea of hierarchical lookups is now standard. Hiera uses an ordered hierarchy to look up data, which allows you to have a large amount of common data and override smaller amounts on the basis of variables called "facts".

This post shows how to implement a hierarchical organisation of data in the same way in Bash, using bash variables instead of facts.

## Example project

An example project to go with this blog post is online at Github [here](https://github.com/alex-harvey-z3q/hiera-in-bash.git). It was forked from [this](https://github.com/awslabs/ami-builder-packer) AWS Labs project. It is a very simple project that bakes an EC2 AMI using Packer, with different data for some parameters in dev, test and prod environments.

(This example project could be used as the starting point for any project that intends to manage Packer or CloudFormation or similar using shell scripts as wrappers. It is complete with a Makefile, unit tests and so on.)

## Build script

The example build script that bakes the AMI is as follows:

```bash
#!/usr/bin/env bash

. data.sh

date=$(date +%Y%m%d%H%M%S)

cat > variables.json <<EOF
{
  "vpc": "$vpc_id",
  "subnet": "$subnet_id",
  "aws_region": "$aws_region",
  "owner": "$owner",
  "date": "$date",
  "instance_type": "$instance_type"
}
EOF
jq . variables.json > /dev/null || exit "$?"

for action in validate build ; do
  packer "$action" -var-file=variables.json \
    packer.json || exit "$?"
done

rm -f variables.json
```

The line `. data.sh` is where I source my data. This is the subject of the blog post, and I'll come back to that in a moment, but for now I'd like to note that this is a simple script that gets the date, builds a Packer variables JSON file, validates the Packer template, and then builds an AMI. Also note that a bunch of variables are passed into Packer, some of which are environment-specific - like the VPC, Subnet, Owner and Instance Type - and others are the same for all environments - such as the region.

The Hiera-like magic is inside the `data.sh` script. In the sections below, I'll relate this script and its features to Puppet's Hiera.

## data.sh

The `data.sh` script is similar to Puppet's `hiera.yaml` file. A simple piece of Bash code, it defines the data hierarchy and the variables it depends on:

```bash
#!/usr/bin/env bash

usage() {
  echo "Usage: environment={dev|test|prod} . $0"
  exit 1
}
[ -z "$environment" ] && usage

data_dir=./data

if [ ! -e "$data_dir"/environment/"$environment".sh ]; then
  echo "Data file $data_dir/environment/${environment}.sh not found"
  usage
fi

# Hierarchy.
. "$data_dir"/common.sh
. "$data_dir"/environment/"$environment".sh
```

Aside from some error-checking, the file defines a hierarchy of lookups. Firstly, the `common.sh` file is sourced into the running shell. Next, an environment-specific file is sourced.

(The error-checking isn't really necessary, but I put it there in case someone wants to call `data.sh` directly for testing. See below for an example of that.)

## Environment variables as facts

Whereas in Puppet, facts are used as inputs to the hierarchy, I have used environment variables. Of course, I could use any kind of variable or external command.

## Data files

The data files are also just sourced Bash code. For instance:

```bash
# data/environment/dev.sh
vpc_id='vpc-11111111'
subnet_id='subnet-11111111'
owner='123456789012'
```

## Overrides

What about overrides?

Due to the normal behaviour of Bash, variables defined in the lower levels of the hierarchy will "clobber" variables defined in the higher levels. This works simply because a variable in Bash that gets defined twice in your code keeps the value defined most recently - naturally. And, if you want the opposite behaviour - say, you want the variables in common to take precedence - you can just change the order. Again, this is similar to how Hiera works<sup>1</sup>.

Thus:

```text
▶ grep -r instance_type data
data/common.sh:instance_type='t2.micro'
data/environment/prod.sh:instance_type='t2.large'
```

## Testing lookups

Or, I could test the lookup behaviour more directly:

```text
▶ environment=dev . ./data.sh ; echo $instance_type
t2.micro
```

```text
▶ environment=prod . ./data.sh ; echo $instance_type
t2.large
```

## Secrets?

Chances are if you're using Bash to bake an AMI with Packer or something similar, you already a CLI tool like SSM. So, although I didn't need it in this example project, there is no reason why I can't have a line like:

```bash
# data/environment/prod.sh
admin_password=$(aws ssm get-parameter --name ${admin_password} \
  --query Parameter.Value --with-decryption --output text)
```

And if I had to do that a lot I could wrap it in a function inside `data.sh` like:

```bash
query_ssm() {
  local param="$1"
  local prev="$-" ; set +x # Prevent set -x from leaking secrets.
  aws ssm get-parameter --name "$param" \
    --query 'Parameter.Value' --with-decryption --output 'text'
  set -"$prev"
}
```

And:

```bash
# data/environment/prod.sh
admin_password=$(query_ssm 'admin_password')
```

## Other thoughts

This approach has a number of advantages:

- Clean separation of data and code. The `build.sh` script is not cluttered with messy code that sets variables and the variables meanwhile are all in one place and their values easily worked out for each environment just by using grep.
- No external tools required. I didn't need to bolt on any external data store but just used features built in to the Bash shell. In fact, there's not even any need to read YAML or JSON.
- A full programming language available in the data files. Puppet's Hiera has a lot of features to be sure, like interpolation functions, aliases and so on, whereas all of Bash is available in one of these data files, so that's quite powerful too.

How about structured data? Well to the extent that structured data is supported in Bash, then it is supported in this model too. But obviously, you won't be using Bash in the first place if you need nested dictionaries of data in your scripts. So this is fine.

## Conclusion

I have documented a pattern for externalising data in Bash for use-cases like wrapper scripts for Packer and CloudFormation. The model is quite similar to Puppet's Hiera and Chef's data bags and so on. Feel free to let me know if you decide to use this approach!

<sup>1</sup> Actually, in Hiera, you would put the environment-specific level at the top and the common level at the bottom. Hiera searches each level in order until it finds the key it was looking for and then returns.
