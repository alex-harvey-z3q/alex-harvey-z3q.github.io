---
layout: post
title: "Using Placebo for Bash to auto-generate mocks in unit tests"
date: 2018-09-18
author: Alex Harvey
tags: bash placebo
---

This post shows how to use my [Bash Placebo](https://github.com/alexharv074/bash_placebo) library, inspired by Mitch Garnaat's [Python Placebo](https://github.com/garnaat/placebo) library, to unit test Bash scripts that use the AWS CLI.

* Table of contents
{:toc}

## Introduction

This post is a sequel to, and should be read in conjunction with, an earlier [post](https://alexharv074.github.io/2018/09/07/testing-aws-cli-scripts-in-shunit2.html), where I documented a method for unit testing AWS CLI scripts in shunit2.

The earlier post focused on setting up and using shunit2, whereas this one focuses on the Placebo library that I have just released. This post is a Bash Placebo tutorial.

As with the Python Placebo library, Bash Placebo is a tool for recording and playing back responses from AWS as mocks. The Bash library should feel familiar to users of the Python library.

## Code example

The sample code under test is the same simple script for deleting CloudFormation stacks that was used in the previous post:

~~~ bash
#!/usr/bin/env bash

usage() {
  echo "Usage: $0 STACK_NAME S3_BUCKET"
  exit 1
}

delete_all_artifacts() {
  aws ec2 delete-key-pair \
    --key-name ${stack_name}
  aws s3 rm --recursive --quiet \
    s3://${s3_bucket}/deployments/${stack_name}
}

resume_all_autoscaling_processes() {
  asgs=$(aws cloudformation describe-stack-resources \
    --stack-name $stack_name \
    --query \
'StackResources[?ResourceType==`AWS::AutoScaling::AutoScalingGroup`].PhysicalResourceId' \
    --output text)

  for asg in $asgs
  do
    aws autoscaling resume-processes \
      --auto-scaling-group-name $asg
  done
}

[ $# -ne 2 ] && usage
read -r stack_name s3_bucket <<< "$@"

delete_all_artifacts
resume_all_autoscaling_processes

aws cloudformation delete-stack \
  --stack-name ${stack_name}
~~~

As with the earlier article, the code is available at Github [here](https://github.com/alexharv074/shunit2_example.git), whereas changes that were added to integrate with Placebo were added in [this](https://github.com/alexharv074/shunit2_example/commit/724c93f6c5d87fbd7c823afad607769e646dc6f6) commit.

## Installing Placebo

The Placebo library, like shunit2, is just one file. At the moment, therefore, it can be installed by simply copying the script into the PATH somewhere:

~~~ text
▶ curl -o /usr/local/bin/placebo \
    https://raw.githubusercontent.com/alexharv074/bash_placebo/master/placebo
~~~

## Recording and playing back responses

Before launching into a unit testing demo, I will show how to record and play back responses on the command line. Then, in the following section, I will show specifically how to record responses for unit tests.

To get started, it is necessary to firstly source the library into the running shell:

~~~ text
▶ . placebo
~~~

I assume, of course, that the running shell is Bash. Unlike shunit2, it won't work in Zsh etc. Sorry. If there's demand, I may look at refactoring in order to support Zsh and other shells.

Sourcing the library into the running shell causes the `pill*` functions to be installed, as well as an `aws` function that will take the place of the external aws command.

Immediately after sourcing Placebo, however, the aws command is broken. This is expected:

~~~ text
▶ aws
DATA_PATH must be set. Try pill_attach
~~~

So I "attach" the Placebo "pill":

~~~ text
▶ pill_attach command=aws data_path=shunit2/fixtures/aws.sh
~~~

The `pill_attach` function takes two arguments:

1. the `command=aws` argument is a feature that is not implemented. For now, it is always expected to be the literal string `command=aws`. It is there to provide a little bit of interface consistency with the Python library, and also allow for future generalisation of the library to support commands other than aws.
2. the second argument `data_path=path/to/responses.sh` is the path to the file to save responses in. Note the deviation from Python Placebo behaviour here: whereas in the Python library, `data_path` specifies a directory to store Boto3 responses in numbered JSON files, it made more sense in the Bash version to store the responses in a single file.

Having attached Placebo, I try again:

~~~ text
▶ aws
PILL must be set to playback or record. Try pill_playback or pill_record
~~~

So again I follow the instructions and set Placebo to record mode:

~~~ text
▶ pill_record
~~~

Now, if I try an aws command, things should work normally. For example:

~~~ text
▶ aws ec2 describe-vpcs --region ap-southeast-2 --query 'Vpcs[].VpcId'
[
    "vpc-07a59518ae4faa320"
]
~~~

That is a command that returns the VPC IDs of all my VPCs. The command appeared to run normally, but if I check the contents of my data file, I find that it also recorded a copy of the command and its response in there:

~~~ bash
case "aws $*" in
'aws ec2 describe-vpcs --region ap-southeast-2 --query Vpcs[].VpcId')
  cat <<'EOF'
[
    "vpc-07a59518ae4faa320"
]
EOF
  ;;
*)
  echo "No responses for: aws $*"
  ;;
esac
~~~

It also has saved a log of all commands issued. These can be revealed by the `pill_log` function:

~~~ text
▶ pill_log
aws ec2 describe-vpcs --region ap-southeast-2 --query Vpcs[].VpcId
~~~

(Under the hood, the responses are just saved in a plain file called `commands_log`. The command `cat commands_log` will also reveal the log.)

Next, I test that I can read the responses back again, this time by switching to playback mode and retrying:

~~~ text
▶ pill_playback
▶ aws ec2 describe-vpcs --region ap-southeast-2 --query 'Vpcs[].VpcId'
[
    "vpc-07a59518ae4faa320"
]
~~~

Unlike the previous run, where the real AWS was contacted, this response was instantanteous; so I know that the response came from the file, as expected.

Finally, we can clean up, and have the original aws command back by "detaching":

~~~ text
▶ pill_detach
▶ type aws
aws is /usr/local/bin/aws
~~~

## Recording responses for the script under test

To recap, the steps to attach Placebo and set it to record mode are:

~~~ text
▶ . placebo
▶ pill_attach command=aws data_path=shunit2/fixtures/aws.sh
▶ pill_record
~~~

Having set all this up, I can now source the script under test into the running shell and capture a log of all the commands it runs in the response file:

~~~ text
▶ . delete_stack.sh mystack mys3bucket
~~~

This script takes a few moments to run and generates no STDOUT, which is what I expected. When it finishes, I find that the list of AWS commands that it ran (which I will use in the test case as the expected log of commands) is available in the log:

~~~ text
▶ pill_log
aws ec2 delete-key-pair --key-name mystack
aws s3 rm --recursive --quiet s3://mys3bucket/deployments/mystack
aws cloudformation describe-stack-resources --stack-name mystack --query StackResources[?ResourceType==`AWS::AutoScaling::AutoScalingGroup`].PhysicalResourceId --output text
aws autoscaling resume-processes --auto-scaling-group-name mystack-AutoScalingGroup-1R0O5PP8YIVPZ
aws cloudformation delete-stack --stack-name mystack
~~~

Meanwhile, the responses have all been saved as a Bash case statement in shunit2/fixtures/aws.sh:

~~~ bash
case "aws $*" in
'aws ec2 delete-key-pair --key-name mystack')
  cat <<'EOF'
EOF
  ;;
'aws s3 rm --recursive --quiet s3://mys3bucket/deployments/mystack')
  cat <<'EOF'
