---
layout: post
title: "A Pattern for Multiple GitLab CI Pipelines"
date: 2025-11-19
author: Alex Harvey
tags: gitlab
---
## Introduction

Tools like Jenkins, GitHub Actions, and Azure Pipelines allow you to organise a project with multiple independent pipelines or workflows. In Jenkins, for example, you can define several `Jenkinsfiles` side-by-side to handle nightly builds, integration tests, and release automation separately. GitHub Actions, meanwhile, allows splitting unrelated tasks into separate workflows under `.github/workflows/`. Azure Pipelines supports multiple YAML pipelines that can be triggered independently.

GitLab CI, however, takes a different approach.

In GitLab CI, a project has _exactly one entry point_: the `.gitlab-ci.yml` file at the root of the repository. As a consequence, all pipelines — merge request pipelines, scheduled jobs, operational tasks, ad-hoc maintenance jobs, and anything else — must ultimately be funneled through this single file.

This post documents a pattern I’ve developed for implementing a CI pipeline multiplexer inside `.gitlab-ci.yml`. The multiplexer delegates to child pipeline definitions, giving us functionality much closer to the multiple-workflows model of other CI systems, while operating within GitLab's constraints.

## Full code example

Code excerpts in this blog post relate to this full code example:
https://github.com/alex-harvey-z3q/gitlab-ci-example

## The Problem We're Solving

In our CI pipeline multiplexer, we want:
  - A clean UI for selecting the **pipeline** to run
  - A readable YAML file for each pipeline
  - A safe way to inject environment-specific values
  - A design that scales as more pipelines are added.

GitLab gives us most of the primitives we need: pipeline selection via variables, templating via external tools like `ytt`, and downstream triggering via `trigger:`.

What GitLab does _not_ provide, unlike Jenkins, is any notion of dynamic or computed input parameters — variables whose values depend on other variables or are generated at runtime. So, there is nothing similar to the Jenkins 'Active Choices Plugin', for example. Instead, all pipeline inputs for all pipelines in GitLab must be declared statically and globally in `.gitlab-ci.yml`. This also means that any variable needed by one specific pipeline must be declared globally and therefore appears as an input for every pipeline, whether it applies to them or not.

## Project Layout

An example project layout is as follows:

    .gitlab-ci.yml       # Parent multiplexer pipeline. Main entrypoint.
    .gitlab/ci/
      data-quality.yml   # The child pipeline for the data-quality task.
      render-report.yml  # etc
      sync-assets.yml
    .gitlab/scripts/
      data-quality.sh    # A shell script that implements the data-quality task.
      render-report.sh   # etc
      sync-assets.sh

## The Parent "Multiplexer" Pipeline

The parent pipeline doesn't do any operational work. Its job is:

1. Accept pipeline-selection input
2. Render the appropriate child pipeline using the **ytt** templating tool
3. Trigger the resulting pipeline downstream.

### User-Selectable Inputs

We expose options to the user through GitLab's "Run pipeline" UI:

``` yaml
variables:
  PIPELINE:
    description: "Choose a pipeline"
    value: NOT_SELECTED
    options:
      - NOT_SELECTED
      - data-quality
      - render-report
      - sync-assets

  TARGET_ENV:
    description: "Environment"
    value: NOT_SELECTED
    options:
      - NOT_SELECTED
      - dev
      - prod
```

This gives a simple drop-down menu. No YAML changes are required to run a different child pipeline.

## YAML Anchors for Pipeline Rules

In order to trigger the pipelines in different scenarios (e.g. to have a merge request pipeline, a pipeline to run on the main branch and manual pipelines run from the UI) GitLab CI provides "rules". But frequently the rules need to be specified again and again for each task, and this quickly becomes repetitive and unreadable.

To avoid this duplication, I define **YAML anchors** with human-readable names for reusable boolean expressions:

