---
layout: post
title: "Adding hosted secrets rotation Lambda to an RDS stack"
date: 2020-11-23
author: Alex Harvey
tags: aws
---

This post aims to address gaps in the AWS documenation for adding a hosted Secrets Manager secret rotation Lambda function to an RDS stack. In the example, I take the simplest RDS database CloudFormation stack, and show how to add the hosted rotation Lambda to it, while explaining how all the pieces fit together.

## Rotation Lambda source code

The source code for the hosted rotation Lambdas is on GitHub [here](https://github.com/aws-samples/aws-secrets-manager-rotation-lambdas). It is good to have this code handy.

## Code example

I will begin with a simple RDS stack that contains only an RDS database instance. Here is that example:

```yaml
---
AWSTemplateFormatVersion: 2010-09-09
Description: Rotation Lambda example stack

Parameters:
  MasterUsername:
    NoEcho: true
    Description: The database Master Username
    Type: String
    MinLength: 1
    MaxLength: 41
  MasterUserPassword: 
    NoEcho: true
    Description: The database Master Password
    Type: String
    MinLength: 1
    MaxLength: 41
    AllowedPattern: '[^"@\/\\]+'

Resources:
  DBInstance:
    Type: AWS::RDS::DBInstance
    Properties:
      AllocatedStorage: 10
      DBInstanceClass: db.t2.micro
      Engine: mysql
      MasterUsername: !Ref MasterUsername
      MasterUserPassword: !Ref MasterUserPassword
      BackupRetentionPeriod: 0

Outputs:
  DatabaseEndpoint:
    Description: The database endpoint
    Value: !GetAtt DBInstance.Endpoint.Address
```

For the sake of this example, I will set the username and password on the command line for the first deployment only. Thus I deploy like this:

```text
▶ aws cloudformation deploy \
  --template cloudformation.yml \
  --stack-name test-stack \
  --parameter-overrides MasterUsername=admin MasterUserPassword=abcd1234

Waiting for changeset to be created..
Waiting for stack create/update to complete
Successfully created/updated stack - test-stack
```

## Putting username and password in Secrets Manager

### Create password with manage_secrets

Here I use a utility I wrote [manage_secrets](https://github.com/alexharv074/manage_secrets) to create and manage the initial secrets:

```text
▶ bash manage_secrets.sh -c database_password -D "Password for RDS database" -s '{"username":"admin","password":"abcd1234"}'
{
    "ARN": "arn:aws:secretsmanager:ap-southeast-2:885164491973:secret:database_password-bVTpex",
    "Name": "database_password",
    "VersionId": "b6fb1e62-f1b6-4673-963d-1eb7c9d651f1"
}
```

Notice I have created a JSON document for the secret string:

```json
{
  "username": "admin",
  "password": "abcd1234"
}
```

This structuring is one of the requirements of the hosted rotation Lambda functions. More on this later.

### Diffs to the template

I make the following changes to my template:

```diff
--- a/cloudformation.yml
+++ b/cloudformation.yml
@@ -2,20 +2,7 @@
 AWSTemplateFormatVersion: 2010-09-09
 Description: Rotation Lambda example stack

-Parameters:
-  MasterUsername:
-    NoEcho: true
-    Description: The database Master Username
-    Type: String
-    MinLength: 1
-    MaxLength: 41
-  MasterUserPassword:
-    NoEcho: true
-    Description: The database Master Password
-    Type: String
-    MinLength: 1
-    MaxLength: 41
-    AllowedPattern: '[^"@\/\\]+'
+Parameters: {}

 Resources:
   DBInstance:
@@ -24,8 +11,8 @@ Resources:
       AllocatedStorage: 10
       DBInstanceClass: db.t2.micro
       Engine: mysql
-      MasterUsername: !Ref MasterUsername
-      MasterUserPassword: !Ref MasterUserPassword
+      MasterUsername: '{% raw %}{{resolve:secretsmanager:database_password:SecretString:username}}{% endraw %}'
+      MasterUserPassword: '{% raw %}{{resolve:secretsmanager:database_password:SecretString:password}}{% endraw %}'
       BackupRetentionPeriod: 0

 Outputs:
```

### Dynamic references

Here I have updated the template with [dynamic references](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/dynamic-references.html) to Secrets Manager to get these secrets.

The dynamic references for the Secrets Manager secret have the form:

```text
{% raw %}{{resolve:secretsmanager:secret-id:secret-string:json-key:version-stage:version-id}}{% endraw %}
```

These fields are:

- `secret-id` (required)

The name or ARN that uniquely identifies the secret.

- `secret-string` (optional)

Currently, the only supported value is `SecretString`, which is the default.

- `json-key` (optional)

Specifies the key name of the key-value pair whose value you want to retrieve. If not specified, the entire secret text is retrieved.

- `version-stage` (optional)

Specifies the secret version that you want to retrieve by the staging label attached to the version. Staging labels are used to keep track of different versions during the rotation process. If you use version-stage then don't specify version-id. If you don't specify either a version stage or a version ID, then the default is to retrieve the version with the version stage value of AWSCURRENT.

- `version-id` (optional)

Specifies the unique identifier of the version of the secret that you want to use in stack operations. If you specify `version-id`, then don't specify `version-stage`. If you don't specify either a version stage or a version ID, then the default is to retrieve the version with the version stage value of `AWSCURRENT`.

So, my two references are:

```yaml
{% raw %}MasterUsername: '{{resolve:secretsmanager:database_password:SecretString:username}}'
MasterUserPassword: '{{resolve:secretsmanager:database_password:SecretString:password}}'{% endraw %}
```

|field|value|comment|
|=====|=====|=======|
|`secret-id`|`database_password`|The name I used to create the secret above|
|`secret-string`|`SecretString`|Always has to be this|
|`json-key`|`username` and `password`|The key from the JSON doc above|
|`version-stage`|not used||
|`version-id`|not used||

### Updating the stack

Now, here is a real gotcha. Despite that the values are _not_ changing, CloudFormation sees that the `MasterUsername` field is changing here, and insists on recreating the database instance!

```text
▶ aws cloudformation deploy \
  --template cloudformation.yml \
  --stack-name test-stack

Waiting for changeset to be created..
Waiting for stack create/update to complete
Successfully created/updated stack - test-stack
```

## Secrets rotation

### Secrets rotation resources

Four additional resources are provided to faciliate secrets rotation in CloudFormation:

New Secrets Manager resource types supported in CloudFormation

- `AWS::SecretsManager::Secret` — Create a secret and store it in Secrets Manager.
- `AWS::SecretsManager::ResourcePolicy` — Create a resource-based policy and attach it to a secret. Resource-based policies enable you to control access to secrets (not used in this example).
- `AWS::SecretsManager::SecretTargetAttachment` — Configure Secrets Manager to rotate the secret automatically.
- `AWS::SecretsManager::RotationSchedule` — Define the Lambda function that will be used to rotate the secret.

### New template

The changes I need to make are to add these resources so that I end up with this:

```yaml
---
AWSTemplateFormatVersion: 2010-09-09
Description: Rotation Lambda example stack
Transform: AWS::SecretsManager-2020-07-23

Parameters: {}

Resources:
  DBInstance:
    Type: AWS::RDS::DBInstance
    Properties:
      AllocatedStorage: 10
      DBInstanceClass: db.t2.micro
      Engine: mysql
      MasterUsername: !Sub "{% raw %}{{resolve:secretsmanager:${SecretsManagerSecret}:SecretString:username}}"
      MasterUserPassword: !Sub "{{resolve:secretsmanager:${SecretsManagerSecret}:SecretString:password}}{% endraw %}"
      BackupRetentionPeriod: 0

  SecretsManagerSecret:
    Type: AWS::SecretsManager::Secret
    Properties:
      Description: Password for RDS Database
      GenerateSecretString:
        SecretStringTemplate: '{"username": "admin"}'
        GenerateStringKey: 'password'
        PasswordLength: 16
        ExcludeCharacters: '"@/\'

  SecretRDSInstanceAttachment:
    Type: AWS::SecretsManager::SecretTargetAttachment
    Properties:
      SecretId: !Ref SecretsManagerSecret
      TargetId: !Ref DBInstance
      TargetType: AWS::RDS::DBInstance

  MySecretRotationSchedule:
    Type: AWS::SecretsManager::RotationSchedule
    Properties:
      SecretId: !Ref SecretsManagerSecret
      HostedRotationLambda:
        RotationType: MySQLSingleUser
      RotationRules:
        AutomaticallyAfterDays: 30

Outputs:
  DatabaseEndpoint:
    Description: The database endpoint
    Value: !GetAtt DBInstance.Endpoint.Address
```

### Finding the Lambda function

Under `HostedRotationLambda` and `RotationType` we have `MySQLSingleUser`. It turns out this is actually part of the name of the actual Lambda function. The source code can be found at:

```bash
target_type=RDS
rotation_type=RotationType
https://github.com/aws-samples/aws-secrets-manager-rotation-lambdas/blob/master/SecretsManager${target_type}${rotation_type}/lambda_function.py
```

### Inspecting the Lambda function

It turns out there is more important documentation in the source code:

```text
This handler uses the single-user rotation scheme to rotate an RDS MySQL user credential. This rotation scheme
logs into the database as the user and rotates the user's own password, immediately invalidating the user's
previous password.

The Secret SecretString is expected to be a JSON string with the following format:
{
    'engine': <required: must be set to 'mysql'>,
    'host': <required: instance host name>,
    'username': <required: username>,
    'password': <required: password>,
    'dbname': <optional: database name>,
    'port': <optional: if not specified, default port 3306 will be used>
}

Args:
    event (dict): Lambda dictionary of event parameters. These keys must include the following:
        - SecretId: The secret ARN or identifier
        - ClientRequestToken: The ClientRequestToken of the secret version
        - Step: The rotation step (one of createSecret, setSecret, testSecret, or finishSecret)
    context (LambdaContext): The Lambda runtime information

Raises:
    ResourceNotFoundException: If the secret with the specified arn and stage does not exist
    ValueError: If the secret is not properly configured for rotation
    KeyError: If the secret json does not contain the expected keys
```

### Understanding the secret string

This secret string is a generated JSON doc. But we must provide two parts to this process in the `GenerateSecretString`. Our code begins by providing these two pieces of information:

```yaml
GenerateSecretString:
  SecretStringTemplate: '{"username": "admin"}'
  GenerateStringKey: 'password'
```

Our JSON doc begins as the `SecretStringTemplate`:

```json
{"username": "admin"}
```

Secrets Manager in the backend then creates an additional key mentioned in the `GenerateStringKey` field. Thus the JSON doc is expanded to become:

```json
{
  "username": "admin",
  "password": "<generated_by_secrets_manager>"
}
```

Finally, code in the CloudFormation backend comes along and adds additional data to this document. Let's deploy the changes first:

### Deploying changes

Once again, there is no way of deploying these changes without recreating the database. This time, the issue is that a new secret needs to be created because the original secret was created outside of CloudFormation.

```text
▶ aws cloudformation deploy \
  --template cloudformation.yml \
  --stack-name test-stack \
  --capabilities CAPABILITY_AUTO_EXPAND CAPABILITY_IAM

Waiting for changeset to be created..
Waiting for stack create/update to complete
Successfully created/updated stack - test-stack
```

### Generated secret string

Returning to the secret string, let's have a look at what was created:

```text
▶ bash manage_secrets.sh -l
[
    "database_password",
    "SecretsManagerSecret-q1JExknBpLCi"
]
▶ bash manage_secrets.sh -g SecretsManagerSecret-q1JExknBpLCi | jq .
{
  "password": "cR34e|s0=zq9{-PN",
  "engine": "mysql",
  "port": 3306,
  "dbInstanceIdentifier": "td1gg242cepfrqg",
  "host": "td1gg242cepfrqg.cbpioybw5u13.ap-southeast-2.rds.amazonaws.com",
  "username": "admin"
}
```

So we can see the `username` key is as I provided it in the template; `password` is as generated by `GenerateStringKey`; and remaining fields needed by the Lambda function are created by CloudFormation.

I found this all quite confusing, and thus my motivation for writing this post!

### Other gotchas

Note that it is not possible to change the Name of the secret once it is created! 

## Summary

Well that completes all of what I wanted to document. Here, I have written a post addressing gaps in the AWS documentation around the hosted rotation Lambda functions, while showing the reader three ways to set a password on an RDS database in CloudFormation.

## See also

- https://aws.amazon.com/blogs/security/how-to-create-and-retrieve-secrets-managed-in-aws-secrets-manager-using-aws-cloudformation-template/
- https://docs.aws.amazon.com/secretsmanager/latest/userguide/integrating_cloudformation.html
- https://docs.aws.amazon.com/secretsmanager/latest/userguide/terms-concepts.html
- https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/dynamic-references.html
- https://github.com/aws-samples/aws-secrets-manager-rotation-lambdas
