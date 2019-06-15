#!/usr/bin/env bash

if [ ! -x /usr/local/bin/gsed ] ; then
  echo "You need to install gnu-sed:"
  echo "$ brew install gnu-sed"
  exit 1
fi

shopt -s expand_aliases
alias sed='/usr/local/bin/gsed'

tags() {
  # shellcheck disable=SC2046,SC2013
  echo -n "[" $(for i in $(awk -F':' '/^tags/ {print $2}' _posts/*) ; do echo "$i" ; done | sort -u) "]"
}

usage() {
  echo "Usage: $0 [-h]"
  exit 1
}
[ "$1" == "-h" ] && usage

echo -n "Title: "
read -r title
echo -n "Tags, space separated: $(tags) "
read -r tags

date=$(date +%Y-%m-%d)
file="_posts/$date-$(sed 's/.*/\L&/; s/[ +,:][ +,:]*/-/g' <<< "$title").md"

cat > "$file" <<EOF
---
layout: post
title: "$title"
date: $date
author: Alex Harvey
tags: $tags
---
EOF

echo "Created $file"
