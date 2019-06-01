---
layout: post
title: "Testing AWS CLI scripts in shUnit2"
date: 2018-09-07
author: Alex Harvey
tags: aws shunit2
---

In this post, I document a pattern of unit testing AWS CLI shell scripts in the shUnit2 framework.

{:toc}

## Overview

In a nutshell, I describe a method here for testing the logic and behaviour of simple shell scripts that use the Python AWS CLI. And, although my target audience is the DevOps engineer using the AWS CLI, the method can obviously be extended to applications that have nothing to do with AWS.

I make a couple of assumptions. The first is that the script-under-test is simple and short and does not require its own file system. For instance, I assume that it does not redirect STDOUT into /var and so on. A script like that would require a fake filesystem to be available i.e. it would need to run in a BSD jail, Docker etc. Secondly, I assume that commands to be mocked are not addressed by their full path. Although, if they are, such scripts can usually be refactored to utilise `$PATH`.

Other dependencies usually have to be satisfied too. For instance, if the tests are expected to run on Mac OS X, whereas the script in production runs on Amazon Linux, it is sometimes necessary to ensure that both environments have the same versions of GNU utilities, etc.

## Code example

The sample code is a simple script that deletes CloudFormation stacks and related deployment artifacts.

```bash
#!/usr/bin/env bash

usage() {
  echo "Usage: $0 STACK_NAME S3_BUCKET"
  exit 1
}

delete_all_artifacts() {
  aws ec2 delete-key-pair \
    --key-name "$stack_name"
  aws s3 rm --recursive --quiet \
    s3://"$s3_bucket"/deployments/"$stack_name"
}

resume_all_autoscaling_processes() {
  asgs=$(aws cloudformation describe-stack-resources \
    --stack-name "$stack_name" \
    --query \
'StackResources[?ResourceType==`AWS::AutoScaling::AutoScalingGroup`].PhysicalResourceId' \
    --output text)

  for asg in $asgs
  do
    aws autoscaling resume-processes \
      --auto-scaling-group-name "$asg"
  done
}

[ $# -ne 2 ] && usage
read -r stack_name s3_bucket <<< "$@"

delete_all_artifacts
resume_all_autoscaling_processes

aws cloudformation delete-stack \
  --stack-name "$stack_name"
```

