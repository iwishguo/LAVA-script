#!/usr/bin/perl

my $TEMPLATE = <<EOF
       - lava-test-case <TEMP>-debug --shell ../uefi-tools/uefi-build.sh -b DEBUG <TEMP>
       - rm -rf Build
       - lava-test-case <TEMP>-release --shell ../uefi-tools/uefi-build.sh -b RELEASE <TEMP> 
       - rm -rf Build
EOF
;

while (<>) {
  chomp;
  my $temp = $TEMPLATE;
  $temp =~ s/<TEMP>/$_/g;
  print $temp;
}



