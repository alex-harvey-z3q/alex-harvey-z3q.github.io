---
layout: post
title: "Unit testing a Python Boto3 Lambda function using Placebo"
date: 2019-01-26
author: Alex Harvey
tags: python boto3 placebo
comments: true
---

This posts documents a method for adding automated tests using the Python Placebo library to AWS Python Boto3 scripts. The method can be used for any Python Boto3 scripts, including Python Lambda functions that use the Boto3 library.

I like the Python Placebo library quite a lot. In fact, I liked it so much so that I wrote my own Bash version of it for use with the AWS CLI ([here](https://alexharv074.github.io/2018/09/18/using-bash-placebo-to-auto-generate-mocks-in-unit-tests.html)).

The Placebo library is by Mitch Garnaat who co-wrote Boto, Botocore and the AWS CLI.

* Table of contents
{:toc}

## Code example

The code example is a Python Boto3 script for encrypting an AMI that has been shared from another AWS account. The guts of the script is the method shown here:

```python
#!/usr/bin/env python

import boto3

class AMIEncrypter():

  def __init__(self):
    self.client = boto3.client('ec2')

  def encrypt(self,
      source_image_id, image_name, kms_key_id, iam_instance_profile,
      subnet_id, os_type):

    try:
      if self.this_account() == self.account_of(source_image_id):
        encrypted_image_id = self.copy_image(source_image_id, image_name, kms_key_id)

      else:
        instance_id = self.run_instance(
          source_image_id, iam_instance_profile, subnet_id, os_type)
        self.stop_instance(instance_id)
        unencrypted_image_id = self.create_image(
          instance_id, image_name + "-unencrypted")
        self.terminate_instance(instance_id)
        encrypted_image_id = self.copy_image(source_image_id, image_name, kms_key_id)
        self.deregister_image(unencrypted_image_id)

    except KeyboardInterrupt:
      sys.exit("User aborted script!")

    print "Encrypted AMI ID: %s" % encrypted_image_id
    return encrypted_image_id

  # Other methods not shown.
```

The code is also online [here](https://github.com/alexharv074/encrypt_ami) at GitHub.

## Setting up Placebo

The first thing to do is add the Placebo library in a `requirements.txt` and create a Virtualenv. In my example:

```text
▶ cat requirements.txt
placebo
boto3
ipdb
▶ virtualenv ./virtualenv
New python executable in /Users/alexharvey/git/encrypt_ami/virtualenv/bin/python2.7
Also creating executable in /Users/alexharvey/git/encrypt_ami/virtualenv/bin/python
Installing setuptools, pip, wheel...
done.
▶ . virtualenv/bin/activate
▶ pip install -r requirements.txt
```

Next I add a hook in the code that allows me to activate the Placebo library whenever I need it. It is shown in this patch:

```diff
diff --git a/encrypt_ami.py b/encrypt_ami.py
index c771f34..f7f8ac3 100644
--- a/encrypt_ami.py
+++ b/encrypt_ami.py
@@ -101,6 +101,14 @@ class UserData():
 class AMIEncrypter():

   def __init__(self):
+
+    if os.environ.get('BOTO_RECORD'):
+      import placebo
+      boto3.setup_default_session()
+      session = boto3.DEFAULT_SESSION
+      pill = placebo.attach(session, data_path='pyunit/fixtures')
+      pill.record()
+
     self.client = boto3.client('ec2')

   def encrypt(self,
```

This is convenient. It allows me to now run the script that is to be tested in a live AWS account and save all of the JSON data exchanged with the AWS API in a directory.

(That was figured out with some help from Stack Overflow [here](https://stackoverflow.com/q/45530840/3787051) and it's now documented in the Placebo README.)

To do that:

```text
▶ export BOTO_RECORD=true
▶ python encrypt_ami.py --source-image-id ami-52293031 \
◀   --name my_test_ami --kms-key-id alias/mykey \
◀   --iam-instance-profile MyInstanceProfile \
◀   --subnet-id subnet-43920e34 --os-type linux
Launching a source AWS instance...
Waiting for instance (i-0481ed4a67454b5e7) to become running...
state: pending
Waiting for instance (i-0481ed4a67454b5e7) to become ok...
Stopping the source AWS instance...
Waiting for instance (i-0481ed4a67454b5e7) to become stopped...
state: stopping
Creating the AMI: my_test_ami-unencrypted
Waiting for AMI to become available...
state: pending
Terminating the source AWS instance...
Waiting for instance (i-0481ed4a67454b5e7) to become terminated...
state: shutting-down
Creating the AMI: my_test_ami
Waiting for AMI to become available...
state: pending
Deregistering the AMI: ami-23061e40
Encrypted AMI ID: ami-2939214a
```

The script took about 15 minutes to run. It launched an AWS EC2 instance, then stopped it, then created an encrypted AMI by copying the stopped EC2 instance, then cleaned up.

But because I attached the Placebo library before I ran it, the JSON responses all have been saved in pyunit/fixtures:

```text
▶ find pyunit/fixtures -type f
pyunit/fixtures/ec2.CreateImage_1.json
pyunit/fixtures/ec2.DescribeInstances_3.json
pyunit/fixtures/ec2.RunInstances_1.json
pyunit/fixtures/ec2.DescribeInstances_2.json
pyunit/fixtures/ec2.CopyImage_1.json
pyunit/fixtures/ec2.DescribeInstances_5.json
pyunit/fixtures/ec2.DescribeInstances_4.json
pyunit/fixtures/ec2.DescribeImages_1.json
pyunit/fixtures/ec2.StopInstances_1.json
pyunit/fixtures/ec2.DescribeImages_2.json
pyunit/fixtures/ec2.DeregisterImage_1.json
pyunit/fixtures/ec2.DescribeInstanceStatus_1.json
pyunit/fixtures/ec2.DescribeInstances_6.json
pyunit/fixtures/ec2.DescribeImages_3.json
pyunit/fixtures/ec2.DescribeInstances_1.json
pyunit/fixtures/ec2.TerminateInstances_1.json
pyunit/fixtures/ec2.DescribeImages_4.json
pyunit/fixtures/sts.GetCallerIdentity_1.json
pyunit/fixtures/ec2.DescribeImages_5.json
```

Let's have a look at one, for instance `ec2.CreateImage_1.json`:

```json
{
  "status_code": 200,
  "data": {
    "ResponseMetadata": {
      "RetryAttempts": 0,
      "HTTPStatusCode": 200,
      "RequestId": "76865d7e-b731-485e-9681-a4b82c4d51f9",
      "HTTPHeaders": {
        "transfer-encoding": "chunked",
        "vary": "Accept-Encoding",
        "server": "AmazonEC2",
        "content-type": "text/xml;charset=UTF-8",
        "date": "Sun, 13 Aug 2017 06:16:03 GMT"
      }
    },
    "ImageId": "ami-23061e40"
  }
}
```

The naming convention of those files can be seen in there too. For a call to [EC2.Client.create_image](https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/ec2.html#EC2.Client.create_image), a file is created `ec2.CreateImage_n.json` where n is an increment starting at 1. Thus if I were to make 3 calls to EC2.Client.create_image, I would get 3 files, `ec2.CreateImage_1.json`, `ec2.CreateImage_2.json` and `ec2.CreateImage_3.json`.

## Writing the tests

### Test header

Capturing the responses is of course the easiest part. Writing the tests requires a bit more knowledge.

Firstly, I need to import a few libraries to make this all work:

```python
#!/usr/bin/env python

import unittest
import placebo

import sys
sys.path.insert(0, '.')
from encrypt_ami import AMIEncrypter

import boto3
import os
import time
```

I import unittest as my unit testing framework. You could use nose, pytest or whatever you like, whereas I am most familiar with unittest. I also import the Placebo library itself.

Getting access to the script under test can itself be a challenge if you haven't structured your Python project as a package or module, which is often the case. How do I just read in a file from a location and then read its functions or classes? To do that:

```python
import sys
sys.path.insert(0, '.')
from encrypt_ami import AMIEncrypter
```

Note that the assumption there is that a file `encrypt_ami.py` exists in the directory `'.'`. From that file minus the `.py` extension, we import a class `AMIEncrypter`.

Note also that the `encrypt_ami.py` must contain some code to prevent it actually executing during the import at the bottom of the script. This is called a "guard". You'll often see code like this for that reason:

```python
if __name__ == "__main__":
  main()
```

That says call the `main()` function if and only if the special variable `__name__` is equals to `__main__`. That will be true only when the script is executed directly.

### Setup Placebo

Next I need a snippet of code to place the Placebo library in "playback" mode:

```python
# Attach the Placebo library. Calls to Boto3 are intercepted and replaced
# with the canned responses found in data_path.

boto3.setup_default_session()
session = boto3.DEFAULT_SESSION
pill = placebo.attach(session, data_path='pyunit/fixtures')
pill.playback()
```

### The test

The actual test looks like this:

```python
class TestEncryptAMI(unittest.TestCase):

  def setUp(self):

    # Silence STDOUT everywhere.
    sys.stdout = open(os.devnull, 'w')

    # Stub out time.sleep everywhere.
    def dummy_sleep(seconds):
      pass
    time.sleep = dummy_sleep

    os.environ['AWS_DEFAULT_REGION'] = 'ap-southeast-2'

  def tearDown(self):
    pass

  def testEncryptAMIDifferentAccount(self):
    ami_encrypter = AMIEncrypter()
    encrypted_ami = ami_encrypter.encrypt(
      'ami-52293031', 'my_test_ami', 'alias/mykey', 'MyInstanceProfile',
      'subnet-43920e34', 'linux')
    self.assertEquals(encrypted_ami, 'ami-2939214a')

def main():
  unittest.main()

if __name__ == "__main__":
  main()
```

Now a lot of that is just unittest boilerplate.

Note firstly that I have silenced STDOUT everywhere. If I didn't do this, I'll see the STDOUT from my script printed to the screen when the tests run, and I don't want that.

Similarly, I have stubbed out `time.sleep`. I believe that I got that from Stack Overflow [here](https://stackoverflow.com/a/25689487/3787051).

The script also expects to find the default region in the environment variable `AWS_DEFAULT_REGION` so that's what the `os.environ` line does.

Now for the test itself:

```python
  def testEncryptAMIDifferentAccount(self):
    ami_encrypter = AMIEncrypter()
    encrypted_ami = ami_encrypter.encrypt('ami-52293031', 'my_test_ami', 'alias/mykey', 'MyInstanceProfile', 'subnet-43920e34', 'linux')
    self.assertEquals(encrypted_ami, 'ami-2939214a')
```

Here I say if I call the `encrypt` method on the `AMIEncrypter` with those arguments similar to what I passed in on the script's CLI, the script returns an expected AMI ID. And with understanding of the code, I know that this test exercises all of the code in one of the main logic pathways through the code.

### Running the test

To run it:

```text
▶ python pyunit/encrypt_ami.py
.
----------------------------------------------------------------------
Ran 1 test in 0.460s

OK
```

## Discussion

This has shown the basics of what I do when I test Python Boto3 scripts using Placebo. Is it a good way to test? A bad way?

### What I like

Armed with the information I have documented here, Python Placebo is easy to set up. You can have this up and running for any Python script in 20 minutes. Then you can run your script in a real AWS account, record all the responses, ensuring that you test all the paths through the code you care about, then take it away, go nuts, refactor it, and you have unit tests to protect you from bugs.

And the best bit of course is there's no need to manually create Mocks. I didn't need the Python Mock library. No MagicMock. No [moto](https://github.com/spulec/moto). It's just run the script and you have all your mocks saved for you. That's a big win!

### What I don't like

It must be noted at the outset that this library can lead to secrets leaking into test files! By default, details of the account you run the script in during the Placebo record run will be saved in the response files. This might include details like account IDs, VPC IDs and so forth. These are perhaps not secret in the same way passwords are but all the same they are details you do not want in a public Git repo. Generally, I redact the JSON files using Perl one-liners.

The ease of set up also needs to be weighed against the readability and sometimes maintainability of the tests. It's nice not having to know how to create mocks. But without explicit mocks, it's hard to understand from reading the tests what's going on under the hood. That leads to one key benefit of unit testing being lost, namely the layer of readable code as documentation that tells people how the code actually works.

The naming convention of the response files is also not ideal. It would be great if it were possible to group response files on a per-test basis, rather than just in order by increment. The order by increment approach leads to a very confusing situation where a maintainer might simply change the order of the tests in the code, and that would lead to all the tests breaking mysteriously!

I raised an issue at the Placebo project [here](https://github.com/garnaat/placebo/issues/66). Feel free to upvote that issue if you also agree that this could be improved.

Another concern is whether or not Placebo is a good fit for Test-Driven Development. I am personally not overly zealous about always writing tests first but the test-first approach sometimes does have merit. In that situation, it wouldn't make sense to use Placebo I don't think.

## Conclusion

This post has quickly documented how to set up Placebo to unit test your Python Boto3 scripts. These could be AWS Lambda functions or any other Python Boto3 script. And I've briefly added a few words about what I love about this approach, and what's imperfect about it. Let me know if you have any thoughts of your own.

## Further reading

- Ben Kehoe, [Unit and Integration Testing for AWS Lambda](https://serverless.zone/unit-and-integration-testing-for-lambda-fc9510963003).
- Alex Harvey, [Using Placebo for Bash to auto-generate mocks in unit tests](https://alexharv074.github.io/2018/09/18/using-bash-placebo-to-auto-generate-mocks-in-unit-tests.html).
