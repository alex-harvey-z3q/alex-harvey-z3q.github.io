---
layout: post
title: "Introduction to SAM Part IV: Updates to sam package and deploy in SAM CLI >= 0.33.1"
date: 2019-12-07
author: Alex Harvey
tags: sam
---

A look at changes to sam package and deploy in SAM CLI 0.33.1 and other updates since parts I, II and III of this series.

- ToC
{:toc}

## Overview to Part IV

When I wrote Parts I, II & III in March 2019, the SAM CLI was at version 0.11.0 and the SAM translator was at version 1.11.0. At the time of writing Part IV (7th December, 2019) those versions have changed to 0.37.0 and 1.19.0. The intention of this post is to provide a rewrite of Part I based on the changes in SAM CLI 0.33.1. I cover the new sam deploy and also the samconfig.toml file and walk through the deployment process using the new commands.

## SAM CLI

### Important documentation

SAM's documentation appears much improved, making the importance of a section to help readers find important docs less relevant. All the same, there remains quite a lot of unofficial documentation in the source code that appears useful for developers coming up to speed in SAM. I won't summarise it all again other than to note that a lot of the useful docs are now in the [`designs`](https://github.com/awslabs/aws-sam-cli/tree/develop/designs) directory.

Some documents that are relevant to this post are the following:

- [`designs/package_during_deploy.md`](https://github.com/awslabs/aws-sam-cli/blob/develop/designs/package_during_deploy.md) file. This doc explains the motivation and details of the sam deploy changes that I'm writing about today.
- The [release notes](https://github.com/awslabs/aws-sam-cli/releases/tag/v0.33.1) for version 0.33.1 of the SAM CLI.
- The AWS blog post, [A simpler deployment experience with AWS SAM CLI](https://aws.amazon.com/blogs/compute/a-simpler-deployment-experience-with-aws-sam-cli/).

### Python version

In Part I, I used Python 2.7, since that is what I had on my laptop at the time. But with Python 2 no longer in support at the end of this month, it is definitely time to use Python 3.7. Thus my Python version:

```text
▶ python -V
Python 3.7.4
```

### Installing SAM CLI

I use a similar Python Virtualenv approach as I used in Part I. I create a file venv.sh:

```bash
#!/usr/bin/env bash
virtualenv venv
. venv/bin/activate
pip install -r requirements.txt
```

And a requirements.txt:

```text
awscli
aws-sam-cli
pytest
pytest-mock
sam
```

I source that script into the running shell and have SAM installed:

```text
▶ sam --version
SAM CLI, version 0.37.0
```

### Creating a new project

The new version of SAM comes with a number of additional options for the initial SAM app. Furthermore, sam init - like other SAM CLI tools - is an interactive program now. If I just run that:

```text
▶ sam init --runtime python3.7
Which template source would you like to use?
        1 - AWS Quick Start Templates
        2 - Custom Template Location
Choice: 1

Project name [sam-app]:

Quick start templates may have been updated. Do you want to re-download the latest [Y/n]: Y

AWS quick start application templates:
        1 - Hello World Example
        2 - EventBridge Hello World
        3 - EventBridge App from scratch (100+ Event Schemas)
Template selection: 1

-----------------------
Generating application:
-----------------------
Name: sam-app
Runtime: python3.7
Dependency Manager: pip
Application Template: hello-world
Output Directory: .

Next steps can be found in the README file at ./sam-app/README.md
```

To fully automate that step (not that I can think of any reason why this would be necessary) but this works:

```text
▶ echo Y | sam init --runtime python3.7 --name sam-app --app-template hello-world
```

### Directory structure

The directory structure of the example app is more or less the same as it was before:

```text
▶ tree .
.
├── README.md
├── events
│   └── event.json
├── hello_world
│   ├── __init__.py
│   ├── app.py
│   └── requirements.txt
├── template.yaml
└── tests
    └── unit
        ├── __init__.py
        └── test_handler.py

4 directories, 8 files
```

The only real change is that the event.json file has moved to the events directory.

## Testing locally

### Running the unit tests

To run the unit tests locally:

```
▶ python -m pytest tests/ -v
```

### sam local

The sam local commads have not changed and allows me to run my function locally in a Docker container. As before, if I want to run the function locally and send an example event to it:

```text
▶ sam local invoke HelloWorldFunction --event events/event.json
Invoking app.lambda_handler (python3.7)

Fetching lambci/lambda:python3.7 Docker container image..................................................................................................................................
...................................................................................
Mounting /Users/alexharvey/git/home/sam-test/sam-app/.aws-sam/build/HelloWorldFunction as /var/task:ro,delegated inside runtime container
START RequestId: 618fffb1-d9d4-163e-c4d9-e61f4c76549c Version: $LATEST
END RequestId: 618fffb1-d9d4-163e-c4d9-e61f4c76549c
REPORT RequestId: 618fffb1-d9d4-163e-c4d9-e61f4c76549c  Init Duration: 232.81 ms        Duration: 3.96 ms       Billed Duration: 100 ms Memory Size: 128 MB     Max Memory Used: 23 MB

{"statusCode":200,"body":"{\"message\": \"hello world\"}"}
```

And if I just want to run the function locally and play with it:

```text
▶ sam local start-api
Mounting HelloWorldFunction at http://127.0.0.1:3000/hello [GET]
You can now browse to the above endpoints to invoke your functions. You do not need to restart/reload SAM CLI while working on your functions, changes will be reflected instantly/automatically. You only need to restart SAM CLI if you update your AWS SAM template
2019-12-07 21:40:18  * Running on http://127.0.0.1:3000/ (Press CTRL+C to quit)
```

And:

```text
▶ curl http://127.0.0.1:3000/hello
{"message": "hello world"}
```

## Building and deploying

It is in building and deploying application that the real changes are found. The sam package command is no longer needed. Instead, the recommended workflow is as follows.

### sam validate

The sam validate command works exactly as before:

```text
▶ sam validate --template template.yaml
/Users/alexharvey/git/home/sam-test/sam-app/template.yaml is a valid SAM Template
```

### sam build

The sam build and sam build --use-container commands also work just as before:

```text
▶ sam build
Building resource 'HelloWorldFunction'
Running PythonPipBuilder:ResolveDependencies
Running PythonPipBuilder:CopySource

Build Succeeded

Built Artifacts  : .aws-sam/build
Built Template   : .aws-sam/build/template.yaml

Commands you can use next
=========================
[*] Invoke Function: sam local invoke
[*] Deploy: sam deploy --guided
```

Or with use-container:

```text
▶ sam build --use-container
Starting Build inside a container
Building resource 'HelloWorldFunction'

Fetching lambci/lambda:build-python3.7 Docker container image............................................................................................................................
.........................................................................................................................................................................................
.........................................................................................................................................................................................
.........................................................................................................................................................................................
.........................................................................................................................................................................................
.........................................................................................................................................................................................
.........................................................................................................................................................................................
.........................................................................................................................................................................................
.........................................................................................................................................................................................
.................................................
Mounting /Users/alexharvey/git/home/sam-test/sam-app/hello_world as /tmp/samcli/source:ro,delegated inside runtime container

Build Succeeded

Built Artifacts  : .aws-sam/build
Built Template   : .aws-sam/build/template.yaml

Commands you can use next
=========================
[*] Invoke Function: sam local invoke
[*] Deploy: sam deploy --guided

Running PythonPipBuilder:ResolveDependencies
Running PythonPipBuilder:CopySource
```

### sam deploy

#### guided mode

It is now recommended to use the "guided" deployment, although the old way still works. Using guided mode:

```text
▶ sam deploy --guided

Configuring SAM deploy
======================

        Looking for samconfig.toml :  Not found

        Setting default arguments for 'sam deploy'
        =========================================
        Stack Name [sam-app]:
        AWS Region [us-east-1]: ap-southeast-2
        #Shows you resources changes to be deployed and require a 'Y' to initiate deploy
        Confirm changes before deploy [y/N]: y
        #SAM needs permission to be able to create roles to connect to the resources in your template
        Allow SAM CLI IAM role creation [Y/n]:
        Save arguments to samconfig.toml [Y/n]:

        Looking for resources needed for deployment: Not found.
        Creating the required resources...
        Successfully created!

                Managed S3 bucket: aws-sam-cli-managed-default-samclisourcebucket-15mcwc8hibmci
                A different default S3 bucket can be set in samconfig.toml

        Saved arguments to config file
        Running 'sam deploy' for future deployments will use the parameters saved above.
        The above parameters can be changed by modifying samconfig.toml
        Learn more about samconfig.toml syntax at
        https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-config.html

        Deploying with following values
        ===============================
        Stack name                 : sam-app
        Region                     : ap-southeast-2
        Confirm changeset          : True
        Deployment s3 bucket       : aws-sam-cli-managed-default-samclisourcebucket-15mcwc8hibmci
        Capabilities               : ["CAPABILITY_IAM"]
        Parameter overrides        : {}

Initiating deployment
Waiting for changeset to be created..

CloudFormation stack changeset
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Operation                                                    LogicalResourceId                                            ResourceType
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
+ Add                                                        HelloWorldFunctionHelloWorldPermissionProd                   AWS::Lambda::Permission
+ Add                                                        HelloWorldFunctionRole                                       AWS::IAM::Role
+ Add                                                        HelloWorldFunction                                           AWS::Lambda::Function
+ Add                                                        ServerlessRestApiDeployment47fc2d5f9d                        AWS::ApiGateway::Deployment
+ Add                                                        ServerlessRestApiProdStage                                   AWS::ApiGateway::Stage
+ Add                                                        ServerlessRestApi                                            AWS::ApiGateway::RestApi
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Changeset created successfully. arn:aws:cloudformation:ap-southeast-2:007108882118:changeSet/samcli-deploy1575703939/57973087-31a0-46e4-80d1-a29c03f300dd


Previewing CloudFormation changeset before deployment
======================================================
Deploy this changeset? [y/N]: y

2019-12-07 18:32:43 - Waiting for stack create/update to complete

CloudFormation events from changeset
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
ResourceStatus                                ResourceType                                  LogicalResourceId                             ResourceStatusReason
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE_IN_PROGRESS                            AWS::IAM::Role                                HelloWorldFunctionRole                        -
CREATE_IN_PROGRESS                            AWS::IAM::Role                                HelloWorldFunctionRole                        Resource creation Initiated
CREATE_COMPLETE                               AWS::IAM::Role                                HelloWorldFunctionRole                        -
CREATE_IN_PROGRESS                            AWS::Lambda::Function                         HelloWorldFunction                            -
CREATE_IN_PROGRESS                            AWS::Lambda::Function                         HelloWorldFunction                            Resource creation Initiated
CREATE_COMPLETE                               AWS::Lambda::Function                         HelloWorldFunction                            -
CREATE_IN_PROGRESS                            AWS::ApiGateway::RestApi                      ServerlessRestApi                             -
CREATE_IN_PROGRESS                            AWS::ApiGateway::RestApi                      ServerlessRestApi                             Resource creation Initiated
CREATE_COMPLETE                               AWS::ApiGateway::RestApi                      ServerlessRestApi                             -
CREATE_IN_PROGRESS                            AWS::Lambda::Permission                       HelloWorldFunctionHelloWorldPermissionProd    -
CREATE_IN_PROGRESS                            AWS::ApiGateway::Deployment                   ServerlessRestApiDeployment47fc2d5f9d         -
CREATE_IN_PROGRESS                            AWS::Lambda::Permission                       HelloWorldFunctionHelloWorldPermissionProd    Resource creation Initiated
CREATE_COMPLETE                               AWS::ApiGateway::Deployment                   ServerlessRestApiDeployment47fc2d5f9d         -
CREATE_IN_PROGRESS                            AWS::ApiGateway::Deployment                   ServerlessRestApiDeployment47fc2d5f9d         Resource creation Initiated
CREATE_IN_PROGRESS                            AWS::ApiGateway::Stage                        ServerlessRestApiProdStage                    -
CREATE_IN_PROGRESS                            AWS::ApiGateway::Stage                        ServerlessRestApiProdStage                    Resource creation Initiated
CREATE_COMPLETE                               AWS::ApiGateway::Stage                        ServerlessRestApiProdStage                    -
CREATE_COMPLETE                               AWS::Lambda::Permission                       HelloWorldFunctionHelloWorldPermissionProd    -
CREATE_COMPLETE                               AWS::CloudFormation::Stack                    sam-app                                       -
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Stack sam-app outputs:
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
OutputKey-Description                                                                      OutputValue
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
HelloWorldFunctionIamRole - Implicit IAM Role created for Hello World function             arn:aws:iam::007108882118:role/sam-app-HelloWorldFunctionRole-YWQAXKFFWEQ3
HelloWorldApi - API Gateway endpoint URL for Prod stage for Hello World function           https://z3hfweg5r1.execute-api.ap-southeast-2.amazonaws.com/Prod/hello/
HelloWorldFunction - Hello World Lambda Function ARN                                       arn:aws:lambda:ap-southeast-2:007108882118:function:sam-app-HelloWorldFunction-
                                                                                           JVY40ZTM3SFK
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Successfully created/updated stack - sam-app in ap-southeast-2
```

#### samconfig.toml

When sam deploy \--guided is run, a samconfig.toml file is created. After I did that above I had this content in it:

```toml
version = 0.1
[default]
[default.deploy]
[default.deploy.parameters]
stack_name = "sam-app"
s3_bucket = "aws-sam-cli-managed-default-samclisourcebucket-15mcwc8hibmci"
s3_prefix = "sam-app"
region = "ap-southeast-2"
confirm_changeset = true
capabilities = "CAPABILITY_IAM"
```

#### Deploying again

When I deploy a second time, I can use the samconfig.toml that was created the first time. This time the file is automatically found:

```text
▶ sam deploy

        Deploying with following values
        ===============================
        Stack name                 : sam-app
        Region                     : ap-southeast-2
        Confirm changeset          : True
        Deployment s3 bucket       : aws-sam-cli-managed-default-samclisourcebucket-15mcwc8hibmci
        Capabilities               : ["CAPABILITY_IAM"]
        Parameter overrides        : {}

Initiating deployment
=====================

Waiting for changeset to be created..
Error: No changes to deploy. Stack sam-app is up to date
```

## Summary

That completes my update to Part I showing the updated procedure for SAM CLI. I covered some of the same material from creating a Virtualenv, the updated procedure to create the example project using sam init, and the new method of using sam build and the guided sam deploy.
