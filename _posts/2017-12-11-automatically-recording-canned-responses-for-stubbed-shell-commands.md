---
layout: post
title: "Automatically recording canned responses for stubbed shell commands"
date: 2017-12-11
author: Alex Harvey
---

This brief post shows a shell script that can automatically record canned responses from a shell command, for example the aws command line, for later use in shUnit2 tests.

For more information, see my other [post](https://alexharv074.github.io/2017/07/07/unit-testing-a-bash-script-with-shunit2.html) on unit testing bash scripts in shUnit2.

## Method
Replace the command of interest with a shell function following this pattern:

~~~ bash
#!/bin/bash

log_file=/tmp/aws.sh

aws() {
  if [ ! -e $log_file ]
  then
    echo 'aws() {'         >> $log_file
    echo '  case "$*" in'  >> $log_file
  else
    awk '/esac/{exit}{print}' $log_file > x ; mv x $log_file
  fi

  echo '  "'$*'")'       >> $log_file
  echo "    cat <<'EOF'" >> $log_file

  command aws $* | tee -a $log_file

  echo 'EOF'           >> $log_file
  echo '    ;;'        >> $log_file
  echo '  esac'        >> $log_file
  echo '}'             >> $log_file
}

aws ec2 describe-instances --instance-id i-0985e6cf081ec2424 --query 'Reservations[*].Instances[0].PrivateIpAddress' --output text
aws ec2 describe-images --image-id ami-0001e562 --query 'Images[].OwnerId' --output text
aws ec2 describe-images --image-id ami-0001e562 --query 'Images[].CreationDate' --output text
~~~
Now run the script you wish to test, and your stub will be in the log file:

~~~ bash
aws() {
  case "$*" in
  "ec2 describe-instances --instance-id i-0985e6cf081ec2424 --query Reservations[*].Instances[0].PrivateIpAddress --output text")
    cat <<EOF
10.23.13.158
EOF
  ;;
  "ec2 describe-images --image-id ami-0001e562 --query Images[].OwnerId --output text")
    cat <<EOF
EOF
  ;;
  "ec2 describe-images --image-id ami-0001e562 --query Images[].CreationDate --output text")
  cat <<EOF
2017-09-09T06:50:57.000Z
EOF
  ;;
  "ec2 describe-instances --instance-id i-0985e6cf081ec2424 --query Reservations[*].Instances[0].PrivateIpAddress --output text")
    cat <<EOF
10.23.13.158
EOF
    ;;
  "ec2 describe-images --image-id ami-0001e562 --query Images[].OwnerId --output text")
    cat <<EOF
EOF
    ;;
  "ec2 describe-images --image-id ami-0001e562 --query Images[].CreationDate --output text")
    cat <<EOF
2017-09-09T06:50:57.000Z
EOF
    ;;
  esac
}
~~~
