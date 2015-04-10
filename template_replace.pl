#!/usr/bin/perl

my $TEMPLATE = <<EOF
       - lava-test-case <TEMP>-debug --shell "../uefi-tools/uefi-build.sh -b DEBUG <TEMP> > build_log"
       - tail -n 50 build_log
       - rm -rf Build
       - lava-test-case <TEMP>-release --shell "../uefi-tools/uefi-build.sh -b RELEASE <TEMP> > build_log"
       - tail -n 50 build_log
       - rm -rf Build
EOF
;

while (<>) {
  chomp;
  my $temp = $TEMPLATE;
  $temp =~ s/<TEMP>/$_/g;
  print $temp;
}



