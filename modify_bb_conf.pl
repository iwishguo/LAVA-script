#!/usr/bin/perl

while (<>) {
    print $_;
    if (/meta-yocto-bsp/) {
        $a = $_;
        $a =~ s/meta-yocto-bsp/meta-luv/;
        print $a;
    }
}