(Note: all of the code for this blog post is available at Github [here](https://github.com/alexharv074/shunit2_example.git). The reader can step through the revision history to see the examples before and after the refactoring.)

As can be seen, this script does these things:

- validates the inputs
- deletes a key pair and deployment artifacts
- resumes any suspended processes in auto-scaling groups
- deletes the CloudFormation stack specified in the inputs.

## Designing the tests

To provide complete unit test coverage, I need the following test cases:

- a usage message is expected if incorrect inputs are passed
- for a stack with no auto-scaling groups:
    * key pairs and deployment artifacts are expected to be deleted
    * aws cloudformation delete-stack should be issued
- for a stack with multiple auto-scaling groups:
    * a resume-processes command should be issued for each auto-scaling group.

Also, it is a known issue with the script that it doesn't try to handle a non-existent S3 bucket and a non-existent CloudFormation stack. To remedy this I can choose between:

- documenting this as a known issue
- fixing the script to be more defensive (recommended!)
- or writing tests to test for and demonstrate the known issue.

For the purpose of this blog post, I want the script and tests to be short and simple, so I leave it as-is.

## Structure of the project

The convention I have adopted is to create a directory `shunit2` in the root of the project and name the test files the same as the scripts that they test. In this example I have:

```text
▶ tree .
.
├── delete_stack.sh
└── shunit2
    └── delete_stack.sh
```

The tests are expected to be also run from the root of the project, like this:

```text
▶ bash shunit2/delete_stack.sh
```

To locate the script-under-test, I have a line like this at the start of every test file:

```bash
script_under_test=$(basename "$0")
```

## Installing shUnit2 > 2.1.7

At the time of writing, the method I describe here depends on a patched version of shUnit2 that is only available in shUnit2 pre-2.1.8. The method was tested using [this](https://github.com/kward/shunit2/blob/6d17127dc12f78bf2abbcb13f72e7eeb13f66c46/shunit2) version that I took from the master branch.

So, to install, something like this would be required:

```text
▶ curl \
    https://raw.githubusercontent.com/kward/shunit2/6d17127dc12f78bf2abbcb13f72e7eeb13f66c46/shunit2 \
    -o /usr/local/bin/shunit2
```

Or, if shUnit2 2.1.8 is released, then (on a Mac) try:

```text
▶ brew install shunit2
```

## Installing DiffHighlight (optional)

Also used just for prettifying diff output (see below) is `DiffHighlight.pl`. This is a slightly-modified version of [diff-highlight](https://github.com/git/git/tree/master/contrib/diff-highlight), which is part of Git.

```text
▶ curl \
    https://raw.githubusercontent.com/alexharv074/scripts/master/DiffHighlight.pl \
    -o /usr/local/bin/DiffHighlight.pl
```

## Structure of the tests

The test file `shunit2/delete_stack.sh` has five parts:

1. the variable `$script_under_test` as mentioned above
2. a mocks section where I replace commands that make calls to AWS with mocks that return canned responses
3. a more general setup / teardown section
4. some test cases, being the shell functions whose names start with `test*`
5. the final call to shUnit2 itself.

## About the mocks

In general, the testing method works when the calls to Linux external commands (and even to internal, built-in shell commands) can be divided cleanly into commands related to the internal logic of the script, and commands related to the external behaviour of the script, i.e. to the things it changes or whatever it actually does.

I reiterate that some scripts simply can't be tested by this method. Some probably can't be unit tested by any method. Sometimes the setup required is far more complicated than the script itself, and it just makes no sense to test it. Often, though, shell scripts can be tested, and certainly the script discussed here can.

The mocks follow a pattern, and indeed I intend to publish a script, similar to the Python [Placebo](https://github.com/garnaat/placebo) library, for recording and playing back AWS CLI responses as mocks. Until then, I simply note that a mock that just silently intercepts and logs the inputs passed into it looks like:

```bash
some_command() {
  echo "${FUNCNAME[0]} $*" >> commands_log
}
```

The variable `${FUNCNAME[0]}` in Bash is the name of a function. Use of this pattern (actually not used in this example script) allows me to quickly copy/paste mocks from other mocks. E.g.

```bash
chmod() {
  echo "${FUNCNAME[0]} $*" >> commands_log
}

chown() {
  echo "${FUNCNAME[0]} $*" >> commands_log
}

...
```

More complicated mocks that also respond with fake responses programmed into them then look like:

```bash
some_command() {
  echo "${FUNCNAME[0]} $*" >> commands_log
  case "${FUNCNAME[0]} $*"
    "${FUNCNAME[0]} some_arg_a some_arg_b") ; echo some_response_1 ;;
    "${FUNCNAME[0]} some_arg_c some_arg_d") ; echo some_response_2 ;;
  esac
}
```

And the `tearDown` function provided by shUnit2 is later expected to clean up the `commands_log`:

```bash
tearDown() {
  rm -f commands_log
}
```

## About the commands log

The `commands_log` created by the mocks can be queried to make assertions about the script's actual behaviour. This becomes clearer below.

## Test cases

### Simplest example

In the simplest test case, I just call the script with some fake inputs, and then assert that the actual contents of `commands_log` after the script runs matches expected content. My test file looks like this:

```bash
#!/usr/bin/env bash

# section 1 - the script under test.
script_under_test=$(basename "$0")

# section 2 - the mocks.
aws() {
  echo "aws $*" >> commands_log
  case "aws $*" in
    "aws ec2 delete-key-pair --key-name mystack") true ;;
    "aws s3 rm --recursive --quiet s3://mybucket/deployments/mystack") true ;;

    "aws cloudformation describe-stack-resources \
--stack-name mystack \
--query "'StackResources[?ResourceType==`AWS::AutoScaling::AutoScalingGroup`].PhysicalResourceId'" \
--output text")
      echo mystack-AutoScalingGroup-xxxxxxxx
      ;;

    "aws autoscaling resume-processes \
--auto-scaling-group-name mystack-AutoScalingGroup-xxxxxxxx")
      true
      ;;

    "aws cloudformation delete-stack --stack-name mystack") true ;;
    *) echo "No response for >>> aws $*" ;;
  esac
}

# section 3 - other setup or teardown.
tearDown() {
  rm -f commands_log
  rm -f expected_log
}

# section 4 - the test cases.
testSimplestExample() {
  . "$script_under_test" mystack mybucket

  cat > expected_log <<'EOF'
aws ec2 delete-key-pair --key-name mystack
aws s3 rm --recursive --quiet s3://mybucket/deployments/mystack
aws cloudformation describe-stack-resources --stack-name mystack --query StackResources[?ResourceType==`AWS::AutoScaling::AutoScalingGroup`].PhysicalResourceId --output text
aws autoscaling resume-processes --auto-scaling-group-name mystack-AutoScalingGroup-xxxxxxxx
aws cloudformation delete-stack --stack-name mystack
EOF

  assertEquals "unexpected sequence of commands issued" \
    "" "$(diff -wu expected_log commands_log | colordiff | DiffHighlight.pl)"
}

# section 5 - the call to shUnit2 itself.
. shunit2
```

The test case here just calls the script with some fake inputs. The mocks intercept the AWS CLI calls and write their command line into the log file, and then the shunit2 `assertEquals` function is called to assert that the actual log file equals the expected log.

The `assertEquals` function takes three arguments: a message to be seen only during failures (optional); an expected string; and the actual string. The shUnit2 framework is just like jUnit, Python unittest etc.

The complicated call to `diff -wu` ensures that during failures, a nice readable unified diff of "expected" compared to "actual" is seen. This is because I found over time that the default shUnit2 output that compares two multiline strings is not easy to read at all. The use of `DiffHighlight.pl` helps a great deal by further highlighting the character-level diffs.

Notice also that we _source_ the script into the running shell rather than executing it in its own process. This way, the mocks and other setup can alter its behaviour in the test environment.

### Testing bad inputs

To add an example to ensure that the script errors out as expected when passed in bad inputs:

```bash
testBadInputs() {
  actual_stdout=$(. "$script_under_test" too many arguments passed)
  assertTrue "unexpected response when passing bad inputs" \
    "echo $actual_stdout | grep -q ^Usage"
}
```

Notice here that the STDOUT is captured using command substitution `$( ... )` and an assertion is made about the content of that string.

### Testing a stack with no auto-scaling groups

Another possibility is that a user tries to delete a stack that has no auto-scaling groups. If so, the `aws cloudformation describe-stack-resources` command returns an empty string and I expect that to cause the `for` loop over an empty string to be simply skipped.

So, I end up with a new sequence of mocks which I probably collected from a different stack during manual testing, like this:

```bash
aws() {
  ...
  # responses for myotherstack.
  "aws ec2 delete-key-pair --key-name myotherstack") true ;;
  "aws s3 rm --recursive --quiet s3://mybucket/deployments/myotherstack") true ;;

  "aws cloudformation describe-stack-resources \
--stack-name myotherstack \
--query "'StackResources[?ResourceType==`AWS::AutoScaling::AutoScalingGroup`].PhysicalResourceId'" \
--output text")
    echo ""  ## Manual testing revealed that this command returns an empty string in this situation.
    ;;

  "aws cloudformation delete-stack --stack-name myotherstack") true ;;
}
```

And I write another test case that looks like this:

```bash
testNoASGs() {
  . "$script_under_test" myotherstack mybucket
  assertFalse "a resume-processes command was unexpectedly issued" \
    "grep -q resume-processes commands_log"
}
```

## Running the tests

To run the tests:

```text
▶ bash shunit2/delete_stack.sh
testSimplestExample
testBadInputs
testNoASGs

Ran 3 tests.

OK
```

## Discussion

At this point, I anticipate some objections to the method.

### Are the tests brittle?

I don't think so. I think the tests are describing, if somewhat verbosely, the behaviour of the script that we care about. And if the behaviour changes, then the tests should change too, and this is true of all unit tests.

At first glance, I felt that the tests were overly prescriptive, in that an exact sequence of commands is expected that permits no variation. But on thinking about it more, the only legitimate way to break the tests that I could think of, without also breaking the script, is to change the ordering. Someone might change the ordering so that, say, the deployment artifacts are deleted after the stack is deleted instead of before. And I could make the tests more robust by sorting the expected and actual commands log so that the order is no longer relevant. But I can't think of any good reason why someone would change the ordering.

Could Amazon change the format of the output of their CLI commands? I don't think so. It would break everyone's scripts.

### Overly verbose

Rather than overly prescriptive and brittle, I think the tests are overly verbose. It is ugly to have reproduced the entire log of commands, character-for-character - and I think that is the biggest problem with these tests, and on the other hand it is also useful. Someone trying to understand the script can look at these tests and quickly understand what the script actually does. So I am in two minds on this aspect of the implementation.

### Test-first development not possible

A consequence of the need to capture the outputs of real AWS CLI commands is that test-first development is really not possible. And while this point may upset some TDD purists, I must say I don't always write tests first anyway, and I have never been convinced that tests _must_ be always written first - or indeed at all.

### Method cannot be generalised

The biggest problem with the method, in my view, is that it cannot be generalised to all shell scripts. As mentioned, some scripts make assumptions about the filesystem (think of `some_command >> /var/log/some_log`; how can a script that does that be tested?); others make calls to commands using full paths (although it is usually better style to refactor these scripts to utilise an edited `$PATH` in any case); and sometimes, the set-up and tear-down required to test the behaviour result in tests that are far more complicated than the script being tested.

### Is it worth it then?

All things considered, still - for me - this layer of unit testing shell scripts is definitely worth the effort, when it is possible to do so. I see automated testing as adding value that goes well beyond just the testing of code. It is also a method of analysis. The tests allow me, whether as the author or maintainer of a script, to understand and reason about its behaviour in a way that just isn't possible in the absence of the unit tests.

Imagine that the tests documented above did not exist. If so, no one, no matter how experienced in the AWS CLI, could possibly be expected to know, without additional research, what the response from a command like this would look like:

```text
aws cloudformation describe-stack-resources \
  --stack-name mystack \
  --query "'StackResources[?ResourceType==`AWS::AutoScaling::AutoScalingGroup`].PhysicalResourceId'" \
  --output text
```

Few would know even if it is a valid command, much less that it might return a list of strings like:

```text
mystack-AutoScalingGroup-xxxxxxxx
mystack-AutoScalingGroup-yyyyyyyy
```

The tests and mocks document all this. I refer to tests all the time for all sorts of things.

Furthermore, the tests do allow me to refactor the code with confidence. If I want to clean up the code with better spacing, line breaks, better variable or function names, I can do all that and be 100% confident due to complete unit test coverage that I have not broken anything.

## Conclusion

I have documented here a method for unit testing AWS CLI scripts that I have used for a while. I would welcome feedback on the idea, especially from others who have experience with unit testing shell scripts.

## Further reading

- James Sanderson, [Bourne shell unit testing](https://github.com/zofrex/bourne-shell-unit-testing).
