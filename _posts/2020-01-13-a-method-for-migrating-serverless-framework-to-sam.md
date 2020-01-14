---
layout: post
title: "A method for migrating Serverless Framework to SAM"
date: 2020-01-13
author: Alex Harvey
tags: sam lambda serverless-framework
---

Documents a method of migrating a Serverless Framework app with an API Gateway to AWS SAM.

- ToC
{:toc}

## Introduction

Serverless Framework and AWS SAM are two popular frameworks for deploying Serverless applications into the AWS cloud. If you have no requirement for multi-cloud or to migrate your application to a different cloud in the future, both tools are similar and have their advantages and disadvantages. AWS CloudFormation users may prefer AWS SAM for consistency, since SAM uses a marked-up CloudFormation as its DSL. Python developers may prefer SAM because it is written in Python whereas Serverless Framework may appeal more to Node.JS developers (See my [earlier](https://alexharv074.github.io/2019/03/02/introduction-to-sam-part-i-using-the-sam-cli.html) blog series for an introduction to SAM.)

Whatever the motivations, in this post I document a method I adopted for migrating from Serverless Framework => SAM, and show how to do that for a simple Hello World Serverless app. At the time of writing, I am not sure if it is the best way but it is one way that I was able to migrate a complex app and API Gateway into SAM.

## Example hello world app

In this section I describe the example Hello World app that I will be migrating.

### Install Serverless Framework

If you do not already have it installed, install Serverless Framework (on Mac OS X) this way:

```text
curl -o- -L https://slss.io/install | bash
```

### Code example

My Serverless Framework code example is a minor modification of the example app provided by Serverless Framework:

#### Function

Here is the Node.JS Lambda function:

```js
'use strict';

module.exports.hello = (event, context, callback) => {
  const response = {
    statusCode: 200,
    body: JSON.stringify({
      message: 'Go Serverless v1.0! Your function executed successfully!',
      input: event,
    }),
  };
};
```

#### Serverless.yml

And the `serverless.yml` file:

```yaml
---
service: helloworld

provider:
  name: aws
  runtime: nodejs12.x
  region: ap-southeast-2

functions:
  hello:
    handler: handler.hello
    events:
      - http:
          path: /
          method: get
```

### Deploy the app

Next, I deploy the app so that I can observe how Serverless has code-generated it:

```text
▶ sls deploy
Serverless: Packaging service...
Serverless: Excluding development dependencies...
Serverless: Creating Stack...
Serverless: Checking Stack create progress...
........
Serverless: Stack create finished...
Serverless: Uploading CloudFormation file to S3...
Serverless: Uploading artifacts...
Serverless: Uploading service helloworld.zip file to S3 (325 B)...
Serverless: Validating template...
Serverless: Updating Stack...
Serverless: Checking Stack update progress...
...........................
Serverless: Stack update finished...
Service Information
service: helloworld
stage: dev
region: ap-southeast-2
stack: helloworld-dev
resources: 10
api keys:
  None
endpoints:
  GET - https://5yca3b0997.execute-api.ap-southeast-2.amazonaws.com/dev/
functions:
  hello: helloworld-dev-hello
layers:
  None
Serverless: Run the "serverless" command to setup monitoring, troubleshooting and testing.
```

I make a note at this point that the stack name is `helloworld-dev`.

### Generated CloudFormation

A key insight in migration from Serverless Framework => SAM is that both Serverless Framework and SAM are opinionated generators of CloudFormation code. The challenges arise because their opinions are slightly different! But after deploying the Serverless stack, I have generated this code in the `.serverless` directory:

```text
▶ find .serverless
.serverless
.serverless/cloudformation-template-update-stack.json
.serverless/cloudformation-template-create-stack.json
.serverless/serverless-state.json
.serverless/helloworld.zip
```

Serverless Framework, as can be immediately seen, is more Terraform-like in its design. There is a state file, and code for creating and updating the stack. SAM, meanwhile, offloads all of this state management to the AWS CloudFormation service backend. So we never receive an update and create version of the CloudFormation template. (See my SAM series for how to generate CloudFormation templates using SAM.)

## Install SAM and dependencies

Now I move on to install SAM and dependencies in a Virtualenv. I have:

```text
▶ cat requirements.txt
awscli
aws-sam-cli
cfn-flip
```

And:

```bash
#!/usr/bin/env bash
virtualenv venv
. venv/bin/activate
pip install -r requirements.txt
```

And I source that into the shell:

```text
▶ source venv.sh
```

## Note about aws-cfn-template-flip

By adding `cfn-flip` I installed the [aws-cfn-template-flip](https://github.com/awslabs/aws-cfn-template-flip) useful utility for converting CloudFormation templates from JSON <=> YAML and vice versa.

## Flip the update stack template

So I use that utility next to get the generated CloudFormation as YAML:

```text
▶ cfn-flip -y .serverless/cloudformation-template-update-stack.json > template.yaml
```

## Digression on using this as is

At this point, one may be tempted to use this generated template as-is. And don't let me stop you if it suits your requirements! However, I decided against this approach because:

1. This is not SAM code. It is pure CloudFormation code and while it would be easy to make it all work, the whole point of using SAM is that you don't want all that CloudFormation code!
1. The generation after CFN Flip used a fair bit of unreadable CloudFormation DSL syntax that I would have had to clean up.

So I continue.

## Get the API ID

I noted above that my stack name is `helloworld-dev` and now I used that to get the ID of the API Gateway resource in the Serverless CloudFormation stack:

```text
▶ aws cloudformation list-stack-resources --stack-name helloworld-dev \
    --query 'StackResourceSummaries[?ResourceType==`AWS::ApiGateway::RestApi`].PhysicalResourceId' --output text
5yca3b0997
```

## Export the Swagger document

Now, it turns out that the AWS CLI provides a utility [`aws apigateway get-export`](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-export-api.html) that allows me to export an API Gateway in OpenAPI format. To do that:

```text
▶ aws apigateway get-export --parameters extensions='apigateway' \
    --rest-api-id 5yca3b0997 --stage-name dev --export-type swagger swagger.json
{
    "contentType": "application/octet-stream",
    "contentDisposition": "attachment; filename=\"swagger_2020-01-13T13:15:44Z.json\""
}
```

## Flip that too

And I'll want that one in YAML too so I flip it just as if it were a CloudFormation template:

```text
▶ cfn-flip -y swagger.json > swagger.yml
```

## Create the SAM project

Now it's time to create the SAM project that all of this migrated code will live in.

### Sam init

Initialise the repo:

```text
▶ sam init --runtime nodejs8.10                                        
```

(Note that at the time of writing Serverless & SAM didn't support the same Node.JS runtimes so I'm going to use nodejs8.10 and that should be fine.)

### Copy function

I copy the function to its new location in SAM:

```text
▶ cp handler.js sam-app/hello-world/app.js
```

## Initial template

And I make some minor tweaks to the initial SAM template that was generated for me:

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: Hello World Demo

Globals:
  Function:
    Timeout: 3

Resources:
  HelloWorldFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: hello-world/
      Handler: app.lambdaHandler
      Runtime: nodejs8.10
      Events:
        HelloWorld:
          Type: Api
          Properties:
            Path: /hello
            Method: get
```

## Edit to reference an explicit API

SAM of course has its implicit and explicit APIs. I explained this quite well in a Stack Overflow answer [here](https://stackoverflow.com/a/55062868/3787051). So I paste in the above API Gateway resource declaration and change the function to reference this explicit API:

```diff
diff --git a/sam-app/template.yaml b/sam-app/template.yaml
index 7abcc35..13ed9c9 100644
--- a/sam-app/template.yaml
+++ b/sam-app/template.yaml
@@ -17,5 +17,27 @@ Resources:
         HelloWorld:
           Type: Api
           Properties:
-            Path: /hello
-            Method: get
+            Path: /{proxy+}
+            Method: ANY
+            RestApiId: !Ref ApiGatewayRestApi
```

## Create a Serverless API

Then I create a Serverless API resource like this:

```yaml
    Type: AWS::Serverless::Api
    Properties:
      Name: HelloAPI
```

And append to it the swagger.yml:

```text
▶ cat swagger.yml >> sam-app/template.yaml
```

And I fix up the formatting to have this:

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: Hello World Demo

Globals:
  Function:
    Timeout: 3

Resources:
  HelloWorldFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: hello-world/
      Handler: app.lambdaHandler
      Runtime: nodejs8.10
      Events:
        HelloWorld:
          Type: Api
          Properties:
            Path: /{proxy+}
            Method: ANY
            RestApiId: !Ref HelloWorldAPI

  HelloWorldAPI:
    Type: AWS::Serverless::Api
    Properties:
      Name: HelloAPI
      DefinitionBody:
        swagger: '2.0'
        info:
          version: '2020-01-13T13:15:44Z'
          title: dev-helloworld
        host: 5yca3b0997.execute-api.ap-southeast-2.amazonaws.com
        basePath: /dev
        schemes:
          - https
        paths:
          /:
            get:
              responses: {}
              x-amazon-apigateway-integration:
                uri: arn:aws:apigateway:ap-southeast-2:lambda:path/2015-03-31/functions/arn:aws:lambda:ap-southeast-2:123456789012:function:helloworld-dev-hello/invocations
                passthroughBehavior: when_no_match
                httpMethod: POST
                type: aws_proxy
        x-amazon-apigateway-policy:
          Version: '2012-10-17'
          Statement:
            - Effect: Allow
              Principal: '*'
              Action: execute-api:Invoke
              Resource: arn:aws:execute-api:ap-southeast-2:123456789012:5yca3b0997/*/*/*
              Condition:
                IpAddress:
                  aws:SourceIp:
                    - '0.0.0.0/0'
                    - ::/0
```

## A few tweaks

So I do the following tweaks:

- Delete the host line
- Replace the version string '2020-01-13T13:15:44Z' with '1.0'
- Sed searches and replaces:
    * `%s/ap-southeast-2/${AWS::Region}/gc`
    * `%s/123456789012/${AWS::AccountId}/gc`
    * `%s/helloworld-dev/${AWS::StackName}/gc`

## Delete the Serverless stack

Then I delete the Serverless Framework stack:

```text
▶ aws cloudformation delete-stack --stack-name helloworld-dev
```

## And I'm done!

At this point I can sam build and sam deploy my new stack!

## See also

- Fernando Medina Corey, 28 Aug 2019, [Migrate a Simple SAM Application to the Serverless Framework](https://thenewstack.io/migrate-a-simple-sam-application-to-the-serverless-framework/).
