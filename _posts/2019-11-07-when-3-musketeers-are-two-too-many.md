---
layout: post
title: "When 3 Musketeers are two too many"
date: 2019-11-07
author: Alex Harvey
tags: terraform 3musketeers
---

A discussion of when to use the 3 Musketeers and related patterns.

## Introduction

The first time I encountered an early incarnation of the [3 Musketeers](https://3musketeers.io) - I don't mean the 2011 film or classic novel but the Make, Docker Compose and Docker pattern of the same name - was in early 2016. A young colleague had joined the team after fighting off much complexity at the DevOps frontier. He arrived fully armed with a battle-tested solution to a problem that would be gradually explained to us as developers having different versions of tools.

The solution, of course, involved Docker containers. I mean lots of Docker containers. So many Docker containers, in fact, that I did wonder who would maintain them all. We had Docker containers for Packer, and Docker containers for Python, and Docker containers for you name it, and thankfully these Docker containers were versioned. The Docker container for Python 2.7.6 might be version python:1.0.0 and the Docker container for Python 2.7.13 might be python:1.0.1. You get the idea.

The second time I encountered the 3 Musketeers was when a remote colleague told me that Terraform - you know, that Golang application - needed to be inside a Docker container. How else could we ensure that all of us had the right version of Terraform installed? To which I countered, Terraform is already a fat binary. That is, after all, the point of writing applications in Golang. If we wrap Terraform in a Docker container, have we not simply made an even fatter binary. How can we ensure that we all have the right version of this Docker container installed?

![Fat binaries]({{ "/assets/fat-binaries.jpg" | absolute_url }})

Here I wish to consider when 3 Musketeers does and does not make sense. Firstly, I look at the pattern itself - what are the 3 Musketeers and what problem do they really solve. Secondly, I want to think about who actually has the problem that they solve. And then I ask the hard question: What are its actual advantages and disadvantages?

## 3 Musketeers

### What is the problem

The 3 Musketeers [website](https://3musketeers.io/) offers three reasons to use this pattern:

- Consistency "Run the same commands no matter where you are"
- Control "Take control of languages, versions, and tools you need, and version source control your pipelines with your preferred VCS like GitHub and GitLab"
- Confidence "Test your code and pipelines locally before your CI/CD tool runs it. Feel confident that if it works locally, it will work in your CI/CD server"

Alright but let's be honest: these three reasons are actually all the same reason: This pattern is about _consistency_. It is about having the same toolset on your Mac OS X laptop as you have inside your CI/CD pipeline and as your colleague has who, for whatever weird reasons, is using Windows!

Consistency is the problem it is solving and the only problem it is solving. And from consistency, of course, flow all sorts of other benefits. Be consistent.

### Hello world

Here is the same hello world example from their docs:

```yaml
# docker-compose.yml
version: 3
services:
  alpine:
    image: alpine
```

```make
# Makefile

# echo calls Compose to run the command "echo 'Hello, World!'" in a Docker container
echo:
  docker-compose run --rm alpine echo 'Hello, World!'
```

```text
# echo 'Hello, World!' with the following command
$ make echo
```

### 1st Musketeer - Make

I love Make. Always use Makefiles. Wrap your automation tasks in them. Run your tests from them. Compile your code in them. Also, you can call Docker Compose to launch Docker containers from them. This is the 1st Musketeer.

### 2nd Musketeer - Docker

Docker is also an excellent tool that solves many problems. In the 3 Musketeers, Docker containers are used to contain your tools. You might have a Python Docker container, or an AWS CLI Docker container, or a all-in-one container, or a vim plugins container, and another containing your Ruby environment and so on. How you divide up your tools between containers is up to you.

### 3rd Musketeer - Compose

Now while you may have all your tools in a single container, the chances are you will divide them up in a way that minimises the maintenance of the Docker images. That being so, you will need a way to launch and orchestrate those images conveniently. Docker Compose solves this problem, because no one would use Kubernetes just for this. (Or would they?)

## Who has the problem

It may be apparent that I am a bit skeptical of the 3 Musketeers (and similar patterns) and sense a bit of hype around Dockerising everything and worry that it is being over-used. This is probably because I come from the Puppet community, where we always had a lot of tools, some of them quite complex, and we never needed this pattern. In the various open source projects I maintain and contribute to, I definitely have no need for my toolsets to align to the preferences of others in the community. Freedom!

Some, no doubt, really do have this problem, however. It appears to me that you would have the problem that 3 Musketeers solves if the following conditions are all satisfied:

- The applications or infrastructure that you support or maintain have a rich and complex ecosystem of tools.
- The tools in this ecosystem must be aligned to some sort of version matrix in order to function.
- The tools in this ecosystem frequently change.

So if you are a Terraform user, and you need Terraform and not much else - you probably don't need the 3 Musketeers. If you are building Kubernetes clusters then perhaps you _do_ need this.

## Discussion

### Advantages

Assuming you do have the problem that warrants set up of the 3 Musketeers, then the primary advantage of this pattern is consistency, as I mentioned above. It might also be consistent in a way that other DevOps engineers in the community will be familiar with. Being able to develop in the same environment as your CI/CD pipeline is advantageous. And so on.

It could be argued that having all of this automated in a Makefile provides a second advantage, of automation and convenience. That is not really true. There is nothing new or unique to this pattern of automating build tasks in a Makefile. So this can't really be counted.

### Disadvantages

The disadvantages are the ones that need to be thought about more carefully.

#### Maintaining Docker images

The need to maintain Docker images creates a maintenance burden that otherwise would not exist. Your Docker image will have its own project, a Dockerfile, and so on. Maybe its own tests. Here is some code sprawl.

#### Docker images become black boxes

To the consumer of the Docker images, the images become black boxes that contain goodies that are hidden from the user. A Docker image called "utils" does not communicate well that it contains a range of tools used for development or what those tools actually are.

#### Problem of tool alignment reinvented as a new problem of image alignment

The next problem is that the pattern really does not guarantee that developers are really all using the same tools after all, as I alluded to above. Since the Docker images are versioned, it is quite possible for users of the pattern to end up unknowingly on different versions of the Docker images. This is especially true if your tools are divided into many Docker containers.

#### Loss of freedom

Sometimes tool versions do not actually need to be locked down. Some of your developers might like to use the unreleased development branch of their favourite tools and it could be totally fine if they do this.

#### Slower

Although Docker containers are often fast to start, they are still slower than simply running tools locally. There is also time spent waiting for Docker to pull images from the Docker Hub.

## Conclusion

I would advise caution when adopting this pattern, and to look at the problem - as always - holistically, and be certain that use of the 3 Musketeers pattern simplifies overall complexity and does not in fact add to it. But certainly it has some great applications and it is useful to understand its ins and outs. Send me an email if you disagree!

## See also

For other views:

- 3 Musketeers [home page](https://3musketeers.io).
- Frederic Lemay (pattern's author), Feb 2, 2018: [The 3 Musketeers: How Make, Docker and Compose enable us to release many times a day](https://amaysim.engineering/the-3-musketeers-how-make-docker-and-compose-enable-us-to-release-many-times-a-day-e92ca816ef17).
