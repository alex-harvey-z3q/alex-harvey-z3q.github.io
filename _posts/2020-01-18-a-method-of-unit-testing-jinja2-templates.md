---
layout: post
title: "A method of unit testing Jinja2 templates"
date: 2020-01-18
author: Alex Harvey
tags: jinja2 python
---

- ToC
{:toc}

## Introduction

The use of Jinja2 templating in infrastructure code has become popular, partly due to the popularity of Python in the DevOps community, and partly due to the success of Ansible, Salt and similar DevOps tools.

Jinja2 itself is part of the Flask web framework and was originally used for code-generating HTML front ends in web pages. In the DevOps community, it is mostly used for code-generating configuration files, although, in the Ansible CloudFormation module and in Sceptre, as examples, it is sometimes used for code-generating more code such as CloudFormation code and Bash shell scripts and so on.

Code within code! It can often start off simple and quickly escalate into a labyrinthine mess! To be clear, I don't like the Jinja2 code-generation pattern and I try to avoid it, although it is widely in use, so techniques for making it maintainable are urgently needed.

These are the problems I am trying to solve here today:

- How can I quickly render a Jinja2 template so as to understand how the Jinja2 logic behaves for a range of input data sets.
- How can I prove that for each sample input data set, valid code is produced at the end.
- [Advanced] How can I write unit test cases for Jinja2 logic?

## Code example

