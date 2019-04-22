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

testInsertAfterLastInstanceOfPattern() {
  echo "aaa
bbb
ccc
bbb
ccc
eee" > /tmp/FILE
  echo "aaa
bbb
ccc
bbb
ccc
ddd
eee" > /tmp/EXPECTED
  sed -i '1h; 1!H; $!d; x; s/.*ccc[^\n]*/&\nddd/' /tmp/FILE
  assertEquals "$(</tmp/EXPECTED)" "$(</tmp/FILE)"
}

testPrintLineAfterPattern() {
  echo "aaa
bbb
ccc
bbb
ccc
eee" > /tmp/FILE
  output=$(sed -n '/bbb/{n;p}' /tmp/FILE)
  expected="ccc
ccc"
  assertEquals "$expected" "$output"
}

testPrintTwoLinesAfterPattern() {
  echo "aaa
bbb
ccc
aaa
bbb
ccc" > /tmp/FILE
  output=$(sed -n '/aaa/{n;n;p}' /tmp/FILE)
  expected="ccc
ccc"
  assertEquals "$expected" "$output"
}

testPrintLineBeforePattern() {
  echo "aaa
bbb
ccc
aaa
bbb
ccc" > /tmp/FILE
  output=$(sed '$!N; /.*\n.*bbb/P; D' /tmp/FILE)
  expected="aaa
aaa"
  assertEquals "$expected" "$output"
}

testPrintTwolinesBeforePattern() {
  echo "aaa
bbb
ccc
aaa
bbb
ccc" > /tmp/FILE
  output=$(sed '1N; $!N; /.*\n.*\n.*ccc/P; D' /tmp/FILE)
  expected="aaa
aaa"
  assertEquals "$expected" "$output"
}

testPrintFourLinesBeforePattern() {
  echo "aaa
bbb
ccc
ddd
eee
aaa
bbb
ccc
ddd
eee" > /tmp/FILE
  output=$(sed '1{N;N;N}; $!N; /.*\n.*\n.*\n.*\n.*eee/P; D' /tmp/FILE)
  expected="aaa
aaa"
  assertEquals "$expected" "$output"
}

testPrintLinesBetweenPatternsInclusive() {
  echo "aaa
PAT1
bbb
ccc
ddd
PAT2
eee
PAT1
fff" > /tmp/FILE
  output=$(sed -n '/PAT1/,/PAT2/p' /tmp/FILE)
  expected="PAT1
bbb
ccc
ddd
PAT2
PAT1
fff"
  assertEquals "$expected" "$output"
}

testPrintLinesBetweenPatternsExclusive() {
  echo "aaa
PAT1
bbb
ccc
ddd
PAT2
eee
PAT1
fff" > /tmp/FILE
  output=$(sed -n '/PAT1/,/PAT2/{//!p}' /tmp/FILE)
  expected="bbb
ccc
ddd
fff"
  assertEquals "$expected" "$output"
}

testPrintLinesBetweenPatternsExclusiveFirstOnly() {
  echo "aaa
PAT1
bbb
ccc
ddd
PAT2
eee
PAT1
fff" > /tmp/FILE
  output=$(sed '0,/PAT1/d;/PAT2/Q' /tmp/FILE)
  expected="bbb
ccc
ddd"
  assertEquals "$expected" "$output"
}

. shunit2
