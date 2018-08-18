---
layout: post
title: "Creating a ZIP file for an AWS Lambda Python function"
date: 2018-08-18
author: Alex Harvey
tags: lambda
---

I found the documentation a bit confusing for creating an AWS Lambda ZIP file for a Python function plus dependencies, so this post will document the procedure.

- TOC
{:toc}

## Note about virtualenv and large zip files

I found [this](https://codeburst.io/aws-lambda-functions-made-easy-1fae0feeab27) post at codeburst.io by Alexandra Johnson quite useful, although in the end it created a zip file that was very large due to inclusion of the whole virtualenv, and actually involved more steps than required. That is no doubt because the Amazon documentation [also](https://docs.aws.amazon.com/lambda/latest/dg/lambda-python-how-to-create-deployment-package.html) talks about zipping up a virtualenv.

Meanwhile, the AWS Lambda limits are documented [here](https://docs.aws.amazon.com/lambda/latest/dg/limits.html#limits-list). On the allowed size of the zip file:

> If the size of your Lambda function's zipped deployment packages exceeds 3MB, you will not be able to use the inline code editing feature in the Lambda console. You can still use the console to invoke your Lambda function.

Including the whole virtualenv can easily lead to the 3MB size being exceeded, so this procedure avoids using the virtualenv altogether.

## Create a zip file

### About this example

In this example I am creating a simple zip file with a single Python pip package, xlrd.

### Create requirements.txt

So, I created a simple `requirements.txt` at the root of my project:

~~~ text
xlrd
~~~

### Note about ZIP file folder structure

The final folder structure is expected to look like this:

~~~ text
$ tree -L 1 . 
.
├── lambda_function.py
├── xlrd
└── xlrd-1.1.0.dist-info
~~~

### Workaround for Homebrew's Python on Mac OS X

At the time of writing, Homebrew's Python on Mac OS X is broken. Based on [this](https://stackoverflow.com/a/44728772/3787051) Stack Overflow post, I had to create a file `setup.cfg` at the root of my project:

~~~ ini
[install]
prefix=
~~~

Without this, a pip error message is seen:

> must supply either home or prefix/exec-prefix — not both

### Install dependencies

To install:

~~~ text
$ pip install -r requirements.txt -t .
~~~

Now my project root looks like this:

~~~ text
$ tree -L 1 .
.
├── bin
├── requirements.txt
├── setup.cfg
├── xlrd
└── xlrd-1.1.0.dist-info
~~~

### Create the zip file

To create the zip file:

~~~ text
$ zip -r9 ../lambda.zip * -x "bin/*" requirements.txt setup.cfg
~~~

Note that it is not obvious how to exclude directories from a zip file. See [here](https://askubuntu.com/questions/28476/how-do-i-zip-up-a-folder-but-exclude-the-git-subfolder) for more on this.

## Update a zip file

One more useful thing to know is how to update the lambda function itself in the zip file without having to pip install and update everything else. The command for that is:

~~~ text
$ zip -g ../lambda.zip lambda_function.py
~~~

