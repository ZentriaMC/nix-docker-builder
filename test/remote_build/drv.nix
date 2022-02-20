{ runCommandNoCC }:

runCommandNoCC "remote-builder-test" { } ''
  uname -a > $out
  echo foo >> $out
''
