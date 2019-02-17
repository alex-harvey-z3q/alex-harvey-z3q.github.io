#!/usr/bin/env bash

tags() {
  echo -n "[" $(for i in $(awk -F':' '/^tags/ {print $2}' _posts/*) ; do echo $i ; done | sort -u ) "]"
}

usage() {
  echo "Usage: $0 [-h]"
  exit 1
}
[ "$1" == "-h" ] && usage

echo -n "Title: "
read title
echo -n "Tags, space separated: $(tags) "
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
