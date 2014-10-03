#!perl

use strict;
use warnings;

use Test::More 0.98;
use Data::Dump::OneLine qw(dump_one_line dump1);

is(dump1(1), 1);
is(dump1("a\nb"), q["a\\nb"]);

my $a = [1, 2]; $a->[2] = $a;
is(dump1($a), q[do{my $a=[1,2,'fix'];$a->[2]=$a;$a;}], "arrayref 2");

done_testing;