My example code is a [Sceptre](https://github.com/Sceptre/sceptre)/CloudFormation template as follows:

```jinja
{%raw%}---
AWSTemplateFormatVersion: "2010-09-09"
Description: "Security Groups"

Resources:
  {%- for sg in sceptre_user_data %}
  {{ sg.Name }}:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: {{ sg.GroupDescription }}
      SecurityGroupIngress:
        {%- for ing in sg.SecurityGroupIngress %}
        - IpProtocol: {{ ing.IpProtocol }}
          FromPort: {{ ing.FromPort }}
          ToPort: {{ ing.ToPort }}
          CidrIp: {{ ing.CidrIp }}
        {%- endfor %}
  {%- endfor %}{%endraw%}
```

As can be seen, it is a template for code-generating AWS Security Groups with a list of ingress rules. Note that it involves a nested for loop - something that in Jinja2 can quickly become unreadable.

## Code on GitHub

This demo is available on GitHub [here](https://github.com/alexharv074/jinja2-unit-testing).

## Test cases

I have created a YAML file with test data sets as test cases. My YAML file is as follows:

```yaml
---
'./template.yml.j2':
  - sceptre_user_data:
      -
        Name: WebSG
        GroupDescription: Web SG Inbound
        SecurityGroupIngress:
          - IpProtocol: tcp
            FromPort: 80
            ToPort: 80
            CidrIp: 0.0.0.0/0
          - IpProtocol: tcp
            FromPort: 443
            ToPort: 443
            CidrIp: 0.0.0.0/0
  - sceptre_user_data:
      -
        Name: App1SG
        GroupDescription: First app inbound
        SecurityGroupIngress:
          - IpProtocol: tcp
            FromPort: 80
            ToPort: 80
            CidrIp: 0.0.0.0/0
      -
        Name: App2SG
        GroupDescription: Second app inbound
        SecurityGroupIngress:
          - IpProtocol: tcp
            FromPort: 443
            ToPort: 443
            CidrIp: 0.0.0.0/0
```

My thinking here is that I will have a YAML structure that is a dictionary of full paths to Jinja2 files that contain a list of test data sets to be fed into that Jinja2 template. Having the test data sets in this file will also make it easier for the users of the template to instantiate their stacks.

## Python dependencies

I need to create a Virtualenv with the Python dependencies as follows. Requirements file:

```text
▶ cat requirements.txt
yamllint
jinja2
```

A venv.sh script:

```text
▶ cat venv.sh
#!/usr/bin/env bash
virtualenv venv
. venv/bin/activate
pip install -r requirements.txt
```

And I source that:

```text
▶ source venv.sh
```

## Test code

### unittest boilerplate

I begin my tests with some Python unittest boilerplate as follows:

```python
#!/usr/bin/env python3

import unittest


class TestJ2(unittest.TestCase):

    def setUp(self):
        pass

    def test_j2(self):
        pass


def main():
    unittest.main()


if __name__ == "__main__":
    main()
```

### A directory for saving compiled templates

I want a directory to save the compiled YAML templates in. Saving them after they are compiled allows me to use these templates to then do manual testing.

```python
import os

COMPILED = '.compiled-j2'


class TestJ2(unittest.TestCase):

    def setUp(self):
        if not os.path.exists(COMPILED):
            os.makedirs(COMPILED)
```

### Read in each data set

To read in each data set I extend the code to this:

```python
import os, yaml

# ...

class TestJ2(unittest.TestCase):

    with open('pyunit/fixtures/test_j2.yml', 'r') as stream:
        try:
            test_data = yaml.safe_load(stream)
        except yaml.YAMLError as exc:
            print(exc)

    # ...

    def test_j2(self):
        for full_path, contexts in self.test_data.items():
            for count, context in enumerate(contexts):
                pass
```

Notice here that I have created a class variable `test_data`. My thinking is I would like to be potentially able to share the test data sets across one or more unittest "tests".

### Render J2

This code snippet renders the Jinja2 template:

```python
import jinja2

COMPILED = '.compiled-j2'


class TestJ2(unittest.TestCase):

    # ...

    def test_j2(self):
        for full_path, contexts in self.test_data.items():
            for count, context in enumerate(contexts):

                # Render the J2.
                rendered = jinja2.Environment(
                    loader=jinja2.FileSystemLoader(path)
                ).get_template(file_name).render(context)

                compiled = '{}/{}.{}'.format(
                        COMPILED, file_name.replace('.j2',''), count)

                with open(compiled, 'w') as text_file:
                    text_file.write(rendered)
```

Notice that the Jinja2 context has come straight from the YAML fixture file. Note also that I write out the compiled Jinja2 template in the `.compiled-j2` directory, and the file names are distinguished by the value of `count` for each data set for that template.

The compiled J2 is obviously a useful thing to have indeed! This allows me to do manual testing given an input example data set. I don't need to have Sceptre all working to test the CloudFormation template I am writing. Winning! Obviously, the same could apply if I were using the Ansible CloudFormation module too.

### Check that the rendered J2 is valid YAML

Next I want to actually test something. Here I test that the rendered template is valid YAML:

```python
class TestJ2(unittest.TestCase):

    # ...

    def test_j2(self):
        for full_path, contexts in self.test_data.items():
            for count, context in enumerate(contexts):

                # ...

                try:
                    yaml.load(rendered, Loader=yaml.BaseLoader)
                except:
                    self.fail("Compiled template is not valid YAML")
```

This snippet tests - calling the UnitTest `fail` method if there's a problem - that my generated CloudFormation template is valid YAML. The assumption is that `yaml.load` raises an exception when the template is invalid YAML.

### Check that Yamllint passes on the rendered template

This may be overkill for some but running the rendered template through Yamllint can detect some issues - including the dreaded duplicate dictionary key problem - not detected by simply checking for valid YAML:

```python
from yamllint.config import YamlLintConfig
from yamllint import linter


class TestJ2(unittest.TestCase):

    conf = YamlLintConfig('{\
            extends: relaxed,\
            rules: {\
                key-duplicates: enable,\
                new-line-at-end-of-file: disable,\
            }}')

    # ...

    def test_j2(self):
        for full_path, contexts in self.test_data.items():
            for count, context in enumerate(contexts):

                # ...

                gen = linter.run(rendered, self.conf)
                self.assertFalse(list(gen),
                      "Yamllint issues in compiled template")
```

Notice that again I have declared the Yamllint config as a class variable and this time I call `self.assertFalse` - another UnitTest method - if Yamllint found any errors.

### Check that the rendered J2 cloudformation validates

Finally, I want to check if the rendered template passes aws cloudformation validate-template:

```python
DEVNULL = open(os.devnull, 'w')


class TestJ2(unittest.TestCase):

    # ...

    def test_j2(self):
        for full_path, contexts in self.test_data.items():
            for count, context in enumerate(contexts):

                # ...

                try:
                    print("Validating {} ...".format(compiled))
                    command = "aws cloudformation validate-template \
                            --template-body file://{}".format(compiled)
                    subprocess.check_call(command.split(), stdout=DEVNULL)
                except:
                    self.fail("Validate template failed")
```

Again pretty self-explanatory. I shell out using `subprocess` to call the AWS CLI to cloudformation validate the generated code.

### All together

The final version of the test suite is as follows:

```python
#!/usr/bin/env python3

import unittest
import jinja2
import os, yaml, subprocess

from yamllint.config import YamlLintConfig
from yamllint import linter

COMPILED = '.compiled-j2'
DEVNULL = open(os.devnull, 'w')


class TestJ2(unittest.TestCase):

    with open('pyunit/fixtures/test_j2.yml', 'r') as stream:
        try:
            test_data = yaml.safe_load(stream)
        except yaml.YAMLError as exc:
            print(exc)

    conf = YamlLintConfig('{\
            extends: relaxed,\
            rules: {\
                key-duplicates: enable,\
                new-line-at-end-of-file: disable,\
            }}')

    def setUp(self):
        if not os.path.exists(COMPILED):
            os.makedirs(COMPILED)

    def test_j2(self):
        """
        Using test data sets found in pyunit/fixtures/test_j2.yml,
        ensure that all Jinja2 templates compile and that the generated
        CloudFormation templates pass Yamllint tests and validate.
        """

        for full_path, contexts in self.test_data.items():

            for count, context in enumerate(contexts):

                path = os.path.dirname(full_path)
                file_name = os.path.basename(full_path)

                rendered = jinja2.Environment(
                    loader=jinja2.FileSystemLoader(path)
                ).get_template(file_name).render(context)

                compiled = '{}/{}.{}'.format(
                        COMPILED, file_name.replace('.j2',''), count)

                with open(compiled, 'w') as text_file:
                    text_file.write(rendered)

                try:
                    yaml.load(rendered, Loader=yaml.BaseLoader)
                except:
                    self.fail("Compiled template is not valid YAML")

                gen = linter.run(rendered, self.conf)
                self.assertFalse(list(gen),
                        "Yamllint issues in compiled template")

                try:
                    print("Validating {} ...".format(compiled))
                    command = "aws cloudformation validate-template \
                            --template-body file://{}".format(compiled)
                    subprocess.check_call(command.split(), stdout=DEVNULL)
                except:
                    self.fail("Validate template failed")


def main():
    unittest.main()


if __name__ == "__main__":
    main()
```

## Makefile

In order to run the tests I have a simple Makefile:

```make
.PHONY: test

test:
	python3 -m unittest discover -s pyunit
```

## Run the tests

Ok. I run the tests:

```text
▶ make
python3 -m unittest discover -s pyunit
Validating .compiled-j2/template.yml.0 ...
Validating .compiled-j2/template.yml.1 ...
.
----------------------------------------------------------------------
Ran 1 test in 2.015s

OK
```

## The generated CloudFormation

Ok. Let's find out what my generated templates look like. Are they what I expected? Formatted correctly? And so on:

```yaml
# .compiled-j2/template.yml.0
---
AWSTemplateFormatVersion: "2010-09-09"
Description: "Security Groups"

Resources:
  WebSG:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Web SG Inbound
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          CidrIp: 0.0.0.0/0
        - IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          CidrIp: 0.0.0.0/0
```

Looks good to me! I try to actually deploy it:

```text
▶ aws cloudformation deploy --stack-name test-stack --template-file .compiled-j2/template.yml.0

Waiting for changeset to be created..
Waiting for stack create/update to complete
Successfully created/updated stack - test-stack
```

Great! What about the other one:

```yaml
# .compiled-j2/template.yml.1
---
AWSTemplateFormatVersion: "2010-09-09"
Description: "Security Groups"

Resources:
  App1SG:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: First app inbound
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          CidrIp: 0.0.0.0/0
  App2SG:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Second app inbound
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          CidrIp: 0.0.0.0/0
```

That looks right too.

## Testing the tests

So, what else can these tests actually detect? How useful are they? Here are a few demonstrations:

### YAML indentation error

In this demonstration I add a deliberate indentation error:

```diff
diff --git a/template.yml.j2 b/template.yml.j2
index f02492a..30d6492 100644
--- a/template.yml.j2
+++ b/template.yml.j2
@@ -5,7 +5,7 @@ Description: "Security Groups"
 Resources:
   {%raw%}{%- for sg in sceptre_user_data %}
   {{ sg.Name }}:{%endraw%}
-    Type: AWS::EC2::SecurityGroup
+     Type: AWS::EC2::SecurityGroup
     Properties:
       GroupDescription: {%raw%}{{ sg.GroupDescription }}{%endraw%}
       SecurityGroupIngress:
```

Then:

```text
▶ make
python3 -m unittest discover -s pyunit
F
======================================================================
FAIL: test_j2 (test_j2.TestJ2)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/Users/alexharvey/git/home/j2_tests/pyunit/test_j2.py", line 58, in test_j2
    yaml.load(rendered, Loader=yaml.BaseLoader)
yaml.parser.ParserError: while parsing a block mapping
  in "<unicode string>", line 6, column 3:
      WebSG:
      ^
expected <block end>, but found '<block mapping start>'
  in "<unicode string>", line 8, column 5:
        Properties:
        ^

During handling of the above exception, another exception occurred:

Traceback (most recent call last):
  File "/Users/alexharvey/git/home/j2_tests/pyunit/test_j2.py", line 60, in test_j2
    self.fail("Compiled template is not valid YAML")
AssertionError: Compiled template is not valid YAML

----------------------------------------------------------------------
Ran 1 test in 0.007s

FAILED (failures=1)
make: *** [test] Error 1
```

### YAML duplicate key

Another easily-made and hard-to-notice YAML error is the dreaded key duplicate. I deliberately add a duplicate key:

```diff
diff --git a/template.yml.j2 b/template.yml.j2
index f02492a..63fdcc8 100644
--- a/template.yml.j2
+++ b/template.yml.j2
@@ -15,5 +15,6 @@ Resources:
           ToPort: {%raw%}{{ ing.ToPort }}
           CidrIp: {{ ing.CidrIp }}
         {%- endfor %}{%endraw%}
+    Type: AWS::EC2::SecurityGroup

   {%raw%}{%- endfor %}{%endraw%}
```

And then I try that:

```text
▶ make
python3 -m unittest discover -s pyunit
F
======================================================================
FAIL: test_j2 (test_j2.TestJ2)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/Users/alexharvey/git/home/j2_tests/pyunit/test_j2.py", line 64, in test_j2
    "Yamllint issues in compiled template")
AssertionError: [19:5: duplication of key "Type" in mapping (key-duplicates)] is not false : Yamllint issues in compiled template

----------------------------------------------------------------------
Ran 1 test in 0.016s

FAILED (failures=1)
make: *** [test] Error 1
```

All good. So, I feel very confident that my code works now, and I haven't had to perform any expensive end-to-end testing. I can defer all that to one go at the end, where I expect everything is going to work on the first try(!).

## Discussion

I have used this method for a while now and I find it to be adding a lot of value and well worth the effort of setting it all up. I would go as far as to say that I doubt anyone should be running Jinja2 CloudFormation templates in production without a layer of testing like this.

It is easy to also see how this could be extended to, say, test Bash scripts. I could just as easily run generated Bash scripts through `bash -n` - or even write Bash unit tests to run on the generated Bash code. Likewise, I could easily extend these tests for Jinja2 to be real unit tests, by reading the generated YAML into a dictionary and making assertions about its keys and data.

## Conclusion

I have documented a method of unit testing Jinja2 logic in CloudFormation, Ansible and other code. As far as I can tell, not many in the DevOps community are doing anything like this, although, I daresay, they should be doing it. Please send me an email if you have any feedback or suggestions for improvement!

## See also

- Stack Overflow, Feb 7 2017, [How can I unit test the jinja2 template logic?](https://stackoverflow.com/a/42091287/3787051).
