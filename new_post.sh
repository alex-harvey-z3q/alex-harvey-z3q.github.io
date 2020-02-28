#!/usr/bin/env bash

shopt -s expand_aliases
alias sed='/usr/local/bin/gsed'

usage() {
  echo "Usage: $0 [-h]"
  exit 1
}
[ "$1" == "-h" ] && usage

tags() {
  awk '
    BEGIN {
      ORS=" "
    }

    $1 == "tags" ":" {
      for (i=2; i <= NF; i++)
        seen[$i]++
    }

    END {
      print "["

      for (k in seen)
        print k

      print "]"
    }
  ' _posts/*
}

get_title_and_tags() {
  echo -n "Title: "
  read -r title
  echo -n "Tags, space separated: $(tags)"
  read -r tags
}

set_file_name() {
  local date file_part

  date="$(date +%Y-%m-%d)"

  file_part=$(sed '
    s!.*!\L&!
    s![/ +,:][/ +,:]*!-!g
  ' <<< "$title")

  file="_posts/$date-$file_part.md"
}

create_doc() {
  cat > "$file" <<EOF
---
layout: post
title: "$title"
date: $date
author: Alex Harvey
tags: $tags
---
EOF

  printf "Created:\\n%s\\n" "$file"
}

main() {
  get_title_and_tags
  set_file_name
  create_doc
}

if [ "$0" == "${BASH_SOURCE[0]}" ] ; then
  main
fi

# vim: set ft=sh:
