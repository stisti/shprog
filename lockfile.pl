#!/usr/bin/perl -w
# Lockfile helper by Sami Tikka 2007
#
# Usage from a shell script:
# lockholder=`lockfile PATH_TO_LOCKFILE` || exit 1
# echo "Lock acquired"
# echo "Doing my thing"
# echo "Releasing lock"
# kill $lockholder
#
use strict;
use Fcntl ':flock';

die "USAGE: lockfile PATH_TO_LOCKFILE" if $#ARGV != 0;

my $lockfile = shift @ARGV;
my $LOCK;
my $signaled = 0;
$SIG{'INT'}  = sub { $signaled++ };
$SIG{'TERM'} = sub { $signaled++ };

open($LOCK, '>', $lockfile) or die "Cannot open $lockfile: $!";
flock($LOCK, LOCK_EX|LOCK_NB) or exit 1;
my $lockholder = fork();
# Parent prints the PID of child who will hang around and hold the lock
if ($lockholder > 0) {
    print "$lockholder\n";
    exit 0;
}
sleep;
flock($LOCK, LOCK_UN);
close($LOCK);
exit 0;
