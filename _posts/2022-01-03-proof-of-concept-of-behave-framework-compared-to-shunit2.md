---
layout: post
title: "Proof of concept of behave framework compared to shunit2"
date: 2022-01-03
author: Alex Harvey
tags: behave shunit2
---

- ToC
{:toc}

## Introduction

I spent some time over the new year break learning the [behave](https://behave.readthedocs.io/en/stable/) integration testing framework and decided to do a little proof of concept to compare this to my own Bash plus shunit2 integration test patterns. In this post, I create a very simple CloudFormation stack and write integration tests in both frameworks to see which one seems simpler. I conclude that I still prefer Bash plus shunit2 for its simplicity.

## Sample code

To test out this framework I have created a simple CloudFormation stack as follows:

```yaml
Parameters:
  RetentionInDays:
    Type: Number
    Default: 1

Resources:
  LogGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      RetentionInDays: 1

Outputs:
  LogGroup:
    Value: !Ref LogGroup
    Export:
      Name: !Sub "${AWS::StackName}-LogGroup"
```

I am going to write tests for this in behave and then rewrite them in bash and shunit2.

## Behave

### What is behave

behave is a behaviour-driven development (BDD) framework. It is [cucumber](https://cucumber.io/) in Python. It uses Cucumber's [Gherkin syntax](https://cucumber.io/docs/gherkin/). Gherkin is said to be a natural readable language for expressing business logic without reference to the implementation detail.

Here is a sample of Gherkin:

```cucumber
Feature: Fight or flight

  In order to increase the ninja survival rate,
  As a ninja commander
  I want my ninjas to decide whether to take on an
  opponent based on their skill levels

  Scenario: Weaker opponent
    Given the ninja has a third level black-belt
     When attacked by a samurai
     Then the ninja should engage the opponent

  Scenario: Stronger opponent
    Given the ninja has a third level black-belt
     When attacked by Chuck Norris
     Then the ninja should run for his life
```

This allows us to express the feature as the Agile "story" that created it; and then a number of "scenarios" (test cases) that test and express the business logic. 

- *Given* we put the system in a known state before the user (or external system) starts interacting with the system (in the When steps). Avoid talking about user interaction in givens.
- *When* we take key actions the user (or external system) performs. This is the interaction with your system which should (or perhaps should not) cause some state to change.
- *Then* we observe outcomes.

### Installing behave

To get started, I create an empty project and add a requirements file:

```text
▶ tree .
.
├── loggroup.yml
└── requirements.txt
```

In there I add `behave` and `boto3`:

```text
▶ cat requirements.txt
boto3
behave
```

Create the virtualenv:

```text
▶ virtualenv env
. env/bin/activate
```

And install requirements:

```text
▶ pip install -r requirements.txt
```

### What to test

One of the advantages of the Gherkins syntax is that, if properly written, it is in plain English, and should not require additional explanation. So, I am going to test the following:

```cucumber
Feature: Log Group Stack

  In order to test out the behave framework,
  As a crazy tech blogger,
  I want a CloudFormation log group stack,
  so that I can test stuff in it.

  Scenario: Create Stack
    Given the stack 'test-stack1' does not exist
     When the user creates stack 'test-stack1' with template 'loggroup.yml' and parameters 'RetentionInDays=1'
     Then the stack 'test-stack1' will exist
     And the stack 'test-stack1' will have RetentionInDays of '1'
```

### Create the feature file

So I take that text and add it in a file `features/loggroup.feature`:

```text
▶ mkdir features
▶ tree .
.
├── features
│   └── loggroup.feature
├── loggroup.yml
└── requirements.txt
```

### Writing steps

Now I need some steps. A key insight in understanding the behave framework (and Cucumber) is that every line in a feature file must be written out as a decorated `step_impl` function in a steps file inside the `steps` directory. There can be any number of steps files, each one containing Python code, and named `*.py`. So I provide the following implementation for each line of the feature file I wrote:

```python
import boto3
from typing import List, Dict, Optional

client = boto3.client("cloudformation")


@given("the stack '{stack_name}' does not exist")
def step_impl(_, stack_name: str) -> None:
    client.delete_stack(StackName=stack_name)
    _wait(stack_name, "stack_delete_complete")


@when("the user creates stack '{stack_name}' with template '{template}' and parameters '{params_csv}'")
def step_impl(_, stack_name: str, template: str, params_csv: str) -> None:
    client.create_stack(
        StackName=stack_name,
        TemplateBody=_template_body(template),
        Parameters=_parameters(params_csv)
    )
    _wait(stack_name, "stack_create_complete")


@then("the stack '{stack_name}' will exist")
def step_impl(_, stack_name: str) -> None:
    response = client.list_stacks()
    found = False
    for summary in response["StackSummaries"]:
        if summary["StackName"] == stack_name:
            found = True
            break
    assert found


@then("the stack '{stack_name}' will have RetentionInDays of '{expected_retention}'")
def step_impl(_, stack_name: str, expected_retention: str) -> None:
    log_group_name = _get_output(stack_name, "LogGroupName")
    retention = _get_retention(log_group_name)
    assert retention == expected_retention


def _wait(stack_name: str, state: str) -> None:
    waiter = client.get_waiter(state)
    waiter.wait(
        StackName=stack_name,
        WaiterConfig={"Delay": 5, "MaxAttempts": 10}
    )


def _template_body(template: str) -> str:
    with open(template) as file_handle:
        return file_handle.read()


def _parameters(params_csv: str) -> List[Dict[str, str]]:
    return_val = []
    for param in params_csv.split(","):
        key, value = param.split("=")
        return_val.append({"ParameterKey": key, "ParameterValue": value})
    return return_val


def _get_output(stack_name: str, output_name: str) -> str:
    response = client.describe_stacks(StackName=stack_name)
    for output in response["Stacks"][0]["Outputs"]:
        if output["OutputKey"] == output_name:
            return output["OutputValue"]


def _get_retention(log_group_name: str) -> Optional[str]:
    client = boto3.client("logs")
    response = client.describe_log_groups(
        logGroupNamePrefix=log_group_name
    )
    for log_group in response["logGroups"]:
        if log_group["logGroupName"] == log_group_name:
            return str(log_group["retentionInDays"])
```

Some things to pay attention to in this code:

- Every line in a feature file "Given", "When", "Then" and "And" has a `step_impl` decorated with `@given`, `@when`, `@then` (and `@then` again) respectively.
- These functions receive a first argument `context` containing context info defined in the feature file, which I am not using. Thus I have replaced all these with a first argument `\_`.
- I have defined additional helper functions (`_wait`, `_template_body` etc) starting with an underscore although I could name them anything I like.

Otherwise, I think this code is mostly self-explanatory for anyone familiar with Python and Boto3.

And my project structure now looks like this:

```text
▶ tree .
.
├── features
│   └── loggroup.feature
├── loggroup.yml
├── requirements.txt
└── steps
    └── steps.py
```

### Running the tests

To run the tests:

![Behave]({{ "/assets/behave.png" | absolute_url }})

## Bash and shunit2

Now I am going to rewrite all of this in Bash and shunit2 and compare the result.

### Create the test file

```text
▶ mkdir shunit2
```

In there I create `shunit2/test_loggroup.sh` with the following content:

```bash
export AWS_DEFAULT_OUTPUT="text"
stack_name="test-stack1"

_delete_stack() {
  local stack_name="$1"
  echo "Cleaning up $stack_name if it exists"
  aws cloudformation delete-stack \
    --stack-name "$stack_name"
  aws cloudformation wait stack-delete-complete \
    --stack-name "$stack_name"
}

_create_stack() {
  local stack_name="$1"
  local template="$2"
  local retention="$(cut -f2 -d= <<< "$3")"
  echo "Creating $stack_name"
  aws cloudformation create-stack \
    --stack-name "$stack_name" \
    --template-body "file://$template" \
    --parameters "ParameterKey=RetentionInDays,ParameterValue=$retention" \
    --output "json"
  aws cloudformation wait stack-create-complete \
    --stack-name "$stack_name"
}

_get_output() {
  local stack_name="$1"
  local output_name="$2"
  aws cloudformation describe-stacks \
    --stack-name "$stack_name" \
    --query \
'Stacks[0].Outputs[?OutputKey==`'"$output_name"'`].OutputValue'
}

_get_retention() {
  local log_group_name="$1"
  aws logs describe-log-groups \
    --log-group-name-prefix "$log_group_name" \
    --query \
'logGroups[?logGroupName==`'"$log_group_name"'`].retentionInDays'
}

oneTimeSetUp() {
  _delete_stack "$stack_name"
}

testRetention() {
  local actual_retention log_group_name
  _create_stack "$stack_name" "loggroup.yml" "RetentionInDays=1"
  log_group_name="$(_get_output "$stack_name" "LogGroupName")"
  actual_retention="$(_get_retention "$log_group_name")"
  assertEquals "$actual_retention" "1"
}

oneTimeTearDown() {
  _delete_stack "$stack_name"
}

. shunit2
```

My project structure now is:

```text
▶ tree .
.
├── features
│   └── loggroup.feature
├── loggroup.yml
├── requirements.txt
├── shunit2
│   └── test_loggroup.sh
└── steps
    └── steps.py
```

### Running the tests

To run the tests:

![Behave]({{ "/assets/behave-bash.png" | absolute_url }})

## Discussion

As a Bash programmer with equally strong knowledge of Bash and Python, I prefer the Bash and shunit2 patterns. I find that everything has ended up in a single file, which has led to fewer moving parts and code that is &mdash; to me &mdash; easier to understand and maintain. The shunit2 framework seems to be simpler and more flexible and the code an easy top-to-bottom organisation that I am most expecting.

I am sure that someone who strongly prefers Python might be drawn to the behave framework. I feel that having the human-readable Gherkin syntax is a nice idea in theory, whereas I doubt that anyone will read those tests other than the developers and maintainers, and thus having business logic expressed in English does not seem to be a benefit in practice. Rather, we would spend quite a bit of time maintaining code around the need to implement those English sentences in Python.

From a user experience and output point of view, I feel that behave wins a little bit. The output is cleaner and more readable and this might be a reason to choose behave.

## Conclusion

This concludes my post comparing the behave BDD framework with the Bash and shunit2 framework that I personally prefer. I have shown how to set it all up and given a simplest example. I did not cover all of the features but the remainder would be easy to pick up from here. I then rewrote this in Bash and shunit2 and found that the Bash code ended up simpler in my own opinion.

## See also

- Gherkins reference https://cucumber.io/docs/gherkin/reference/
- behave docs https://behave.readthedocs.io/en/stable/index.html
