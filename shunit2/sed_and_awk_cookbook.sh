if [ "$(uname -s)" == "Darwin" ] ; then
  shopt -s expand_aliases
  alias sed=/usr/local/bin/gsed
fi

testInplaceEdit() {
  echo "SEARCH bar baz" > /tmp/FILE
  sed -i 's/SEARCH/REPLACE/g' /tmp/FILE
  assertEquals "REPLACE bar baz" "$(</tmp/FILE)"
}

testAppendLine() {
  echo "PATTERN
bar" > /tmp/FILE
  sed -i '/PATTERN/a foo' /tmp/FILE
  echo "PATTERN
foo
bar" > /tmp/EXPECTED
  assertEquals "$(</tmp/EXPECTED)" "$(</tmp/FILE)"
}

testAppendLineWithSpaces() {
  echo "PATTERN
  bar
  baz" > /tmp/FILE
  sed -i -e '/PATTERN/a\' -e '  foo' /tmp/FILE
  echo "PATTERN
  foo
  bar
  baz" > /tmp/EXPECTED
  assertEquals "$(</tmp/EXPECTED)" "$(</tmp/FILE)"
}

testInsertLine() {
  echo "PATTERN
baz
qux" > /tmp/FILE
  sed -i '/PATTERN/i foo' /tmp/FILE
  echo "foo
PATTERN
baz
qux" > /tmp/EXPECTED
  assertEquals "$(</tmp/EXPECTED)" "$(</tmp/FILE)"
}

testInsertAfterLastInstanceOfPattern() {
  echo "aaa
bbb
PATTERN
bbb
PATTERN
eee" > /tmp/FILE
  echo "aaa
bbb
PATTERN
bbb
PATTERN
foo
eee" > /tmp/EXPECTED
  sed -i '1h; 1!H; $!d; x; s/.*PATTERN[^\n]*/&\nfoo/' /tmp/FILE
  assertEquals "$(</tmp/EXPECTED)" "$(</tmp/FILE)"
}

testPrintLineAfterPattern() {
  echo "aaa
PATTERN
ccc
PATTERN
ccc
eee" > /tmp/FILE
  output=$(sed -n '/PATTERN/{n;p}' /tmp/FILE)
  expected="ccc
ccc"
  assertEquals "$expected" "$output"
}

testPrintTwoLinesAfterPattern() {
  echo "PATTERN
bbb
ccc
PATTERN
bbb
ccc" > /tmp/FILE
  output=$(sed -n '/PATTERN/{n;n;p}' /tmp/FILE)
  expected="ccc
ccc"
  assertEquals "$expected" "$output"
}

testPrintLineBeforePattern() {
  echo "aaa
PATTERN
ccc
aaa
PATTERN
ccc" > /tmp/FILE
  output=$(sed '$!N; /.*\n.*PATTERN/P; D' /tmp/FILE)
  expected="aaa
aaa"
  assertEquals "$expected" "$output"
}

testPrintTwolinesBeforePattern() {
  echo "aaa
bbb
PATTERN
aaa
bbb
PATTERN" > /tmp/FILE
  output=$(sed '1N; $!N; /.*\n.*\n.*PATTERN/P; D' /tmp/FILE)
  expected="aaa
aaa"
  assertEquals "$expected" "$output"
}

testPrintFourLinesBeforePattern() {
  echo "aaa
bbb
ccc
ddd
PATTERN
aaa
bbb
ccc
ddd
PATTERN" > /tmp/FILE
  output=$(sed '1{N;N;N}; $!N; /.*\n.*\n.*\n.*\n.*PATTERN/P; D' /tmp/FILE)
  expected="aaa
aaa"
  assertEquals "$expected" "$output"
}

testPrintLinesBetweenPatternsInclusive() {
  echo "aaa
PATTERN1
bbb
ccc
ddd
PATTERN2
eee
PATTERN1
fff" > /tmp/FILE
  output=$(sed -n '/PATTERN1/,/PATTERN2/p' /tmp/FILE)
  expected="PATTERN1
bbb
ccc
ddd
PATTERN2
PATTERN1
fff"
  assertEquals "$expected" "$output"
}

testPrintLinesBetweenPatternsExclusive() {
  echo "aaa
PATTERN1
bbb
ccc
ddd
PATTERN2
eee
PATTERN1
fff" > /tmp/FILE
  output=$(sed -n '/PATTERN1/,/PATTERN2/{//!p}' /tmp/FILE)
  expected="bbb
ccc
ddd
fff"
  assertEquals "$expected" "$output"
}

testPrintLinesBetweenPatternsExclusiveFirstOnly() {
  echo "aaa
PATTERN1
bbb
ccc
ddd
PATTERN2
eee
PATTERN1
fff" > /tmp/FILE
  output=$(sed '0,/PATTERN1/d;/PATTERN2/Q' /tmp/FILE)
  expected="bbb
ccc
ddd"
  assertEquals "$expected" "$output"
}

testGrepFunction() {
  echo "aaa
bbb
function() {
  ccc
  ddd
  PATTERN
  eee
  fff
}
ggg
PATTERN
hhh" > /tmp/FILE
  output=$(sed -n '/^function/,/^}/{/PATTERN/p;}' /TMP/FILE)
  expected="  PATTERN"
  assertEquals "$expected" "$output"
}

. shunit2
