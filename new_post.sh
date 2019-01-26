#!/usr/bin/env bash

usage() {
  echo "Usage: $0 [-h]"
  exit 1
}
[ "$1" == "-h" ] && usage

echo -n "Title: "
read title
echo -n "Tags, space separated: "
read tags

date=$(date +%Y-%m-%d)
file="_posts/$date-$(echo $title | tr '[:upper:]' '[:lower:]' | sed -e 's/ /-/g').md"

cat > $file <<EOF
---
layout: post
title: "$title"
date: $date
author: Alex Harvey
tags: $tags
---
EOF

echo "Created $file"