EOF
  ;;
'aws cloudformation describe-stack-resources --stack-name mystack --query StackResources[?ResourceType==`AWS::AutoScaling::AutoScalingGroup`].PhysicalResourceId --output text')
  cat <<'EOF'
mystack-AutoScalingGroup-1R0O5PP8YIVPZ
EOF
  ;;
'aws autoscaling resume-processes --auto-scaling-group-name mystack-AutoScalingGroup-1R0O5PP8YIVPZ')
  cat <<'EOF'
EOF
  ;;
'aws cloudformation delete-stack --stack-name mystack')
  cat <<'EOF'
EOF
  ;;
*)
  echo "No responses for: aws $*"
  ;;
esac
~~~

Note that this auto-generated code is a bit messy, and I could choose to clean it up - it's just Bash code after all. But that's completely optional. The generated code will work fine.

Finally, for completeness, I detach again:

~~~ text
▶ pill_detach
~~~

## Playing responses back in tests

### New structure of the tests

When using Placebo, the structure of the test files changes slightly. Previously, I had noted that a test file has a structure with five sections:

- the variable `$script_under_test` as mentioned above
- a mocks section where I replace commands that make calls to AWS with mocks that return canned responses
- a more general setUp / tearDown section
- some test cases, being the shell functions whose names start with test*
- the final call to shUnit2 itself.

When using Placebo, however, the test files need only four sections:

- the variable `$script_under_test`
- a setUp section that attaches to Placebo before each test, and a tearDown section that detaches afterwards
- some test cases, being the shell functions whose names start with test*
- the final call to shUnit2 itself.

### Simplest test case

The simplest test case now looks like this:

~~~ bash
#!/usr/bin/env bash

# section 1 - the script under test.
script_under_test=$(basename $0)

# section 2 - setup and teardown.
setUp() {
  . placebo
  pill_attach command=aws data_path=shunit2/fixtures/aws.sh
  pill_playback
}

tearDown() {
  rm -f actual_log
  rm -f expected_log
  pill_detach
}

# section 3 - the test cases.
testSimplestExample() {
  . $script_under_test mystack mybucket

  cat > expected_log <<'EOF'
aws ec2 delete-key-pair --key-name mystack
aws s3 rm --recursive --quiet s3://mys3bucket/deployments/mystack
aws cloudformation describe-stack-resources --stack-name mystack --query StackResources[?ResourceType==`AWS::AutoScaling::AutoScalingGroup`].PhysicalResourceId --output text
aws autoscaling resume-processes --auto-scaling-group-name mystack-AutoScalingGroup-1R0O5PP8YIVPZ
aws cloudformation delete-stack --stack-name mystack
EOF
  pill_log > actual_log

  assertEquals "unexpected sequence of commands issued" \
    "" "$(diff -wu expected_log actual_log)"
}

# section 4 - the call to shUnit2 itself.
. shunit2
~~~

The lines for the expected_log I took directly from the `pill_log` function, and the file `shunit2/fixtures/aws.sh` was generated by `pill_record` as discussed above.

## Conclusion

All the rest, including designing the tests, extending to other test cases, and running the tests, are found in the earlier blog post, whereas I have only documented here how to use Placebo to record responses and play them back in your tests. And if Placebo is only required for playback - if, for instance, it is preferred to manually create the case statement inside the data file, the post shows how to do that too.

I am excited about the Placebo library, as it should significantly lower the barrier to entry for unit testing AWS CLI scripts. Just as I was excited when I first discovered the Python Placebo library (which I will write about in another post).

I would welcome feedback from any other AWS users who try out this library and to that end I am more than happy to help if anyone finds any issues. PRs, feature requests and bug reports also welcome.
