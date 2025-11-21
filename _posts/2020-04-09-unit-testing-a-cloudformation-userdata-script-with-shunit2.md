---
layout: post
title: "Unit testing a CloudFormation UserData script with shunit2"
date: 2020-04-09
author: Alex Harvey
tags: shunit2 cloudformation
---

This post adapts the method I documented [earlier](https://alex-harvey-z3q.github.io/2020/01/31/unit-testing-a-terraform-user_data-script-with-shunit2.html) for unit testing a Terraform user_data script to CloudFormation.

- Toc
{:toc}

## Introduction

In an earlier post, I documented a method for unit testing a Terraform user_data script using the shUnit2 Bash unit testing framework. Here, I adapt that method to test CloudFormation. I assume that the user uses CloudFormation YAML templates, although it would be trivial to adapt this to CloudFormation JSON. In this post, I use a simple CloudFormation and Bash example, and focus on the test boilerplate and set up.

## Why test

I think that almost no one out there is, at the time of writing, unit testing their CloudFormation Bash scripts, and some will wonder, why would I bother? I included this section in the previous post, and I can never say it too often: these are some of the reasons why unit testing is important:

|Use case|UserData example|
|--------|-----------------|
|Safely refactor code|Minor style improvements to a Bash UserData script should not require expensive end-to-end tests.|
|Quickly test complex Bash one-liners or complex logic|Some common examples include testing `jq`, `sed`, and `awk` one-liners.|
|Unit tests often force best practices on the code author|Badly-written Bash code is often not testable. Unit tests force this code to be refactored.|
|Unit tests provide a layer of code-as-documentation that otherwise would not exist|If a `jq` command is unreadable, for example, the tests for this will assist the reader understand what it does.|

## Sample CloudFormation code

The example I have written for this post is a simple EC2 instance stack that installs and configures Apache. It doesn't do anything terribly complicated, and in real life, I probably would not bother to unit test something as simple. But it is fine for an example. Here it is:

```yaml
---
AWSTemplateFormatVersion: 2010-09-09
Description: Apache stack

Parameters:
  BucketName:
    Type: String

Resources:
  EC2Instance:
    Type: AWS::EC2::Instance
    Properties:
      ImageId: ami-08589eca6dcc9b39c
      InstanceType: t2.micro
      KeyName: default
      UserData:
        Fn::Base64:
          !Sub |
            #!/usr/bin/env bash
            index='/var/www/html/index.html'

            update_system() {
              yum -y update
            }

            configure_apache() {
              yum -y install httpd
              service httpd start
              chkconfig httpd on
              aws s3 cp s3://"${BucketName}" /var/www/html -recursive
            }

            configure_index_html() {
              echo "<h1>Deployed via CloudFormation!</h1>" | tee "$index"
            }

            main() {
              update_system
              configure_apache
              configure_index_html
            }

            if [ "$0" == "${!BASH_SOURCE[0]}" ] ; then
              main
            fi

Outputs:
  PublicIp:
    Description: Public IP
    Value: !GetAtt EC2Instance.PublicIp
    Export:
      Name: !Sub "${AWS::StackName}-PublicIp"
```

## Sample code on GitHub

The source code for this blog post can be found online [here](https://github.com/alex-harvey-z3q/cloudformation-unit-test-example).

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
├── cloudformation.yml
└── shunit2
    └── test_user_data.sh
```

### Installing yq

The method I document here also has a dependency in the [`yq`](https://github.com/mikefarah/yq) command. On Mac OS X, it can be installed via Home Brew:

```text
▶ brew install yq
```

### Test boilerplate

Before I can test the embedded UserData script, I need to extract it. I can use `yq` to extract the script. But I also need to handle CloudFormation's [`Fn::Sub`]() intrinsic function's exclamation point notation for literal variable interpolation:

> To write a dollar sign and curly braces (${}) literally, add an exclamation point (!) after the open curly brace, such as ${!Literal}. AWS CloudFormation resolves this text as ${Literal}.

I can deal with that using a `sed` one-liner. So I begin with the following test boilerplate:

```bash
#!/usr/bin/env bash

cloudformation_yml='cloudformation.yml'
user_data_path='.Resources.EC2Instance.Properties.UserData."Fn::Base64"'

oneTimeSetUp() {
  yq -r "$user_data_path" "$cloudformation_yml" | sed -E '
    s/\${!([^}]*)}/${\1}/g
  ' > temp.sh
}

oneTimeTearDown() {
  rm -f temp.sh
}

. shunit2
```

So as a oneTimeSetUp, I extract the embedded script using `yq` and `sed`, and save it in `temp.sh`. And at the end of my suite, I delete that file again to clean up. This boilerplate is excutable already by the way. Here goes:

```text
▶ bash shunit2/test_user_data.sh

Ran 0 tests.

OK
```

### Testing bash -n

The simplest test I can do is simply check that the embedded script satisfies `bash -n` which means it may be syntactically ok. So I add `testMinusN`:

```bash
testMinusN() {
  assertTrue "bash -n returned an error" "bash -n temp.sh"
}
```

### Testing ShellCheck

I can (and should!) also run the generated script through ShellCheck. Here is that one:

```bash
testShellCheck() {
  local exclusions='SC2154'
  shellcheck --exclude="$exclusions" temp.sh
  assertTrue "ShellCheck returned an error" "$?"
}
```

### Unit tests

Now to do some real unit tests. Well actually there is not much to test, but for fun let's test the `configure_index_html` function anyway. The source code again for that function:

```bash
index='/var/www/html/index.html'

configure_index_html() {
  echo "<h1>Deployed via CloudFormation!</h1>" | tee "$index"
}
```

So the function just prints some text into a file `$index` which is a variable defined outside of this function. I do it this way to make the function testable. Without that variable, this function would write into the real file in `/var/www/html/index.html`, and that won't exist in my unit test environment. So here's the unit test:

```bash
testConfigureIndexHtml() {
  . temp.sh
  index='./test_index.html'
  configure_index_html > /dev/null
  assertTrue "$index did not contain expected pattern" \
    "grep -q CloudFormation $index"
  rm -f "$index"
}
```

### Running the tests

Now finally to run these tests:

```text
▶ bash shunit2/test_user_data.sh
testMinusN
testShellCheck
testConfigureIndexHtml

Ran 3 tests.

OK
```

## Discussion

There is not much to add that I did not cover in the earlier Terraform post. The method I've documented here has simple setup code for extracting the embedded scripts, is easy enough to understand, and is therefore as maintainable as long as the embedded shell script and the unit tests themselves are maintainable. And of course, this method here can be used to just run say ShellCheck if something easier than full unit testing is desired. I hope this is useful and encourages more people to unit test their Bash code using shunit2!

## See also

My earlier posts on shUnit2:

- Jul 7, 2017, [Unit Testing a Bash Script with shUnit2](https://alex-harvey-z3q.github.io/2017/07/07/unit-testing-a-bash-script-with-shunit2.html).
- Sep 7, 2018, [Testing AWS CLI scripts in shUnit2](https://alex-harvey-z3q.github.io/2018/09/07/testing-aws-cli-scripts-in-shunit2.html).
- Jan 31, 2020, [Unit testing a Terraform user_data script with shUnit2](https://alex-harvey-z3q.github.io/2020/01/31/unit-testing-a-terraform-user_data-script-with-shunit2.html).

And see also my Placebo library on GitHub, [Placebo for Bash](https://github.com/alex-harvey-z3q/bash_placebo).
