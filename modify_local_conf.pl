#!/usr/bin/perl

while (<>) {
    if (s/^(BB_NUMBER_THREADS .* )"\d+"/$1"16"/) {
        $thread = 1;
    }
    if (s/^(MACHINE.* )".*"/$1"genericarmv8"/) {
        $machine = 1;
    }
    if (s/^(DISTRO.* )".*"/$1"luv"/) {
        $distro = 1;
    }
    print $_; 
}

if (! $thread) {
    print 'BB_NUMBER_THREADS ?= "16"', "\n";
}

