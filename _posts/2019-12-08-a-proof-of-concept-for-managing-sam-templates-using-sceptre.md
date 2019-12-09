---
layout: post
title: "A proof of concept for managing SAM templates using Sceptre"
date: 2019-12-08
author: Alex Harvey
tags: sam sceptre
---

This post documents a proof of concept for managing AWS SAM templates using [Sceptre](https://sceptre.cloudreach.com/2.2.1/index.html).

{:toc}
- ToC

## Overview

Users of AWS CloudFormation and also AWS SAM (Serverless Application Model) would know that a major weakness of these tools is data handling. Data must be passed into CloudFormation and SAM stacks as a flat array of string parameters. This makes handling of environment-specific data difficult, if not impossible. Another significant defect is lack of programming features in the CloudFormation DSL. For loops and if statements don't exist, and there are no user-defined variables and so on.

These issues have led to various abstraction layers for code-generating CloudFormation being produced. I have written about [Troposphere](https://github.com/cloudtools/troposphere) [here](https://alexharv074.github.io/2018/12/01/configuration-management-with-troposphere-and-jerakia.html) before. I also discussed a [Bash](https://alexharv074.github.io/2018/12/15/hierarchical-data-resolution-using-the-bash-shell.html) solution.

Yet another alternative that I encountered recently is [Sceptre](https://github.com/Sceptre/sceptre).

Based on my limited experience so far, Sceptre appears to be an excellent tool, and another good alternative to Terraform. However, its support for SAM and particularly its documentation is lacking.

The purpose of this post is to show how I set up Sceptre to manage an example hello world SAM stack. I also briefly discuss some of the issues I encountered.

## Source code

The source code to go with this blog post is online at GitHub [here](https://github.com/alexharv074/sceptre-sam-poc).

## Sceptre SAM support

Sceptre is an abstraction layer above AWS CloudFormation. At the time of writing (8th December, 2019), Sceptre has basic support since 2.1.0 (see [this](https://github.com/Sceptre/sceptre/commit/1ae2a4cfbc889d556bf383e47665187502ccc5bc) commit) for understanding the SAM transformer but no apparent integration with the SAM CLI. This means that a custom [`sceptre_handler`](https://sceptre.cloudreach.com/2.2.1/docs/templates.html#python) needs to be written to call the SAM CLI. More on that [below](#create-the-sceptre-handler).

## Python virtualenv

I use a Python Virtualenv to avoid dependency hell with my system Python. I create a file venv.sh:

```bash
#!/usr/bin/env bash
virtualenv venv
. venv/bin/activate
pip install -r requirements.txt
```

And a file requirements.txt:

```text
sceptre
awscli
aws-sam-cli
pytest
pytest-mock
sam
```

I source venv.sh into the running shell and have Sceptre installed:

```text
▶ sceptre --version
Sceptre, version 2.2.1
```

And I have the SAM CLI installed:

```text
▶ sam --version
SAM CLI, version 0.37.0
```

## Create a SAM project

I start by using sam init to create an example "hello world" SAM app. See my earlier posts [here](https://alexharv074.github.io/2019/03/02/introduction-to-sam-part-i-using-the-sam-cli.html) and [here](https://alexharv074.github.io/2019/12/07/introduction-to-sam-part-iv-updates-to-sam-package-and-deploy-in-sam-cli-0.33.1.html) for more on this workflow.

I can do that in one line using:

```text
▶ echo Y | sam init --runtime python3.7 --name sam --app-template hello-world

Quick start templates may have been updated. Do you want to re-download the latest [Y/n]:
-----------------------
Generating application:
-----------------------
Name: sam
Runtime: python3.7
Dependency Manager: pip
Application Template: hello-world
Output Directory: .

Next steps can be found in the README file at ./sam/README.md
```

## Create the S3 bucket

The S3 bucket is a dependency of sam package and for the purposes of this proof of concept I have created the bucket manually as follows:

```text
▶ aws s3 mb s3://alexharvey3118
make_bucket: alexharvey3118
```

Note that I have had to hardcode the bucket name in a bunch of places at this time. See below. I suspect there would be a cleaner way of using Sceptre to do this.

## Create a new Sceptre project

I create the Sceptre project manually as follows:

```text
▶ mkdir -p config/dev src
```

Create a config/config.yaml as:

```yaml
project_code: sceptre-poc
```

Create a config/dev/config.yaml as:

```yaml
region: ap-southeast-2
template_bucket_name: alexharvey3118
```

And finally config/dev/hello.yaml as:

```yaml
template_path: hello.py
```

That creates a directory structure:

```text
▶ tree config
config
├── config.yaml
└── dev
    ├── config.yaml
    └── hello.yaml

1 directory, 3 files
```

## Create the Sceptre handler

Then I created a Python template handler to do the SAM build and package:

```python
#!/usr/bin/env python3

import subprocess
import os
import yaml
import json

S3_BUCKET = 'alexharvey3118' # FIXME. There might be a way
                             # of parameterising the bucket name.

def sceptre_handler(sceptre_user_data):
    os.chdir('sam')
    build = "sam build"
    package = "sam package --s3-bucket %s \
--output-template-file /tmp/packaged.yaml" % S3_BUCKET
    subprocess.run(build.split(" "))
    subprocess.run(package.split(" "))
    stream = open('/tmp/packaged.yaml', 'r')
    with open('/tmp/packaged.yaml') as f:
        return json.dumps(yaml.load(f, Loader=yaml.FullLoader))

if __name__ == '__main__':
    print(sceptre_handler('dummy'))
```

## Create the stack

I can then use Sceptre to build and create the SAM stack:

```text
▶ sceptre create dev/hello.yaml
Do you want to create 'dev/hello.yaml' [y/N]: y
[2019-12-09 15:41:35] - dev/hello - Creating Stack
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

Uploading to 14d0e1b8ec9725c4c6764606d3ebc448  532293 / 532293.0  (100.00%)

Successfully packaged artifacts and wrote output template to file /tmp/packaged.yaml.
Execute the following command to deploy the packaged template
sam deploy --template-file /tmp/packaged.yaml --stack-name <YOUR STACK NAME>

[2019-12-09 15:41:45] - dev/hello sceptre-poc-dev-hello AWS::CloudFormation::Stack CREATE_IN_PROGRESS User Initiated
[2019-12-09 15:41:49] - dev/hello sceptre-poc-dev-hello AWS::CloudFormation::Stack CREATE_IN_PROGRESS Transformation succeeded
[2019-12-09 15:41:53] - dev/hello HelloWorldFunctionRole AWS::IAM::Role CREATE_IN_PROGRESS
[2019-12-09 15:41:53] - dev/hello HelloWorldFunctionRole AWS::IAM::Role CREATE_IN_PROGRESS Resource creation Initiated
[2019-12-09 15:42:10] - dev/hello HelloWorldFunctionRole AWS::IAM::Role CREATE_COMPLETE
[2019-12-09 15:42:10] - dev/hello HelloWorldFunction AWS::Lambda::Function CREATE_IN_PROGRESS
[2019-12-09 15:42:10] - dev/hello HelloWorldFunction AWS::Lambda::Function CREATE_IN_PROGRESS Resource creation Initiated
[2019-12-09 15:42:14] - dev/hello HelloWorldFunction AWS::Lambda::Function CREATE_COMPLETE
[2019-12-09 15:42:14] - dev/hello ServerlessRestApi AWS::ApiGateway::RestApi CREATE_IN_PROGRESS
[2019-12-09 15:42:14] - dev/hello ServerlessRestApi AWS::ApiGateway::RestApi CREATE_IN_PROGRESS Resource creation Initiated
[2019-12-09 15:42:14] - dev/hello ServerlessRestApi AWS::ApiGateway::RestApi CREATE_COMPLETE
[2019-12-09 15:42:18] - dev/hello ServerlessRestApiDeployment47fc2d5f9d AWS::ApiGateway::Deployment CREATE_IN_PROGRESS
[2019-12-09 15:42:18] - dev/hello HelloWorldFunctionHelloWorldPermissionProd AWS::Lambda::Permission CREATE_IN_PROGRESS
[2019-12-09 15:42:18] - dev/hello HelloWorldFunctionHelloWorldPermissionProd AWS::Lambda::Permission CREATE_IN_PROGRESS Resource creation Initiated
[2019-12-09 15:42:18] - dev/hello ServerlessRestApiDeployment47fc2d5f9d AWS::ApiGateway::Deployment CREATE_IN_PROGRESS Resource creation Initiated
[2019-12-09 15:42:18] - dev/hello ServerlessRestApiDeployment47fc2d5f9d AWS::ApiGateway::Deployment CREATE_COMPLETE
[2019-12-09 15:42:18] - dev/hello ServerlessRestApiProdStage AWS::ApiGateway::Stage CREATE_IN_PROGRESS
[2019-12-09 15:42:18] - dev/hello ServerlessRestApiProdStage AWS::ApiGateway::Stage CREATE_IN_PROGRESS Resource creation Initiated
[2019-12-09 15:42:18] - dev/hello ServerlessRestApiProdStage AWS::ApiGateway::Stage CREATE_COMPLETE
[2019-12-09 15:42:27] - dev/hello HelloWorldFunctionHelloWorldPermissionProd AWS::Lambda::Permission CREATE_COMPLETE
[2019-12-09 15:42:27] - dev/hello sceptre-poc-dev-hello AWS::CloudFormation::Stack CREATE_COMPLETE
```

And I can delete the stack:

```text
▶ sceptre delete dev/hello.yaml
The following stacks, in the following order, will be deleted:
dev/hello

Do you want to delete 'dev/hello.yaml' [y/N]: y
[2019-12-09 15:43:48] - dev/hello - Deleting stack
[2019-12-09 15:43:49] - dev/hello sceptre-poc-dev-hello AWS::CloudFormation::Stack DELETE_IN_PROGRESS User Initiated
[2019-12-09 15:43:54] - dev/hello ServerlessRestApiProdStage AWS::ApiGateway::Stage DELETE_IN_PROGRESS
[2019-12-09 15:43:54] - dev/hello HelloWorldFunctionHelloWorldPermissionProd AWS::Lambda::Permission DELETE_IN_PROGRESS
[2019-12-09 15:43:54] - dev/hello ServerlessRestApiProdStage AWS::ApiGateway::Stage DELETE_COMPLETE
[2019-12-09 15:43:54] - dev/hello ServerlessRestApiDeployment47fc2d5f9d AWS::ApiGateway::Deployment DELETE_IN_PROGRESS
[2019-12-09 15:43:54] - dev/hello ServerlessRestApiDeployment47fc2d5f9d AWS::ApiGateway::Deployment DELETE_COMPLETE
[2019-12-09 15:44:02] - dev/hello HelloWorldFunctionHelloWorldPermissionProd AWS::Lambda::Permission DELETE_COMPLETE
[2019-12-09 15:44:02] - dev/hello ServerlessRestApi AWS::ApiGateway::RestApi DELETE_IN_PROGRESS
[2019-12-09 15:44:06] - dev/hello ServerlessRestApi AWS::ApiGateway::RestApi DELETE_COMPLETE
[2019-12-09 15:44:06] - dev/hello HelloWorldFunction AWS::Lambda::Function DELETE_IN_PROGRESS
[2019-12-09 15:44:06] - dev/hello HelloWorldFunction AWS::Lambda::Function DELETE_COMPLETE
[2019-12-09 15:44:06] - dev/hello HelloWorldFunctionRole AWS::IAM::Role DELETE_IN_PROGRESS
[2019-12-09 15:44:10] - dev/hello - delete complete
```

## Discussion

At the time of writing, it appears that SAM integration is rudimentary and the Sceptre and SAM workflows compete a little with each other. A Sceptre user no doubt would still want to also use the SAM CLI directly for such purposes as running unit tests against the Lambda function, running the Lambda function in a local Docker container and so on.

The advantage of Sceptre in managing a SAM stack would be that environment-specific data can be handled in Sceptre's model and passed in to generated SAM templates as CloudFormation parameters. It also would be great fit if Sceptre is used more generally to manage other CloudFormation stacks and your requirement is to share outputs between stacks and so on.

But there are some disadvantages too, most notably that Sceptre requires the _packaged_ version of the SAM template to be available, and this template is generated by `sam build` and `sam package`. Furthermore, `sam package` is somewhat deprecated since SAM CLI 0.33.1 in favour of the `samconfig.toml` file that is generated by `sam deploy --guided`.

The other obvious disadvantage is that Sceptre's Jinja2 can't be used in the SAM template.

Perhaps this could be improved with better integrations with SAM. If Sceptre knew how to call `sam build` and `sam deploy` directly, these issues could be resolved and a seamless user experience could be had.

Note that at the time of writing, my code depended on an unmerged pull request that I raised [here](https://github.com/Sceptre/sceptre/pull/871). Without that patch, an error message would be see:

```text
ValueError: list.remove(x): x not in list
```

## Related docs

- [Sceptre Wordpress](https://github.com/cloudreach/sceptre-wordpress-example) code example that I based some of this code on.
- [Sceptre Getting Started Guide](https://sceptre.cloudreach.com/2.2.1/docs/get_started.html).
- [sam package](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-cli-command-reference-sam-package.html) documentation.