```yaml
.is_mr: &is_mr >
  $CI_PIPELINE_SOURCE == "merge_request_event"

.is_push_main: &is_push_main >
  $CI_PIPELINE_SOURCE == "push" &&
  $CI_COMMIT_BRANCH == "main"

.is_manual: &is_manual >
  $CI_PIPELINE_SOURCE == "web"
```

We can now reference these anchors throughout the parent pipeline using
`*is_mr`, `*is_push_main`, and so on.

### Applying Rules

For example, the **Generate Config** job should run only for manual
invocations:

``` yaml
Generate Config:
  stage: generate
  rules:
    - if: *is_manual
      when: always
    - when: never
```

Similarly, the **Shellcheck** job should run only on merge requests or
pushes to `main`:

``` yaml
Shellcheck:
  stage: check
  rules:
    - if: *is_mr
      when: always
    - if: *is_push_main
      when: always
    - when: never
```

Rules determine which jobs are visible in each pipeline context without
cluttering the child pipelines.

## Rendering the Child Pipeline

The parent pipeline dynamically generates a child pipeline configuration using **ytt**.

``` yaml
Generate Config:
  stage: generate
  image: ci-tool:latest
  script:
    - |
      cat > values.yml <<EOF
      #@data/values
      ---
      pipeline: $PIPELINE
      environment: $TARGET_ENV
      EOF

      ytt -f ".gitlab/ci/${PIPELINE}.yml" -f values.yml > generated.yml

  artifacts:
    paths: [generated.yml]
  rules:
    - if: *is_manual
      when: always
```

This produces a temporary file `generated.yml` containing the fully rendered child pipeline.

## Triggering the Child Pipeline

``` yaml
Trigger Pipeline:
  stage: trigger
  needs: ["Generate Config"]
  trigger:
    include:
      - artifact: generated.yml
        job: Generate Config
    strategy: depend
  rules:
    - if: *is_manual
      when: always
```

This hands off execution to the child pipeline, which becomes a standalone, fully resolved pipeline.

## Structure of a Child Pipeline

``` yaml
#@ load("@ytt:data", "data")
#@ env = data.values.environment

workflow:
  rules:
    - when: always

stages:
  - validate

Data Quality Checks:
  stage: validate
  image: alpine:latest

  variables:
    ENV: #@ env

  script:
    - ./scripts/run-data-quality.sh --env "$ENV"
```

## Discussion

This pattern fills a gap in GitLab CI's design, but it's not a silver bullet. It works best for repositories that accumulate a handful of operational pipelines: data refreshes, report generators, snapshot utilities, validation tasks, and so on. These tasks are logically unrelated to the application's normal merge request workflow, but they still belong in the same repository and need to be runnable on demand.

The multiplexer gives them structure and provides a clean UX, but it also comes with trade-offs. Because GitLab cannot scope pipeline variables to individual child pipelines, the top-level input form tends to grow as more pipelines are added. Every variable declared globally becomes visible for every run. In practice this remains manageable for a small set of pipelines, but it can become unwieldy if the number grows large.

The need for templating and **ytt** introduces another layer of complexity — one that most other CI systems don't impose. This pattern, however, keeps that additional complexity to a minimum.

If you anticipate needing more dynamic behaviour than this model can support, it may simply be that GitLab CI just isn't the right tool choice. In that case, you might consider whether your workflows belong in a different CI system — such as GitHub Actions — or whether they would be better expressed through an external orchestration tool like Ansible.

Despite these constraints, though, this pattern has proven effective in real codebases. It brings a sense of modularity to a system that otherwise encourages a single monolithic CI file, and it allows operational pipelines to evolve independently without contaminating merge request pipelines or bloating `.gitlab-ci.yml`. It's not how GitLab expected users to structure pipelines, but in some projects it will prove to be a natural and pragmatic fit.

## Conclusion

This pattern — separating operational pipelines into their own files and controlling them through a templated multiplexer pipeline — keeps GitLab CI organised, scalable, and pleasant to work with.

It provides clean UI selection, clear separation of responsibilities, consistent structure for each pipeline, flexible parameterisation, and predictable behaviour through rules and anchors.
