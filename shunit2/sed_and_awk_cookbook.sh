if [ "$(uname -s)" == "Darwin" ] ; then
  shopt -s expand_aliases
  alias sed=/usr/local/bin/gsed
fi

testInplaceEdit() {
  echo "qux bar baz" > /tmp/FILE
  sed -i 's/qux/foo/g' /tmp/FILE
  assertEquals "foo bar baz" "$(</tmp/FILE)"
}

testAppendLine() {
  echo "foo
baz
qux" > /tmp/FILE
  sed -i '/foo/a bar' /tmp/FILE
  echo "foo
bar
baz
qux" > /tmp/EXPECTED
  assertEquals "$(</tmp/EXPECTED)" "$(</tmp/FILE)"
}

testAppendLineWithSpaces() {
  echo "  foo
  baz
  qux" > /tmp/FILE
  sed -i -e '/foo/a\' -e '  bar' /tmp/FILE
  echo "  foo
  bar
  baz
  qux" > /tmp/EXPECTED
  assertEquals "$(</tmp/EXPECTED)" "$(</tmp/FILE)"
}

testInsertLine() {
  echo "foo
baz
qux" > /tmp/FILE
  sed -i '/baz/i bar' /tmp/FILE
  echo "foo
bar
baz
qux" > /tmp/EXPECTED
  assertEquals "$(</tmp/EXPECTED)" "$(</tmp/FILE)"
}

# sed -i '1h; 1!H; $!d; x; s/.*PATTERN[^\n]*/&\nfoo/' FILE
# sed -n '/PATTERN/{n;p;}'
# sed -n '/PATTERN/{n;n;p;}'
# sed '$!N; /PATTERN/P; D'
# sed '1N; $!N; /.*\n.*\n.*PATTERN.*/P; D'
# sed '1{N;N};$!N;/.*\n.*\n.*\n.*pattern/P;D'
# sed '1{N;N;N}; $!N; /.*\n.*\n.*\n.*\n.*PATTERN.*/P; D'
# sed -n 11p
# sed -n 4,11p
# sed -n '4,$p'
# - Solution using sed
# sed -n '/PATTERN1/,/PATTERN2/p'
# - Solution using sed
# sed -n '/PATTERN1/,/PATTERN2/p;/PATTERN2/q'
# - Solution using sed
# sed -n '/PATTERN1/,/PATTERN2/{//!p;}'
# - Solution using GNU sed
# gsed '0,/PATTERN1/d;/PATTERN2/Q'
# gsed -i 's/  *$//' FILE

. shunit2
