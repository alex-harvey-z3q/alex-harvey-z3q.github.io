---
layout: post
title: "Merge a Git repository and its history into a subdirectory of a second Git repository"
date: 2017-10-04
author: Alex Harvey
tags: git puppet
---

On more than one occasion, I have needed to merge a Git repository and its history into a subdirectory of a second Git repository.

In this post, I document how to merge a Git repo git@git.example.com:BAR/repo2.git ("second repo") into the subdir/ directory another Git repo git@git.example.com:FOO/repo1.git ("first repo"). And after the merge, I explain how to filter the history so that commands like git log, git blame and git show work as expected and show a history as if the files in the subdirectory had always been there.

## Set up a test environment

I begin by cloning the first repo into /var/tmp as follows:

```text
▶ cd /var/tmp
▶ git clone git@git.example.com:FOO/repo1.git
```

## Merge the second repo into a subdirectory

Now merge the second repo into the modules subdirectory of the first repo. Firstly, add a remote and fetch its content:

```text
▶ git remote add -f repo2 git@git.example.com:BAR/repo2.git
```

The -f option here means "after adding the remote, also fetch".

Next, perform the merge but tell Git via `--no-commit` to pretend the merge failed and stop before committing, to give us a chance to inspect and further tweak the merge result before committing.

```text
▶ git merge -s ours --no-commit repo2/master --allow-unrelated-histories
```

There should be a message printed to the screen, "Automatic merge went well; stopped before committing as requested".

The `--no-commit` option says to perform the merge but pretend the merge failed and not autocommit, to give the user a chance to inspect and further tweak the merge result before committing. This is so that we can modify the tree using the read-tree command below.

A note about the `--allow-unrelated-histories` option. Since Git 2.9, the default behaviour of git merge has changed:

> "git merge" used to allow merging two branches that have no common base by default, which led to a brand new history of an existing project created and then get pulled by an unsuspecting maintainer, which allowed an unnecessary parallel history merged into the existing project. The command has been taught not to allow this by default, with an escape hatch `--allow-unrelated-histories` option to be used in a rare event that merges histories of two projects that started their lives independently.

See [here](https://github.com/git/git/blob/master/Documentation/RelNotes/2.9.0.txt#L58-L68) in the Git change log.

Naturally, the object of the git merge command, repo2/master, means "the master branch of the Git repo at the remote named 'repo2'".

Next, read the commits from the root of repo2/master and place the files resulting from them under subdir:

```text
▶ git read-tree --prefix=subdir -u repo2/master:
```

Note the colon at the end there. The colon is actually a delimiter, with remote/branch on the left-hand side and a path on the right-hand side. Our path is an empty string, which means to use the root.

This commands returns more or less instantly and should provide no output.

The working tree should now have a directory at subdir. But the merge commit has not been done yet; the changes have only been read onto the current tree. Finally, we add the merge commit:

```text
▶ git commit
```

Now I am prompted to use the default merge commit message, which is: "Merge remote-tracking branch 'repo2/master'".

Also, I see below that this commit intends to add all of the files from the repo2 repo under subdir.

## Repairing the history

At this point, all might appear to be fine until we try to inspect the history of the files we have added.

If I run git log on one of those files, the only history is the merge commit from above that added them. If I run git blame on those files, they are shown to have their old paths. Same with git show.

At this point, I have a git filter-branch script that I wrote that repairs the history, that is based on a Stack Overflow post that I lost the original reference to.

To write it, I started with this:

```text
▶ git filter-branch --tree-filter \
>   '(echo === $GIT_COMMIT:; git ls-tree $GIT_COMMIT) >> /tmp/tree.log'
```

This helped me get my head around what was going on inside the filter and allowed me to make the observation that all of the commits from the second repo are bunched together and not ordered by date.

So, the next step is to get the initial commit’s and the latest commit’s SHA1s from the original repo2 repo and save them as $first and $last. Then:

```bash
#!/usr/bin/env bash

first=c4096edb47f3a07e4f9d670c7edff564329b82f9
last=01d14f0a82c860849e9cfb5884f5b54e8486b248
subdir=subdir

git filter-branch --tree-filter '
  first='"$first"'
  last='"$last"'

  subdir='"$subdir"'
  log_file=/tmp/filter.log

  [ "$GIT_COMMIT" = "$first" ] && seen_first=true

  if [ "$seen_first" = "true" ] && [ "$seen_last" != "true" ]; then
    echo "=== $GIT_COMMIT: making changes"
    files=$(git ls-tree --name-only $GIT_COMMIT)
    mkdir -p $subdir
    for i in $files; do
      mv $i $subdir || echo "ERR: mv $i $subdir failed"
    done
  else
    echo "=== $GIT_COMMIT: ignoring"
  fi \
    >> $log_file

  [ "$GIT_COMMIT" = "$last" ] && seen_last=true

  status=0  # tell tree-filter never to fail
'
```

A few notes about the script:

Obviously, its purpose is to rewrite the history, moving the files from their original locations in the history to their new locations in their new repo.

The variable $status is used internally by Git to cause the behaviour documented in git help filter-branch:

> If any evaluation of returns a non-zero exit status, the whole operation will be aborted.

I discovered the status variable by using set -x.

Finally, the /tmp/filter.log gives me confidence that I know what has changed and what hasn’t changed, before I finally rewrite the original repo using `git push origin --force`.

## A better way?

I have no doubt there is an easier way to do this, but at the moment, it’s a procedure that has worked for me. Do let me know if you know of that better way!
