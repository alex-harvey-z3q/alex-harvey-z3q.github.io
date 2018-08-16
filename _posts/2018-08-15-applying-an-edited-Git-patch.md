---
layout: post
title: "Applying an edited Git patch in Vim"
date: 2018-08-15
author: Alex Harvey
tags: git
---

From time to time I have needed to take a patch in unified format and then edit it before git applying it to a file. I discovered some tricks today when doing this and intend to document these in this post.

### Patch problem

By way of setting up an example, imagine we start with the following YAML file:

~~~ yaml
---

series: "Star Trek: The Next Generation"

episodes:
  -
    Name: "The Naked Now"
    StarDate: 41209.2
    AirDate: "October 5, 1987"
  -
    Name: "Code of Honor"
    StarDate: 41235.25
    AirDate: "October 12, 1987"
  -
    Name: "The Last Outpost"
    StarDate: 41386.4
    AirDate: "October 19, 1987"
  -
    Name: "Where No One Has Gone Before"
    StarDate: 41263.1
    AirDate: "October 26, 1987"
  -
    Name: "Lonely Among Us"
    StarDate: 41249.3
    AirDate: "November 2, 1987"

creator: "Gene Roddenberry"
~~~

Someone then emails a patch that is intended to update this file:

~~~ diff
commit cee8d7f5067c10d7c63cdc0856ffa27e949bbd7f
Author: Jean-luc Picard
Date:   Fri Aug 17 00:57:20 2018 +1000

    Please update this file!

diff --git a/star_trek.yml b/star_trek.yml
index 51a9f7b..33d8b12 100644
--- a/star_trek.yml
+++ b/star_trek.yml
@@ -3,6 +3,10 @@
 series: "Star Trek: The Next Generation"

 episodes:
+  -
+    Name: "Encounter at Farpoint"
+    StarDate: 41153.7
+    AirDate: "September 28, 1987"
   -
     Name: "The Naked Now"
     StarDate: 41209.2
@@ -23,5 +27,13 @@ episodes:
     Name: "Lonely Among Us"
     StarDate: 41249.3
     AirDate: "November 2, 1987"
+  -
+    Name: "Justice"
+    StarDate: 41255.6
+    AirDate: "November 9, 1987"
+  -
+    Name: "The Battle"
+    StarDate: 41723.9
+    AirDate: "November 16, 1987"

 creator: "Gene Roddenberry"
~~~

In the mean time, someone else has changed the file to:

~~~ yaml
---

studio: "Paramount"
series: "Star Trek: The Next Generation"

episodes:
  SEASON1:
    -
      Name: "The Naked Now"
      StarDate: 41209.2
      AirDate: "October 5, 1987"
    -
      Name: "Code of Honor"
      StarDate: 41235.25
      AirDate: "October 12, 1987"
    -
      Name: "The Last Outpost"
      StarDate: 41386.4
      AirDate: "October 19, 1987"
    -
      Name: "Where No One Has Gone Before"
      StarDate: 41263.1
      AirDate: "October 26, 1987"
    -
      Name: "Lonely Among Us"
      StarDate: 41249.3
      AirDate: "November 2, 1987"

creator: "Gene Roddenberry"
~~~

I now want to apply the patch that was emailed to the current version of the file, but of course it won't apply:

~~~ text
$ git apply patch 
error: patch failed: star_trek.yml:3
error: star_trek.yml: patch does not apply
~~~

### Editing the patch in vim

#### Problem 1: Lines shifted

The first problem is that lines have shifted.

This means that 3, 23 and 27 are incorrect now in `@@ -3,6 +3,10 @@` and `@@ -23,5 +27,13 @@`.

To find out what to change the first one to, I used grep -n on the first line of context in the first hunk:

~~~ text
$ grep -n 'series: "Star Trek: The Next Generation"' star_trek.yml
4:series: "Star Trek: The Next Generation"
~~~

So I change the first hunk's header to `@@ -4,6 +4,10 @@`. I'll need to do the second one later as step 2 will introduce a complicating factor.

The first hunk is now:

~~~ diff
@@ -4,6 +4,10 @@
 series: "Star Trek: The Next Generation"

 episodes:
+  -
+    Name: "Encounter at Farpoint"
+    StarDate: 41153.7
+    AirDate: "September 28, 1987"
   -
     Name: "The Naked Now"
     StarDate: 41209.2
~~~

#### Problem 2: Lines context changed

The second problem is the context around the first hunk changed. A line `SEASON1:` was added after `episodes`, so I need to manually insert that line into the patch. The first hunk becomes:

~~~ diff
@@ -4,6 +4,10 @@
 series: "Star Trek: The Next Generation"

 episodes:
   SEASON1:
+  -
+    Name: "Encounter at Farpoint"
+    StarDate: 41153.7
+    AirDate: "September 28, 1987"
   -
     Name: "The Naked Now"
     StarDate: 41209.2
~~~

#### Problem 3: Indentation changed

Having inserted a key `SEASON1` inside the `episodes` hash, I need to then correct the indentation. I can fix this by selecting the lines in visual mode and then running the following vim editor command:

~~~ text
:'<,'>s/^\([^@]\)/\1  /
~~~

I do this on both hunks. They become:

~~~ diff
@@ -4,6 +4,10 @@
 series: "Star Trek: The Next Generation"

 episodes:
   SEASON1:
+    -
+      Name: "Encounter at Farpoint"
+      StarDate: 41153.7
+      AirDate: "September 28, 1987"
     -
       Name: "The Naked Now"
       StarDate: 41209.2
@@ -23,5 +27,13 @@ episodes:
       Name: "Lonely Among Us"
       StarDate: 41249.3
       AirDate: "November 2, 1987"
+    -
+      Name: "Justice"
+      StarDate: 41255.6
+      AirDate: "November 9, 1987"
+    -
+      Name: "The Battle"
+      StarDate: 41723.9
+      AirDate: "November 16, 1987"

 creator: "Gene Roddenberry"
~~~

#### Problem 4: Before and after line counts changed

The next problem is the before and after line counts changed. These are `4` and `10` in the first hunk and `5` and `13` in the second hunk.

To find out the new counts, it's necessary to know:

> before lines = unchanged lines + deleted lines

And:

> after lines = unchanged lines + added lines

I can get the first by selecting all the lines in visual mode and then:

~~~ text
:'<,'>w ! grep -v "^-" | wc -
~~~

or:

~~~ text
:'<,'>w ! grep -v "^+" | wc -
~~~

The first hunk is the only one that changes because it's the one where I edited the context by adding the `SEASON1` line. I find that `@@ -4,6 +4,10 @@` becomes `@@ -4,7 +4,11 @@`.

#### Problem 5: Lines shifted of second hunk

Now the second hunk has shifted both by the 1 line that the first hunk was shifted by, but also by the additional `SEASON1` line I inserted. So I add 2 to each of the markers: `@@ -23,5 +27,13` @@ becomes `@@ -25,5 +29,13 @@`.

#### Final patch

The final patch now applies and it looks like:

~~~ diff
--- a/star_trek.yml
+++ b/star_trek.yml
@@ -4,7 +4,11 @@
 series: "Star Trek: The Next Generation"

 episodes:
   SEASON1:
+    -
+      Name: "Encounter at Farpoint"
+      StarDate: 41153.7
+      AirDate: "September 28, 1987"
     -
       Name: "The Naked Now"
       StarDate: 41209.2
@@ -25,5 +29,13 @@ episodes:
       Name: "Lonely Among Us"
       StarDate: 41249.3
       AirDate: "November 2, 1987"
+    -
+      Name: "Justice"
+      StarDate: 41255.6
+      AirDate: "November 9, 1987"
+    -
+      Name: "The Battle"
+      StarDate: 41723.9
+      AirDate: "November 16, 1987"

 creator: "Gene Roddenberry"
~~~

And after git applying it, the final version of the file is:

~~~ yaml
---

studio: "Paramount"
series: "Star Trek: The Next Generation"

episodes:
  SEASON1:
    -
      Name: "Encounter at Farpoint"
      StarDate: 41153.7
      AirDate: "September 28, 1987"
    -
      Name: "The Naked Now"
      StarDate: 41209.2
      AirDate: "October 5, 1987"
    -
      Name: "Code of Honor"
      StarDate: 41235.25
      AirDate: "October 12, 1987"
    -
      Name: "The Last Outpost"
      StarDate: 41386.4
      AirDate: "October 19, 1987"
    -
      Name: "Where No One Has Gone Before"
      StarDate: 41263.1
      AirDate: "October 26, 1987"
    -
      Name: "Lonely Among Us"
      StarDate: 41249.3
      AirDate: "November 2, 1987"
    -
      Name: "Justice"
      StarDate: 41255.6
      AirDate: "November 9, 1987"
    -
      Name: "The Battle"
      StarDate: 41723.9
      AirDate: "November 16, 1987"

creator: "Gene Roddenberry"
~~~
