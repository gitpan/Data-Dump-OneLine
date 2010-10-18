#!perl -T

use strict;
use warnings;

use Test::More tests => 4;
use Data::Dump::OneLine qw(dump_oneline dump1);

#use lib "./t";
#require "testlib.pl";

is(dump_oneline(1), 1, "export dump_partial");
is(dump1(1), 1, "export dumpp");

is(dump1("a\nb"), q["a\\nb"], "arrayref 1");

my $a = [1, 2]; $a->[2] = $a;
is(dump1($a), q[do { my $a = [1, 2, 'fix']; $a->[2] = $a; $a; }], "arrayref 2");
