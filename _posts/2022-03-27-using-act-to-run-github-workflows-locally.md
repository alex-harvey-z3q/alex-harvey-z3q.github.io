---
layout: post
title: "Using act to run GitHub Workflows locally"
date: 2022-03-27
author: Alex Harvey
tags: github-actions act
published: false
---

I recently started using GitHub Actions as a CI/CD platform, and quickly found I wanted a way to run my CI builds locally. This post documents my, as yet, unsuccessful attempt to use the open source project [nektos/act](https://github.com/nektos/act). I have given up at this point, since Reusable Workflows are [not supported](https://github.com/nektos/act/issues/826).

- ToC
{:toc}

## What is act

Act is a tool for running your GitHub Actions locally. It gives you fast feedback if you don't like waiting to find out that your build has issues after you already pushed to a branch and possibly raised a PR.

## How does it work?

> When you run act it reads in your GitHub Actions from .github/workflows/ and determines the set of actions that need to be run. It uses the Docker API to either pull or build the necessary images, as defined in your workflow files and finally determines the execution path based on the dependencies that were defined. Once it has the execution path, it then uses the Docker API to run containers for each action based on the images prepared earlier. The environment variables and filesystem are all configured to match what GitHub provides.

## Installation

Initially I installed the latest version (0.2.26 at the time of writing) using `brew install act`. That worked fine until I ran into a Mac OS X bug documented ([Issue 935](https://github.com/nektos/act/issues/935) and found a [workaround](https://github.com/nektos/act/issues/935#issuecomment-999707633) that suggested I would need to downgrade to version 0.2.24. So, to install a specific version I did this:

1. Cloned the source code:
    ```text
    ▶ git clone git@github.com:nektos/act.git                            
    ▶ cd act
    ```
1. Read the source code of the installer! In there I found the `tag` option. So to install I then did:
    ```text
    ▶ bash install.sh v0.2.24
    ```
1. That compiles a Golang binary in `./bin/act`, so then I did:
    ```text
    ▶ mv bin/act /usr/local/bin
    ```
1. Checked it:
    ```text
    ▶ act --version
    act version 0.2.24
    ```

## Locally build the Docker image

Next, I built the Docker image that that my workflow depends on as specified in the workflow in `runs-on: example-base`.

```text
▶ docker build -f images/gha-default-runner.Dockerfile . -t gha-default-runner:latest
```

## Created a GitHub Access Token

In order for my GitHub Actions workflow to be able to close resuable workflows, I then created a GitHub Personal Access Token, according to docs [here](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token).

## Running act

### Viewing workflows

To see workflows available that run in stage `on: pull_request`:

```text
▶ act pull_request -l
ID        Stage  Name
pr-merge  0      pr-merge
pr-lint   0      pr-lint
pr-tests  0      pr-tests
pr-pass   1      pr-pass
```

### Running the workflow

To run it:

```text
▶ act -s GITHUB_TOKEN=xxx -P example-base=example-base:latest pull_request  
```

## Conclusion

This is a nice piece of software, that is possibly useful for people who are not using Reusable Workflows or other features of GitHub Actions that are not currently supported. At the time of writing, however, Reusable Workflows is not supported due to [this](https://github.com/nektos/act/issues/826) open issue. As this is something of a must-have feature, many will find this isn't a solution.
