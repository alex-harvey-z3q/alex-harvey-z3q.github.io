---
layout: post
title: "Introduction to SAM Part I: Using the SAM CLI"
date: 2019-03-02
author: Alex Harvey
tags: sam lambda cors
---

In this blog series I introduce Amazon's Serverless Application Model (SAM). The series summarises my learnings after developing an app in this framework for the first time. It could serve as a guide for others who also want to learn SAM quickly.

In Part I (this article) I show how to use the SAM CLI to build, test and deploy SAM's built-in Python "hello world" app. In Part II I look at the internals of SAM with reference to the architecture and template language features. And then in Part III I configure the app's API Gateway to add a proxy+ endpoint and CORS configuration using the SAM template.

#### Table of contents

1. [Overview to Part I](#overview-to-part-i)
2. [About SAM and the SAM CLI](#about-sam-and-the-sam-cli)
3. [Important documentation](#important-documentation)
4. [Installing SAM CLI](#installing-sam-cli)
    * [Dependencies](#dependencies)
    * [Building a virtualenv](#building-a-virtualenv)
    * [Installing SAM CLI in the virtualenv](#installing-sam-cli-in-the-virtualenv)
5. [Creating a new project](#creating-a-new-project)
    * [About the "hello world" app](#about-the-hello-world-app)
    * [sam init](#sam-init)
    * [The directory structure](#the-directory-structure)
6. [Testing locally](#testing-locally)
    * [Running the unit tests](#running-the-unit-tests)
    * [sam local invoke](#sam-local-invoke)
    * [sam local start-api](#sam-local-start-api)
7. [Building and deploying](#building-and-deploying)
    * [sam validate](#sam-validate)
    * [sam build](#sam-build)
    * [sam build --use-container](#sam-build-use-container)
    * [sam package](#sam-package)
    * [sam deploy](#sam-deploy)
    * [sam logs](#sam-logs)
8. [Summary](#summary)

## Overview to Part I

As mentioned, in this article I install the SAM CLI and then use it to build, test and deploy the built-in "hello world" app. The post follows in outline the SAM CLI [Quick Start Guide](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-quick-start.html), but expands on it to discuss installation, unit testing, debugging and some of the more advanced features.

## About SAM and the SAM CLI

SAM is a Serverless framework for deploying Serverless apps in AWS. It has two parts: the SAM Translator (also known as the SAM Transformer), which runs in AWS CloudFormation; and the SAM CLI, a utility for building and testing Serverless apps locally and inside a Lambda-like Docker container and also for packaging and deploying them. SAM is also a template language, and in that sense it is a superset of AWS CloudFormation.

More about SAM and the architecture is discussed in Part II.

## Important documentation

At the time of writing, SAM is still Beta software, and part of the challenge is finding the documentation, which is not always complete or well organised. So in this section I discuss the SAM CLI's documentation (and defer discussion of the SAM Translator's docs to Part II).

The docs that I have found most useful are:

- The SAM CLI's built-in help that is found by adding \--help after the CLI commands, such as sam \--help and sam init \--help and so on.
- The Markdown docs in the source code repo at GitHub including:
    * The [README.md](https://github.com/awslabs/aws-sam-cli) describes how to get started, the SAM CLI project status, and links to other important docs.
    * In the docs directory there is:
        - [usage.md](https://github.com/awslabs/aws-sam-cli/blob/develop/docs/usage.md) talks about invoking functions locally, running automated tests against a local Lambda, generating sample events for testing, running an API gateway locally, connecting your IDE to the Lambda debugging port, fetching Lambda logs locally, as well as validating and deploying SAM templates.
        - [advanced_usage.md](https://github.com/awslabs/aws-sam-cli/blob/develop/docs/advanced_usage.md) discusses info about compiled languages like Java and .NET, how SAM CLI uses IAM credentials and environment variables, how to serve static assets locally, and how to connect to remote Docker.
        - [running_and_debugging_serverless_applications_locally.md](https://github.com/awslabs/aws-sam-cli/blob/develop/docs/running_and_debugging_serverless_applications_locally.md) duplicates a bit of the other info (on the develop branch, and at the time of writing) but it contains an example of piping a JSON event into sam local invoke, more on running an API gateway locally, more on connecting your IDE to the Lambda debugging port, and an interesting section on how to integrate your Lambda with other applications.
        - [deploying_serverless_applications.md](https://github.com/awslabs/aws-sam-cli/blob/develop/docs/deploying_serverless_applications.md) is mostly duplicated by docs from elsewhere as far as I can tell. I just mention it here for completeness.
    * In the designs directory is some SAM CLI design documentation that is worth looking at, in particular:
        - [sam_build_cmd.md](https://github.com/awslabs/aws-sam-cli/blob/develop/designs/sam_build_cmd.md) talks about the recently-added sam build feature from the point of view of the developers who wrote the feature and helps to understand the problem it solves and where it is heading.
- The [SAM product page](https://aws.amazon.com/serverless/sam).
- The [SAM developer guide](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/what-is-sam.html), especially:
    * [Testing and Debugging Serverless Applications](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-test-and-debug.html) covers a lot of the same material as in the "usage" docs above, as well as a section on working with Lambda Layers that doesn't appear to be documented anywhere else.
    * [Deploying Serverless Applications](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-deploying.html) also covers material mentioned elsewhere on the sam package and sam deploy commands as well as using sam publish to publish to the AWS Serverless Application Repository and integration with CodeDeploy (both out of scope for this series).
    * [AWS SAM Reference](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-reference.html) covers in detail various ways of installing the SAM CLI and contains a SAM CLI Command Reference that is up to date of version 0.8.0.
    * [AWS SAM CLI Release Notes](https://github.com/awslabs/aws-sam-cli/releases) is an important document to keep an eye on (up to release 0.12.0 at the time of writing) for a product such as this one still in Beta.
- The [SAM Quick Start Guide](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-quick-start.html) mentioned above.

Also useful to be aware of are these other resources:

- The [aws-sam](https://stackoverflow.com/questions/tagged/aws-sam) tag on Stack Overflow, where developers from the SAM team (and people like me) can answer your support questions.
- The open [issues](https://github.com/awslabs/aws-sam-cli/issues) list and [pull requests](https://github.com/awslabs/aws-sam-cli/pulls) for the SAM CLI at Github, where known issues and bugs are documented, raised and/or fixed.
- The [SAM Developers (#samdev) Slack Channel](https://join.slack.com/t/awsdevelopers/shared_invite/enQtMzg3NTc5OTM2MzcxLTdjYTdhYWE3OTQyYTU4Njk1ZWY4Y2ZjYjBhMTUxNGYzNDg5MWQ1ZTc5MTRlOGY0OTI4NTdlZTMwNmI5YTgwOGM/).

## Installing SAM CLI

So enough about documentation. Let's dive right in. In this section, I install the SAM CLI in a virtualenv on my laptop.

### Dependencies

Before trying to install the SAM CLI, make sure you have these dependencies installed:

- Python<sup>1</sup>
- The [virtualenv](https://virtualenv.pypa.io/en/latest/installation/) package (required for this blog post only)
- [Docker](https://www.docker.com/community-edition).

### Building a virtualenv

I prefer to do all my Python development in virtualenvs so as to avoid dependency problems in system Python libraries. (Although SAM CLI is also available in brew, in rpms etc.) Thus, the first step is to create a virtualenv:

```
▶ virtualenv venv
▶ . venv/bin/activate
```

And I create a requirements.txt file with the following libraries:

```
awscli
aws-sam-cli
pytest
pytest-mock
ipdb
```

The AWS CLI and then the SAM CLI itself are the awscli and aws-sam-cli packages. The pytest and pytest-mock libraries are needed to run the unit tests for the "hello world" example. And ipdb is my preferred Python debugger. It's optional, of course.

### Installing SAM CLI in the virtualenv

To install all of these in virtualenv:

```
▶ pip install -r requirements.txt
```

And at this point, I have a working SAM CLI:

```
▶ sam --version
SAM CLI, version 0.11.0
```

Note the versioning there too. Yes, as mentioned, this is Beta software and that is reflected in the 0.x versioning.

## Creating a new project

In this section, I initialise a project with the built-in "hello world" example Serverless app.

### About the "hello world" app

The example app consists of:

- A Lambda function
- A Lambda execution role
- An API Gateway.

All of the resources will live inside a CloudFormation stack. The app listens on port 3000 at the endpoint /hello and responds in JSON with "hello world". So it's very simple of course.

### sam init

The first step is to initialise the project. In this example I use the Python 2.7 runtime, although, at the time of writing, you could use various versions of Go, Node.js, Python 3, .NET, Java or Ruby. To initialise:

```
▶ sam init --runtime python2.7
[+] Initializing project structure...

Project generated: ./sam-app

Steps you can take next within the project folder
===================================================
[*] Invoke Function: sam local invoke HelloWorldFunction --event event.json
[*] Start API Gateway locally: sam local start-api

Read sam-app/README.md for further instructions

[*] Project initialization is now complete
```

The init command initialises the project with a SAM template, a "hello world" Lambda function, some test events, some unit tests, and so forth.

### The directory structure

The directory structure is slightly different depending on the runtime you choose, of course, but for Python 2.7, the following structure is created:

```
▶ tree .
.
├── README.md
├── event.json
├── hello_world
│   ├── __init__.py
│   ├── __init__.pyc
│   ├── app.py
│   ├── app.pyc
│   └── requirements.txt
├── template.yaml
└── tests
    └── unit
        ├── __init__.py
        ├── __init__.pyc
        ├── test_handler.py
        └── test_handler.pyc
```

The most important of these files are the app.py which is the Python Lambda function itself; the template.yaml which is the SAM template; the event.json which contains a sample event for testing; and the README.md which contains further documentation and is worth reading. The requirements.txt file specifies the Lambda function's Python dependencies.

Of the remainder, the \__init__.py and the .pyc files are Pythonisms that we can ignore, and the unit tests are in the tests directory and the test_handler.py file specifically.

## Testing locally

One of the big benefits of using SAM is the framework provided for locally testing your applications. Gone are the bad old days of creating test events manually in the AWS Lambda Console!

### Running the unit tests

To run the unit tests, we can change into the sam-app folder, and then:

```
▶ python -m pytest tests/ -v
======================================= test session starts =======================================
platform darwin -- Python 2.7.15, pytest-4.2.0, py-1.7.0, pluggy-0.8.1 -- /Users/alexharvey/git/
  home/sam-test/virtualenv/bin/python
cachedir: .pytest_cache
rootdir: /Users/alexharvey/git/home/sam-test/sam-app, inifile:
plugins: mock-1.10.1
collected 1 item

tests/unit/test_handler.py::test_lambda_handler PASSED                                        [100%]

==================================== deprecated python version =====================================
You are using Python 2.7.15, which will no longer be supported in pytest 5.0
For more information, please read:
  https://docs.pytest.org/en/latest/py27-py34-deprecation.html
===================================== 1 passed in 0.05 seconds =====================================
```

The example app's tests use the Pytest unit test framework, but this is just Python, so any unit test framework could be used here.

### sam local invoke

More interesting is the ability to invoke the function in its own Docker container. To do that:

```
▶ sam local invoke HelloWorldFunction --event event.json
2019-02-24 22:29:15 Found credentials in environment variables.
2019-02-24 22:29:15 Invoking app.lambda_handler (python2.7)

Fetching lambci/lambda:python2.7 Docker container image......
2019-02-24 22:29:20 Mounting /Users/alexharvey/git/home/sam-test/sam-app/hello_world as /var/task:ro inside runtime container
START RequestId: 12a00391-078d-4ca3-a34d-2f88865d0cb6 Version: $LATEST
END RequestId: 12a00391-078d-4ca3-a34d-2f88865d0cb6
REPORT RequestId: 12a00391-078d-4ca3-a34d-2f88865d0cb6 Duration: 7 ms Billed Duration: 100 ms Memory Size: 128 MB Max Memory Used: 14 MB

{"body": "{\"message\": \"hello world\"}", "statusCode": 200}
```

Note that I had to refer to the function by its resource name from the template.

(Note also that the Docker container is a community contribution from [Michael Hart](https://github.com/mhart) and the source code for it is available [here](https://github.com/lambci/lambci).)

### sam local start-api

Another useful feature is the ability to start the API in the Lambda Docker container and play with it. The following is a demonstration of that:

```
▶ sam local start-api
2019-02-25 19:33:12 Found credentials in environment variables.
2019-02-25 19:33:13 Mounting HelloWorldFunction at http://127.0.0.1:3000/hello [GET]
2019-02-25 19:33:13 You can now browse to the above endpoints to invoke your functions. You do not need to restart/reload SAM CLI while working on your functions, changes will be reflected instantly/automatically. You only need to restart SAM CLI if you update your AWS SAM template
2019-02-25 19:33:13  * Running on http://127.0.0.1:3000/ (Press CTRL+C to quit)
```

Then from another terminal I curl the API:

```
▶ curl http://127.0.0.1:3000/hello
{"message": "hello world"}
```

I note that I received the expected response from the API. And in the other terminal window I see the logs:

```
2019-02-25 19:32:21 Invoking app.lambda_handler (python2.7)
Fetching lambci/lambda:python2.7 Docker container image.................................................
2019-02-25 19:32:32 Mounting /Users/alexharvey/git/home/sam-test/sam-app/hello_world as /var/task:ro inside runtime container
START RequestId: 30ea15c8-3364-42aa-be08-58d752807a8b Version: $LATEST
END RequestId: 30ea15c8-3364-42aa-be08-58d752807a8b
REPORT RequestId: 30ea15c8-3364-42aa-be08-58d752807a8b Duration: 11 ms Billed Duration: 100 ms Memory Size: 128 MB Max Memory Used: 14 MB
2019-02-25 19:32:33 No Content-Type given. Defaulting to 'application/json'.
2019-02-25 19:32:33 127.0.0.1 - - [25/Feb/2019 19:32:33] "GET /hello HTTP/1.1" 200 -
```

### Connecting to other networks

Although it's not relevant to the "hello world" example, I might also mention that if you need to connect your test container to another network - e.g. in order to connect to an RDS database, you can use the \--docker-network option. First, find the local host network:

```
▶ docker network ls
NETWORK ID          NAME                DRIVER              SCOPE
25a03c8453a6        bridge              bridge              local
00de89cf09d0        host                host                local
41597d91a389        none                null                local
```

And then pass that to sam local start-api:

```
▶ sam local start-api --docker-network 00de89cf09d0
```

## Building and deploying

Satisfied that I have a working Lambda function, it is time to deploy it.

Another good reason to use SAM is that it automates the bundling and deployment of the Lambda ZIP file. Traditionally, this involved bundling all the dependencies manually in a ZIP file, and sometimes compiling on an Amazon Linux instance, and then uploading somehow to an S3 bucket. With SAM, the build and package commands do all this for you.

### sam validate

But before we build anything we should validate our SAM template. Recall that a SAM template is really a marked up CloudFormation template. SAM also provides a layer of additional validation compared to aws cloudformation validate-template. To validate the SAM template:

```
▶ sam validate --template template.yaml
2019-03-02 20:31:48 Found credentials in environment variables.
/Users/alexharvey/git/home/sam-test/sam-app/template.yaml is a valid SAM Template
```

The best documentation I know of at this point for SAM validate is the [source code](https://github.com/awslabs/aws-sam-cli/blob/develop/samcli/commands/validate/lib/sam_template_validator.py) and more information can be found by adding \--debug to the command line.

### sam build

The build command creates the build directory in .aws-sam/build and installs the Python dependencies and the Lambda function ready for local testing or deployment. Note that it is necessary to rebuild each time you change the function. Suppose I change the message in the function to "Hello, Alex!" and then saved app.py. Then I can rebuild using:

```
▶ sam build
2019-02-25 19:37:29 Found credentials in environment variables.
2019-02-25 19:37:29 Building resource 'HelloWorldFunction'
2019-02-25 19:37:29 Running PythonPipBuilder:ResolveDependencies
2019-02-25 19:37:30 Running PythonPipBuilder:CopySource

Build Succeeded

Built Artifacts  : .aws-sam/build
Built Template   : .aws-sam/build/template.yaml

Commands you can use next
=========================
[*] Invoke Function: sam local invoke
[*] Package: sam package --s3-bucket <yourbucket>
```

And:

```
▶ curl http://127.0.0.1:3000/hello
{"message": "hello, Alex!"}
```

### sam build \--use-container

For functions that need to be compiled on Amazon Linux (not this one though), we can do the build in the Docker container using sam build \--use-container:

```
▶ sam build --use-container
2019-03-05 22:16:29 Starting Build inside a container
2019-03-05 22:16:30 Found credentials in environment variables.
2019-03-05 22:16:30 Building resource 'HelloWorldFunction'

Fetching lambci/lambda:build-python2.7 Docker container image....................
```

### sam package

Another win for SAM users is the automation around zipping up the Lambda function and pushing it to the S3 bucket. The sam package command zips up your code and artifacts, pushes them to S3 and outputs a modified SAM template ready for deployment via CloudFormation. Here it is:

```
▶ sam package --output-template-file packaged.yaml --s3-bucket alexharvey3118
Uploading to 447c06bbc03dcd1b23220d2450918b99  522916 / 522916.0  (100.00%)
Successfully packaged artifacts and wrote output template to file packaged.yaml.
Execute the following command to deploy the packaged template
aws cloudformation deploy --template-file /Users/alexharvey/git/home/sam-test/sam-app/packaged.yaml --stack-name <YOUR STACK NAME>
```

The remote filename is the string 447c06bbc03dcd1b23220d2450918b99 and I can find the zipped up archive at `https://alexharvey3118.s3.ap-southeast-2.amazonaws.com/447c06bbc03dcd1b23220d2450918b99`.

Also of interest is the packaged.yaml output file.

It turns out that the differences between template.yaml and packaged.yaml are minor. Using the Ruby Hashdiff library I can inspect the differences:

```
▶ ruby -rHashdiff -ryaml -e "puts HashDiff.diff(*ARGV.map{|f| YAML.load_file(f)})" \
      template.yaml packaged.yaml
~
Outputs.HelloWorldApi.Value
{"Fn::Sub"=>"https://${ServerlessRestApi}.execute-api.${AWS::Region}.amazonaws.com/Prod/hello/"}
https://${ServerlessRestApi}.execute-api.${AWS::Region}.amazonaws.com/Prod/hello/
~
Outputs.HelloWorldFunction.Value
{"Fn::GetAtt"=>["HelloWorldFunction", "Arn"]}
HelloWorldFunction.Arn
~
Outputs.HelloWorldFunctionIamRole.Value
{"Fn::GetAtt"=>["HelloWorldFunctionRole", "Arn"]}
HelloWorldFunctionRole.Arn
~
Resources.HelloWorldFunction.Properties.CodeUri
s3://alexharvey3118/447c06bbc03dcd1b23220d2450918b99
hello_world/
```

So, that tells me there are three trivial differences (just reformatting) in the Outputs section, whereas the only real difference is the CodeUri, which was changed from a relative path (hello_world), which allowed us to run the function locally, to an S3 bucket path, which allows us to deploy the function in AWS.

### sam deploy

Finally we can use sam deploy to create the stack. Note that this command is just an alias for aws cloudformation deploy:

Thus:

```
▶ sam deploy --template-file packaged.yaml --stack-name HelloWorld --capabilities CAPABILITY_IAM
Waiting for changeset to be created..
Waiting for stack create/update to complete
Successfully created/updated stack - HelloWorld
```

And to test:

```
▶ aws cloudformation describe-stacks --stack-name HelloWorld --query 'Stacks[].Outputs[?OutputKey==`HelloWorldApi`].OutputValue[]'
[
    "https://udlfabai97.execute-api.ap-southeast-2.amazonaws.com/Prod/hello/"
]
```

And:

```
▶ curl https://udlfabai97.execute-api.ap-southeast-2.amazonaws.com/Prod/hello
{"message": "hello, Alex!"}
```

"Just like when I tested it locally."

### sam logs

Finally, we can use the sam logs command to retrieve the Lambda log files. For example, if I want the logs for the function I just called:

```
▶ sam logs -n HelloWorldFunction --stack-name HelloWorld
2019-03-09 22:35:20 Found credentials in environment variables.
2019/03/09/[$LATEST]71ef94ab32e24b8e9d3217a82a552c30 2019-03-09T11:35:13.968000 START RequestId: baa374c7-6a79-45b9-b398-a130192430e8 Version: $LATEST
```

Or I could add \--debug if I want to see debug output that is too long to print here:

```
▶ sam logs -n HelloWorldFunction --stack-name HelloWorld --debug
```

And also nice is sam logs \--tail where I can get the logs in real time:

```
▶ sam logs -n HelloWorldFunction --stack-name HelloWorld --tail
2019-03-09 22:41:08 Found credentials in environment variables.
2019/03/09/[$LATEST]71ef94ab32e24b8e9d3217a82a552c30 2019-03-09T11:35:13.968000 START RequestId: baa374c7-6a79-45b9-b398-a130192430e8 Version: $LATEST
2019/03/09/[$LATEST]71ef94ab32e24b8e9d3217a82a552c30 2019-03-09T11:35:13.968000 END RequestId: baa374c7-6a79-45b9-b398-a130192430e8
2019/03/09/[$LATEST]71ef94ab32e24b8e9d3217a82a552c30 2019-03-09T11:35:13.968000 REPORT RequestId: baa374c7-6a79-45b9-b398-a130192430e8  Duration: 0.29 ms       Billed Duration: 100 ms        Memory Size: 128 MB     Max Memory Used: 45 MB
```

## Summary

So that's it for Part I. In this post, I have installed SAM in a Python virtualenv, used SAM to generate a sample "hello world" project, shown how to test and debug locally, and also how to deploy to AWS. Stayed tuned for Part II, where I look into the SAM Translator and template language in more detail.

<sup>1</sup> I am using Python 2.7 in this post because my system Python is 2.7, but Python 2.7, 3.6 and 3.7 are all supported since version 0.4.0 [apparently](https://github.com/awslabs/aws-sam-cli/releases/tag/v0.4.0).
