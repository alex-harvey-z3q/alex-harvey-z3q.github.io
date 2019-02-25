---
layout: post
title: "Deploying a CORS-enabled REST API in AWS Lambda using SAM"
date: 2019-02-12
author: Alex Harvey
tags: sam lambda cors
---

I recently played with the AWS Serverless Application Model (SAM). It is time to document what I learnt. In this post, I show how to deploy a CORS-enabled REST API in AWS Lambda using SAM. My example is based on the Hello World example that is provided by default in SAM.

## Dependencies

I assume that you already have installed:

- System Python 2.7
- The virtualenv package
- [Docker](https://www.docker.com/community-edition)

## Install SAM in a Virtualenv

I do all of my Python development in [Virtualenvs](https://docs.python-guide.org/dev/virtualenvs/) so as to avoid dependency hell in my system Python libraries. Thus, my first step is to create a virtualenv:

```
▶ virtualenv venv
▶ . venv/bin/activate
```

And I create the following `requirements.txt` file:

```
awscli
aws-sam-cli
pytest
pytest-mock
ipdb
```

The AWS CLI and the SAM CLI itself are `awscli` and `aws-sam-cli`. The two `pytest` libraries are needed to run the Python unit tests for the Hello World example. And `ipdb` is of course the Python debugger, and that's optional. To install all these in my virtualenv I type:

```
▶ pip install -r requirements.txt
```

At this point, I should have a working SAM CLI:

```
▶ sam --version
SAM CLI, version 0.11.0
```

## Initialise the application

At this point it is possible to follow the AWS Serverless Application Model [Quick Start](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-quick-start.html) docs. Initialise the application using:

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

The `sam init` commands initialises the project with a SAM template, a "hello world" Lambda function, some test events, unit tests and so forth. For more information, see `sam init --help`.

## The directory structure

The `sam init --runtime python2.7` creates the following structure:

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

The `app.py` is the Lambda function itself. Its dependencies are specified in `requirements.txt`. The `__init__.py` file is empty and is a requirement of the Python package structure. The `tests` directory contains sample unit tests for the function using the `pytest` library.

The `template.yaml` file is the SAM template and `event.json` is the sample event for testing the function.

## The initial template.yaml

The sample `template.yaml` file provided should be studied closely by the first time SAM user as it contains a number of important clues about how SAM works and also important documentation references.

### The template itself

I provide the Python 2.7 version of the template here for discussion<sup>1</sup>:

```yaml
---
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: >
  sam-app
  Sample SAM Template for sam-app

# More info about Globals:
# https://github.com/awslabs/serverless-application-model/blob/master/docs/globals.rst
#
Globals:
  Function:
    Timeout: 3

Resources:

  # More info about Function Resource:
  # https://github.com/awslabs/serverless-application-model/blob/master/versions/2016-10-31.md#awsserverlessfunction
  #
  HelloWorldFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: hello_world/
      Handler: app.lambda_handler
      Runtime: python2.7

      # More info about API Event Source:
      # https://github.com/awslabs/serverless-application-model/blob/master/versions/2016-10-31.md#api
      #
      Events:
        HelloWorld:
          Type: Api
          Properties:
            Path: /hello
            Method: get

Outputs:

  # ServerlessRestApi is an implicit API created out of Events key under Serverless::Function
  # Find out more about other implicit resources you can reference within SAM
  # https://github.com/awslabs/serverless-application-model/blob/master/docs/internals/generated_resources.rst#api
  #
  HelloWorldApi:
    Description: "API Gateway endpoint URL for Prod stage for Hello World function"
    Value: !Sub "https://${ServerlessRestApi}.execute-api.${AWS::Region}.amazonaws.com/Prod/hello/"

  HelloWorldFunction:
    Description: "Hello World Lambda Function ARN"
    Value: !GetAtt HelloWorldFunction.Arn

  HelloWorldFunctionIamRole:
    Description: "Implicit IAM Role created for Hello World function"
    Value: !GetAtt HelloWorldFunctionRole.Arn
```

In the remainder of this section I call out key features of this template.

### The transform

The first thing to note is that the SAM template is actually a marked up Cloudformation template. The line `Transform: AWS::Serverless-2016-10-31` tells Cloudformation to include the SAM extensions.

### The globals section

The `globals` section is one of the SAM extensions to Cloudformation. There is important documentation at both the [docs/globals.rst](https://github.com/awslabs/serverless-application-model/blob/master/docs/globals.rst) and [versions/2016-10-31.md#globals-section](https://github.com/awslabs/serverless-application-model/blob/master/versions/2016-10-31.md#globals-section) pages in the SAM source code. I recommend carefully reading both.

At the time of writing<sup>2</sup>, the SAM types `AWS::Serverless::Function`, `AWS::Serverless::Api` and `AWS::Serverless::SimpleTable` can all be further configured from the globals section.

Note that configuration specified in the globals section is inherited by the SAM types defined elsewhere within the template. The rules for inheritance are documented in the [docs/globals.rst#overridable](https://github.com/awslabs/serverless-application-model/blob/master/docs/globals.rst#overridable) section of the docs.

As suggested in the output of `sam init`, the next steps might be:

- use `sam local invoke` and test the function locally (in the SAM-provided Lambda Docker container) using the `event.json` file, also provided by SAM.
- use `sam local start-api` to start the API locally so that you can play with it.
- read the `sam-app/README.md` for further instructions.

### The serverless function

The Lambda function itself is the `HelloWorldFunction` resource of type `AWS::Serverless::Function`:

```yaml
HelloWorldFunction:
  Type: AWS::Serverless::Function
  Properties:
    CodeUri: hello_world/
    Handler: app.lambda_handler
    Runtime: python2.7
    Events:
      HelloWorld:
        Type: Api
        Properties:
          Path: /hello
          Method: get
```

The `AWS::Serverless::Function` type is documented at the [versions/2016-10-31.md#awsserverlessfunction](https://github.com/awslabs/serverless-application-model/blob/master/versions/2016-10-31.md#awsserverlessfunction) page mentioned in the template.

### Comparing the AWS::Serverless::Function with the AWS::Lambda::Function type

It is worth comparing the `AWS::Serverless::Function` with the [standard](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-lambda-function.html) `AWS::Lambda::Function` type in Cloudformation (hereafter the "legacy function type" and the "serverless type").

The following is an sdiff on the signatures from the documentation (at the time of writing):

```
Type: "AWS::Lambda::Function"           | Type: "AWS::Serverless::Function"
Properties:                               Properties:
                                        >   AutoPublishAlias: String
  Code:                                 |   CodeUri:
    Code                                |     CodeUri
  DeadLetterConfig:                     |   DeadLetterQueue:
    DeadLetterConfig                    |     DeadLetterQueue
                                        >   DeploymentPreference:
                                        >     DeploymentPreference
  Description: String                       Description: String
  Environment:                              Environment:
    Environment                               Environment
                                        >   Events:
                                        >     Events
  FunctionName: String                      FunctionName: String
  Handler: String                           Handler: String
                                        >   InlineCode: String
  KmsKeyArn: String                         KmsKeyArn: String
  Layers:                                   Layers:
    - String                                  - String
  MemorySize: Integer                       MemorySize: Integer
                                        >   Policies:
                                        >     Policies
  ReservedConcurrentExecutions: Integer     ReservedConcurrentExecutions: Integer
  Role: String                              Role: String
  Runtime: String                           Runtime: String
  Timeout: Integer                          Timeout: Integer
  TracingConfig:                        |   Tracing: String
    TracingConfig                       <
  VpcConfig:                                VpcConfig:
    VPCConfig                                 VPCConfig
  Tags:                                 |   Tags:
    Resource Tag                              Resource Tag
```

Some of these differences are just naming inconsistencies - the `DeadLetterConfig` and `TracingConfig` properties of the legacy function type appear to have been renamed as `DeadLetterQueue` and `Tracing` in the serverless type. Likewise, the `CodeUri` and `InlineCode` properties also appear to just rename features of the `Code` type. And `Policies` allows us to modify the policies of the implicit IAM Role. More on that below.

Leaving aside superficial differences, the features provided by the serverless type that didn't exist in the legacy function type are:

- `Events`: A map of Event source objects that defines the events that trigger this function. More on this below when I discuss the implicit API.
- `AutoPublishAlias`: Name of the Alias. Read the [AutoPublishAlias Guide](https://github.com/awslabs/serverless-application-model/blob/master/docs/safe_lambda_deployments.rst#instant-traffic-shifting-using-lambda-aliases) for how it works.
- `DeploymentPreference`: Settings to enable Safe Lambda Deployments. Read the [usage guide](https://github.com/awslabs/serverless-application-model/blob/master/docs/safe_lambda_deployments.rst) for detailed information.

Of these, I haven't looked at `AutoPublishAlias` or `DeploymentPreference`, so I will omit further discussion of them at this time.

### The implicit API and the Events source

A selling point of SAM is that it is requires less Cloudformation code to create some of the frequently required supporting AWS resources like the API Gateway and Lambda execution Role. In support of that are the implicit API and the default Role, which are a bit confusing at first.

In the `Events` property of the `HelloWorldFunction`, we have:

```yaml
Events:
  HelloWorld:
    Type: Api
    Properties:
      Path: /hello
      Method: get
```

Now here's the confusing bit:

By mentioning an event source of `Type: Api` _that isn't otherwise defined in the template_, a resource of type `AWS::Serverless::Api` is created silently. This is known as the "implicit API". 

Meanwhile, the new type [`AWS::Serverless::Api`](https://github.com/awslabs/serverless-application-model/blob/master/versions/2016-10-31.md#awsserverlessapi) creates a collection of API Gateway resources, allowing us to avoid defining a complex system of [API Gateway resources](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-reference-apigateway.html) in Cloudformation the old way.

The implict API can be referenced within the template using the special variable `${ServerlessRestApi}`.

### The default Role

Another implicit type defined in the sample template is the Lambda Execution Role. This implicit type - actually referred to as the "default role" in the documentation - is created silently, unless you create an `AWS::IAM::Role` type explicitly and then refer to it via the `Role` property of the function.

The only reference to this Role in the sample template is right at the bottom in the `Outputs` section:

```yaml
HelloWorldFunctionIamRole:
  Description: "Implicit IAM Role created for Hello World function"
  Value: !GetAtt HelloWorldFunctionRole.Arn
```

Note that its name is the function name + `Role` and its ARN can be obtained as shown, using `!GetAtt`. This naming is documented [here](https://github.com/awslabs/serverless-application-model/blob/master/docs/internals/generated_resources.rst#aws-serverless-function).

Now I mentioned above that the function has a `Policies` property that the Cloudformation function doesn't have. By specifying a list of IAM Policies on the `AWS::Serverless::Function` type, these are added to the default role.

### The default Stage

There is also a default stage named "Prod" created that cannot be configured. (And at the time of writing an open [bug](https://github.com/awslabs/serverless-application-model/issues/191) results in a stage called "Stage" being also created.)

The default stage is mentioned in the sample template here:

```yaml
HelloWorldApi:
  Description: "API Gateway endpoint URL for Prod stage for Hello World function"
  Value: !Sub "https://${ServerlessRestApi}.execute-api.${AWS::Region}.amazonaws.com/Prod/hello/"
```

The default stage is documented [here](https://github.com/awslabs/serverless-application-model/blob/master/docs/internals/generated_resources.rst#api).

## Testing locally

Having completed the walk through of the sample template, let's explore the options we have for testing locally.

### Running the unit tests

We can change into the sam-app folder then:

```
▶ python -m pytest tests/ -v
======================================= test session starts =======================================
platform darwin -- Python 2.7.15, pytest-4.2.0, py-1.7.0, pluggy-0.8.1 -- /Users/alexharvey/git/home/sam-test/virtualenv/bin/python
cachedir: .pytest_cache
rootdir: /Users/alexharvey/git/home/sam-test/sam-app, inifile:
plugins: mock-1.10.1
collected 1 item

tests/unit/test_handler.py::test_lambda_handler PASSED                                                                                                          [100%]

==================================== deprecated python version =====================================
You are using Python 2.7.15, which will no longer be supported in pytest 5.0
For more information, please read:
  https://docs.pytest.org/en/latest/py27-py34-deprecation.html
===================================== 1 passed in 0.05 seconds =====================================
```

Of course this is just Python, so any kind of unit test framework could be used here.

### sam local invoke

More interesting is the ability to invoke the function in its own SAM-provided Docker container. To do that:

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

### sam local start-api

Also useful and cool is the ability to start the API in the Lambda Docker container and play with it.

```
▶ sam local start-api
2019-02-25 19:33:12 Found credentials in environment variables.
2019-02-25 19:33:13 Mounting HelloWorldFunction at http://127.0.0.1:3000/hello [GET]
2019-02-25 19:33:13 You can now browse to the above endpoints to invoke your functions. You do not need to restart/reload SAM CLI while working on your functions, changes will be reflected instantly/automatically. You only need to restart SAM CLI if you update your AWS SAM template
2019-02-25 19:33:13  * Running on http://127.0.0.1:3000/ (Press CTRL+C to quit)
```

Then from another terminal:

```
▶ curl http://127.0.0.1:3000/hello
{"message": "hello world"}
```

And in the original terminal I see:

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

### sam build

If I change the function, I may want to rebuild. For testing I changed the message in the function to "Hello, Alex!" and then saved `app.py`. Then I can rebuild using:

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

## Deploying the application

Another big win for users of SAM is automation around zipping up the Lambda function and pushing it to an s3 bucket.

### sam package

```
▶ sam package \
  --output-template-file packaged.yaml \
  --s3-bucket alexharvey3118
Uploading to 447c06bbc03dcd1b23220d2450918b99  522916 / 522916.0  (100.00%)
Successfully packaged artifacts and wrote output template to file packaged.yaml.
Execute the following command to deploy the packaged template
aws cloudformation deploy --template-file /Users/alexharvey/git/home/sam-test/sam-app/packaged.yaml --stack-name <YOUR STACK NAME>
```

A few things have happened:

- The app has been packaged as a ZIP file.
- The ZIP file is pushed to `https://alexharvey3118.s3.ap-southeast-2.amazonaws.com/447c06bbc03dcd1b23220d2450918b99`.
- The template.yaml was converted to packaged.yaml ready for deployment.

The diffs between `template.yaml` and `packaged.yaml` are actually minor, although the processing rewrites the file in a way that obscures this. To see the diffs I use the Ruby `HashDiff` library:

```ruby
▶ irb
2.4.1 :001 > require 'Hashdiff' ; require 'awesome_print' ; require 'yaml'
 => true
2.4.1 :002 > ap HashDiff.diff(YAML.load_file('packaged.yaml'), YAML.load_file('template.yaml'))
[
    [0] [
        [0] "~",
        [1] "Outputs.HelloWorldApi.Value",
        [2] {
            "Fn::Sub" => "https://${ServerlessRestApi}.execute-api.${AWS::Region}.amazonaws.com/Prod/hello/"
        },
        [3] "https://${ServerlessRestApi}.execute-api.${AWS::Region}.amazonaws.com/Prod/hello/"
    ],
    [1] [
        [0] "~",
        [1] "Outputs.HelloWorldFunction.Value",
        [2] {
            "Fn::GetAtt" => [
                [0] "HelloWorldFunction",
                [1] "Arn"
            ]
        },
        [3] "HelloWorldFunction.Arn"
    ],
    [2] [
        [0] "~",
        [1] "Outputs.HelloWorldFunctionIamRole.Value",
        [2] {
            "Fn::GetAtt" => [
                [0] "HelloWorldFunctionRole",
                [1] "Arn"
            ]
        },
        [3] "HelloWorldFunctionRole.Arn"
    ],
    [3] [
        [0] "~",
        [1] "Resources.HelloWorldFunction.Properties.CodeUri",
        [2] "s3://alexharvey3118/447c06bbc03dcd1b23220d2450918b99",
        [3] "hello_world/"
    ]
]
 => nil
```

So actually, aside from formatting differences, the only actual change is the `CodeUri` was changed from the relative path (`hello_world`) that allowed us to run the function locally, to the S3 bucket path, that allows us to deploy in the AWS cloud. That's actually the only difference between `template.yaml` and `packaged.yaml` (at least in this example).

### sam deploy

Finally there is the `sam deploy` command, which is just an alias for `aws cloudformation deploy`:

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

## Summary

In this part one of a three part series, I have installed SAM in a Python Virtualenv, used SAM to generate a sample Hello World project, discussed the SAM architecture with reference to the sample template and documentation, and investigated using SAM to test locally and deploy.

<sup>1</sup> Actually, I cleaned up the formatting for the sake of improving the presentation of this blog post.
<sup>2</sup> Noting that this project is evolving fast.
