---
layout: post
title: "Migrating S3 Bucket ACLs"
date: 2024-08-11
author: Alex Harvey
tags: aws s3
---

I recently had a task to migrate [deprecated ACLs](https://aws.amazon.com/blogs/aws/heads-up-amazon-s3-security-changes-are-coming-in-april-of-2023/) on all S3 buckets to Bucket Policies with the equivalent permission grants. I found documentation challenging around all of this and ended up on a call with a helpful engineer from AWS support. In case this might help others or my future self, I am documenting what I learnt in this blog post.

## Deprecated ACLs

In April 2023, AWS changed the default Object Ownership for all newly created S3 buckets to be *ACLs disabled - Bucket owner enforced*. According to [AWS docs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/about-object-ownership.html):

> A majority of modern use cases in Amazon S3 no longer require the use of ACLs, and we recommend that you keep ACLs disabled except in unusual circumstances where you must control access for each object individually. With ACLs disabled, you can use policies to more easily control access to every object in your bucket, regardless of who uploaded the objects in your bucket.

Note that Object Ownership determines who owns the objects uploaded to your bucket and how access is managed.

## Understanding ACLs

Many AWS users will be familiar with IAM and S3 bucket policies, and less familiar with the older style ACLs. (These are very old, and pre-date S3 bucket policies as a feature.) While they both control access, ACLs and Bucket Policies use different terminology and syntax, and Bucket Policies offer more flexibility in many cases.

The following table shows a comparison of the main features of ACLs and bucket policies:

| **Concept**                     | **ACLs**                                                                 | **S3 Bucket Policies**                                                  |
|---------------------------------|--------------------------------------------------------------------------|--------------------------------------------------------------------------|
| **Canonical User ID** vs **Account ID** | Canonical User ID (e.g., `5059937e6966c6fe4d5f151fc8d221478f6b6f86cadcea51fff22b03585d32f7`) | Account ID (e.g., `123456789012`) used as part of IAM ARN (e.g., `arn:aws:iam::123456789012:root`) |
| **Permissions**                 | Specific permissions like `READ`, `WRITE`, `FULL_CONTROL` (e.g., `FULL_CONTROL`) | Fine-grained actions like `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` (e.g., `s3:PutObject`) |
| **Grantee** vs **Principal**    | Grantee, which could be a Canonical User, AWS account, Group, or AllUsers | Principal, which can be an IAM user, role, service, or `*` (wildcard)    |
| **Authenticated Users group** vs **\*** | `AuthenticatedUsers` group URI (`http://acs.amazonaws.com/groups/global/AuthenticatedUsers`) | Wildcard `*` represents any user (all authenticated users or services)   |
| **Scope of Control**            | Applied at the object or bucket level, with limited flexibility         | Applied at the bucket level, allows for more detailed and flexible permissions |

## Object-level permissions

It is worth emphasising that a key difference between ACLs and Bucket Policies is that ACLs can operate at the level of objects, and each object can have its own ACL. Whereas S3 Bucket Policies always operate at the level of the S3 bucket. This means that if you have a use-case that requires object-level ACLs, the ACLs cannot be replaced with policies.

## Two kinds of permissions

The following table is taken from the docs and is important for understanding how to interpret and rewrite ACL permissions as S3 bucket policy permissions:

| **ACL Permission** | **Corresponding Access Policy Permissions When the ACL Permission is Granted on a Bucket** | **Corresponding Access Policy Permissions When the ACL Permission is Granted on an Object** |
|--------------------|------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------|
| **READ**           | `s3:ListBucket`, `s3:ListBucketVersions`, and `s3:ListBucketMultipartUploads`                  | `s3:GetObject` and `s3:GetObjectVersion`                                                        |
| **WRITE**          | `s3:PutObject`<br><br>Bucket owner can create, overwrite, and delete any object in the bucket, and object owner has `FULL_CONTROL` over their object.<br><br>In addition, when the grantee is the bucket owner, granting `WRITE` permission in a bucket ACL allows the `s3:DeleteObjectVersion` action to be performed on any version in that bucket. | Not applicable |
| **READ_ACP**       | `s3:GetBucketAcl`                                                                               | `s3:GetObjectAcl` and `s3:GetObjectVersionAcl`                                                  |
| **WRITE_ACP**      | `s3:PutBucketAcl`                                                                               | `s3:PutObjectAcl` and `s3:PutObjectVersionAcl`                                                  |
| **FULL_CONTROL**   | Equivalent to granting `READ`, `WRITE`, `READ_ACP`, and `WRITE_ACP` ACL permissions. Accordingly, this ACL permission maps to a combination of corresponding access policy permissions. | Equivalent to granting `READ`, `READ_ACP`, and `WRITE_ACP` ACL permissions. Accordingly, this ACL permission maps to a combination of corresponding access policy permissions. |

## Canned ACLs

AWS provides eight (8) so-called canned ACLs. Most of these are very old, some are dangerously wide-open and not recommended, and only two of them are commonly used today. The canned ACLs are documented [here](https://docs.aws.amazon.com/AmazonS3/latest/userguide/acl-overview.html#canned-acl). The two ACLs you are likely to still see in use today are the `Private` ACL, because it was the default prior to the April 2023 change, and the `LogDeliveryWrite` ACL, commonly used for S3 access logging.

The follow section focuses on exactly how to rewrite these 2 ACLs as bucket policies.

### Private ACL

Using `get-bucket-acl` we can see what the Private canned ACL looks like:

```js
% aws s3api get-bucket-acl --bucket my-bucket-abc123
{
  "Owner": {
    "DisplayName": "MyAccount",
    "ID": "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
  },
  "Grants": [
    {
      "Grantee": {
        "DisplayName": "MyAccount",
        "ID": "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
        "Type": "CanonicalUser"
      },
      "Permission": "FULL_CONTROL"
    }
  ]
}
```

It is important to understand what the Canonical User ID is. It is the 12-digit AWS Account ID, but obfuscated, as explained in the docs [here](https://docs.aws.amazon.com/accounts/latest/reference/manage-acct-identifiers.html#FindCanonicalId). In other words, it is the Account Root. So, the default Private ACL is essentially granting the Account Root full control of the S3 bucket. It is thus rewritten as an S3 bucket policy as follows:

```yaml
PolicyDocument:
  Version: '2012-10-17'
  Statement:
    - Effect: Allow
      Principal:
        AWS: arn:aws:iam::123456789012:root
      Action:
        - 's3:*'
      Resource:
        - 'arn:aws:s3:::my-bucket-abc123/*'
        - 'arn:aws:s3:::my-bucket-abc123'
```

Note that `s3:*` grants full access to all S3 actions, and the resources listed include both the bucket itself and all objects within it.

### Log Delivery Write ACL

The only other canned ACL in common use is the `LogDeliveryWrite` ACL. Fortunately, the docs do provide recommendations on how to rewrite this particular ACL as a bucket policy, and is worth noting that the Bucket Policy is considerably less permissive than the ACL, which grants not only server access logging permissions, but full control to the account root.

In the case of a bucket with this ACL, the ACL might look like this:

```js
% aws s3api get-bucket-acl --bucket my-logging-bucket
{
  "Owner": {
    "DisplayName": "MyAccount",
    "ID": "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
  },
  "Grants": [
    {
      "Grantee": {
        "DisplayName": "MyAccount",
        "ID": "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
        "Type": "CanonicalUser"
      },
      "Permission": "FULL_CONTROL"
    },
    {
      "Grantee": {
        "Type": "Group",
        "URI": "http://acs.amazonaws.com/groups/s3/LogDelivery"
      },
      "Permission": "WRITE"
    },
    {
      "Grantee": {
        "Type": "Group",
        "URI": "http://acs.amazonaws.com/groups/s3/LogDelivery"
      },
      "Permission": "READ_ACP"
    }
  ]
}
```

And this policy would be written as this:

```yaml
PolicyDocument:
  Version: '2012-10-17'
  Statement:
    - Sid: S3ServerAccessLogsPolicy
      Effect: Allow
      Principal:
        Service: logging.s3.amazonaws.com
      Action:
        - s3:PutObject
      Resource: 'arn:aws:s3:::my-logging-bucket/*'
      Condition:
        StringEquals:
          aws:SourceAccount: '123456789012'
```

## Disabling ACLs

Finally, ACLs should be disabled, and to do that involves configuring the correct Object Ownership. To do this with CloudFormation:

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Resources:
  S3Bucket:
    Type: 'AWS::S3::Bucket'
    Properties:
      OwnershipControls:
        Rules:
          - ObjectOwnership: BucketOwnerEnforced
```

And in Terraform:

```hcl
resource "aws_s3_bucket" "example" {
  bucket = "example"
}

resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.example.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
```

## Conclusion

Migrating S3 Bucket ACLs to Bucket Policies is a crucial step in modernising your AWS environment, particularly in light of AWS's recent changes to the default Object Ownership settings. By transitioning from ACLs to Bucket Policies, you gain more control over and simplify access management, and align to AWS best practices.

Throughout this post, I've looked at key differences between ACLs and Bucket Policies, and discussed how to interpret and rewrite ACL permissions, and provided examples using CloudFormation and Terraform. While ACLs were once the primary method for managing access to S3 resources, they now serve a more limited role, particularly in legacy systems or specific use cases requiring object-level permissions.

## References

- https://docs.aws.amazon.com/AmazonS3/latest/userguide/acl-overview.html
- https://docs.aws.amazon.com/AmazonS3/latest/userguide/about-object-ownership.html
- https://docs.aws.amazon.com/accounts/latest/reference/manage-acct-identifiers.html
- https://aws.amazon.com/blogs/aws/heads-up-amazon-s3-security-changes-are-coming-in-april-of-2023/
