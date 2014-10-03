package Data::Dump::OneLine;

our $DATE = '2014-10-03'; # DATE
our $VERSION = '0.04'; # VERSION

use strict;
use vars qw(@EXPORT @EXPORT_OK $DEBUG);
use subs qq(dump);

require Exporter;
*import = \&Exporter::import;
@EXPORT = qw(dd);
@EXPORT_OK = qw(dump pp quote dump_one_line dump1);

$DEBUG = 0;

use overload ();
use vars qw(%seen %refcnt @dump @fixup %require $TRY_BASE64 $INDENT);

$TRY_BASE64 = 50 unless defined $TRY_BASE64;

sub dump
{
    local %seen;
    local %refcnt;
    local %require;
    local @fixup;

    my $name = "a";
    my @dump;

    for my $v (@_) {
	my $val = _dump($v, $name, [], tied($v));
	push(@dump, [$name, $val]);
    } continue {
	$name++;
    }

    my $out = "";
    if (%require) {
	for (sort keys %require) {
	    $out .= "require $_;";
	}
    }
    if (%refcnt) {
	# output all those with refcounts first
	for (@dump) {
	    my $name = $_->[0];
	    if ($refcnt{$name}) {
		$out .= "my \$$name=$_->[1];";
		undef $_->[1];
	    }
	}
	for (@fixup) {
	    $out .= "$_;";
	}
    }

    my $paren = (@dump != 1);
    $out .= "(" if $paren;
    $out .= format_list($paren,
			map {defined($_->[1]) ? $_->[1] : "\$".$_->[0]}
			    @dump
		       );
    $out .= ")" if $paren;

    if (%refcnt || %require) {
	$out .= ";";
	$out = "do{$out}";
    }

    print STDERR "$out\n" unless defined wantarray;
    $out;
}

*pp = \&dump;
*dump_one_line = \&dump;
*dump1 = \&dump;

sub dd {
    print dump(@_), "\n";
}

sub _dump
{
    my $ref  = ref $_[0];
    my $rval = $ref ? $_[0] : \$_[0];
    shift;

    my($name, $idx, $dont_remember, $pclass, $pidx) = @_;

    my($class, $type, $id);
    my $strval = overload::StrVal($rval);
    # Parse $strval without using regexps, in order not to clobber $1, $2,...
    if ((my $i = rindex($strval, "=")) >= 0) {
	$class = substr($strval, 0, $i);
	$strval = substr($strval, $i+1);
    }
    if ((my $i = index($strval, "(0x")) >= 0) {
	$type = substr($strval, 0, $i);
	$id = substr($strval, $i + 2, -1);
    }
    else {
	die "Can't parse " . overload::StrVal($rval);
    }
    if ($] < 5.008 && $type eq "SCALAR") {
	$type = "REF" if $ref eq "REF";
    }
    warn "\$$name(@$idx) $class $type $id ($ref)" if $DEBUG;

    my $out;
    my $hide_keys;
    unless ($dont_remember) {
	if (my $s = $seen{$id}) {
	    my($sname, $sidx) = @$s;
	    $refcnt{$sname}++;
	    my $sref = fullname($sname, $sidx,
				($ref && $type eq "SCALAR"));
	    warn "SEEN: [\$$name(@$idx)] => [\$$sname(@$sidx)] ($ref,$sref)" if $DEBUG;
	    return $sref unless $sname eq $name;
	    $refcnt{$name}++;
	    push(@fixup, fullname($name,$idx)."=$sref");
	    return "do{my \$fix}" if @$idx && $idx->[-1] eq '$';
	    return "'fix'";
	}
	$seen{$id} = [$name, $idx];
    }

    if ($class) {
	$pclass = $class;
	$pidx = @$idx;
    }

    if (defined $out) {
	# keep it
    }
    elsif ($type eq "SCALAR" || $type eq "REF" || $type eq "REGEXP") {
	if ($ref) {
	    if ($class && $class eq "Regexp") {
		my $v = "$rval";

		my $mod = "";
		if ($v =~ /^\(\?\^?([msix-]*):([\x00-\xFF]*)\)\z/) {
		    $mod = $1;
		    $v = $2;
		    $mod =~ s/-.*//;
		}

		my $sep = '/';
		my $sep_count = ($v =~ tr/\///);
		if ($sep_count) {
		    # see if we can find a better one
		    for ('|', ',', ':', '#') {
			my $c = eval "\$v =~ tr/\Q$_\E//";
			#print "SEP $_ $c $sep_count\n";
			if ($c < $sep_count) {
			    $sep = $_;
			    $sep_count = $c;
			    last if $sep_count == 0;
			}
		    }
		}
		$v =~ s/\Q$sep\E/\\$sep/g;

		$out = "qr$sep$v$sep$mod";
		undef($class);
	    }
	    else {
		delete $seen{$id} if $type eq "SCALAR";  # will be seen again shortly
		my $val = _dump($$rval, $name, [@$idx, "\$"], 0, $pclass, $pidx);
		$out = $class ? "do{\\(my \$o = $val)}" : "\\$val";
	    }
	} else {
	    if (!defined $$rval) {
		$out = "undef";
	    }
	    elsif (do {no warnings 'numeric'; $$rval + 0 eq $$rval}) {
		$out = $$rval;
	    }
	    else {
		$out = str($$rval);
	    }
	    if ($class && !@$idx) {
		# Top is an object, not a reference to one as perl needs
		$refcnt{$name}++;
		my $obj = fullname($name, $idx);
		my $cl  = quote($class);
		push(@fixup, "bless \\$obj, $cl");
	    }
	}
    }
    elsif ($type eq "GLOB") {
	if ($ref) {
	    delete $seen{$id};
	    my $val = _dump($$rval, $name, [@$idx, "*"], 0, $pclass, $pidx);
	    $out = "\\$val";
	    if ($out =~ /^\\\*Symbol::/) {
		$require{Symbol}++;
		$out = "Symbol::gensym()";
	    }
	} else {
	    my $val = "$$rval";
	    $out = "$$rval";

	    for my $k (qw(SCALAR ARRAY HASH)) {
		my $gval = *$$rval{$k};
		next unless defined $gval;
		next if $k eq "SCALAR" && ! defined $$gval;  # always there
		my $f = scalar @fixup;
		push(@fixup, "RESERVED");  # overwritten after _dump() below
		$gval = _dump($gval, $name, [@$idx, "*{$k}"], 0, $pclass, $pidx);
		$refcnt{$name}++;
		my $gname = fullname($name, $idx);
		$fixup[$f] = "$gname=$gval";  #XXX indent $gval
	    }
	}
    }
    elsif ($type eq "ARRAY") {
	my @vals;
	my $tied = tied_str(tied(@$rval));
	my $i = 0;
	for my $v (@$rval) {
	    push(@vals, _dump($v, $name, [@$idx, "[$i]"], $tied, $pclass, $pidx));
	    $i++;
	}
	$out = "[" . format_list(1, @vals) . "]";
    }
    elsif ($type eq "HASH") {
	my(@keys, @vals);
	my $tied = tied_str(tied(%$rval));

	# statistics to determine variation in key lengths
	my $kstat_max = 0;
	my $kstat_sum = 0;
	my $kstat_sum2 = 0;

	my @orig_keys = keys %$rval;
	if ($hide_keys) {
	    @orig_keys = grep !$hide_keys->($_), @orig_keys;
	}
	my $text_keys = 0;
	for (@orig_keys) {
	    $text_keys++, last unless /^[-+]?(?:0|[1-9]\d*)(?:\.\d+)?\z/;
	}

	if ($text_keys) {
	    @orig_keys = sort { lc($a) cmp lc($b) } @orig_keys;
	}
	else {
	    @orig_keys = sort { $a <=> $b } @orig_keys;
	}

	my $quote;
	for my $key (@orig_keys) {
	    next if $key =~ /^-?[a-zA-Z_]\w*\z/;
	    next if $key =~ /^-?[1-9]\d{0,8}\z/;
	    $quote++;
	    last;
	}

	for my $key (@orig_keys) {
	    my $val = \$rval->{$key};  # capture value before we modify $key
	    $key = quote($key) if $quote;
	    $kstat_max = length($key) if length($key) > $kstat_max;
	    $kstat_sum += length($key);
	    $kstat_sum2 += length($key)*length($key);

	    push(@keys, $key);
	    push(@vals, _dump($$val, $name, [@$idx, "{$key}"], $tied, $pclass, $pidx));
	}
	$out = "{";
	while (@keys) {
	    my $key = shift @keys;
	    my $val = shift @vals;
	    $out .= "$key=>$val,";
	}
        $out =~ s/,$//;
	$out .= "}";
    }
    elsif ($type eq "CODE") {
	$out = 'sub { ... }';
    }
    elsif ($type eq "VSTRING") {
        $out = sprintf +($ref ? '\v%vd' : 'v%vd'), $$rval;
    }
    else {
	warn "Can't handle $type data";
	$out = "'#$type#'";
    }

    if ($class && $ref) {
	$out = "bless($out, " . quote($class) . ")";
    }
    return $out;
}

sub tied_str {
    my $tied = shift;
    if ($tied) {
	if (my $tied_ref = ref($tied)) {
	    $tied = "tied $tied_ref";
	}
	else {
	    $tied = "tied";
	}
    }
    return $tied;
}

sub fullname
{
    my($name, $idx, $ref) = @_;
    substr($name, 0, 0) = "\$";

    my @i = @$idx;  # need copy in order to not modify @$idx
    if ($ref && @i && $i[0] eq "\$") {
	shift(@i);  # remove one deref
	$ref = 0;
    }
    while (@i && $i[0] eq "\$") {
	shift @i;
	$name = "\$$name";
    }

    my $last_was_index;
    for my $i (@i) {
	if ($i eq "*" || $i eq "\$") {
	    $last_was_index = 0;
	    $name = "$i\{$name}";
	} elsif ($i =~ s/^\*//) {
	    $name .= $i;
	    $last_was_index++;
	} else {
	    $name .= "->" unless $last_was_index++;
	    $name .= $i;
	}
    }
    $name = "\\$name" if $ref;
    $name;
}

sub format_list
{
    my $paren = shift;
    my $indent_lim = $paren ? 0 : 1;
    if (@_ > 3) {
	# can we use range operator to shorten the list?
	my $i = 0;
	while ($i < @_) {
	    my $j = $i + 1;
	    my $v = $_[$i];
	    while ($j < @_) {
		# XXX allow string increment too?
		if ($v eq "0" || $v =~ /^-?[1-9]\d{0,9}\z/) {
		    $v++;
		}
		elsif ($v =~ /^"([A-Za-z]{1,3}\d*)"\z/) {
		    $v = $1;
		    $v++;
		    $v = qq("$v");
		}
		else {
		    last;
		}
		last if $_[$j] ne $v;
		$j++;
	    }
	    if ($j - $i > 3) {
		splice(@_, $i, $j - $i, "$_[$i] .. $_[$j-1]");
	    }
	    $i++;
	}
    }
    return join(",", @_);
}

sub str {
  if (length($_[0]) > 20) {
      for ($_[0]) {
      # Check for repeated string
      if (/^(.)\1\1\1/s) {
          # seems to be a repating sequence, let's check if it really is
          # without backtracking
          unless (/[^\Q$1\E]/) {
              my $base = quote($1);
              my $repeat = length;
              return "($base x $repeat)"
          }
      }
      # Length protection because the RE engine will blow the stack [RT#33520]
      if (length($_) < 16 * 1024 && /^(.{2,5}?)\1*\z/s) {
	  my $base   = quote($1);
	  my $repeat = length($_)/length($1);
	  return "($base x $repeat)";
      }
      }
  }

  local $_ = &quote;

  if (length($_) > 40  && !/\\x\{/ && length($_) > (length($_[0]) * 2)) {
      # too much binary data, better to represent as a hex/base64 string

      # Base64 is more compact than hex when string is longer than
      # 17 bytes (not counting any require statement needed).
      # But on the other hand, hex is much more readable.
      if ($TRY_BASE64 && length($_[0]) > $TRY_BASE64 &&
	  (defined &utf8::is_utf8 && !utf8::is_utf8($_[0])) &&
	  eval { require MIME::Base64 })
      {
	  $require{"MIME::Base64"}++;
	  return "MIME::Base64::decode(\"" .
	             MIME::Base64::encode($_[0],"") .
		 "\")";
      }
      return "pack(\"H*\",\"" . unpack("H*", $_[0]) . "\")";
  }

  return $_;
}

my %esc = (
    "\a" => "\\a",
    "\b" => "\\b",
    "\t" => "\\t",
    "\n" => "\\n",
    "\f" => "\\f",
    "\r" => "\\r",
    "\e" => "\\e",
);

# put a string value in double quotes
sub quote {
  local($_) = $_[0];
  # If there are many '"' we might want to use qq() instead
  s/([\\\"\@\$])/\\$1/g;
  return qq("$_") unless /[^\040-\176]/;  # fast exit

  s/([\a\b\t\n\f\r\e])/$esc{$1}/g;

  # no need for 3 digits in escape for these
  s/([\0-\037])(?!\d)/sprintf('\\%o',ord($1))/eg;

  s/([\0-\037\177-\377])/sprintf('\\x%02X',ord($1))/eg;
  s/([^\040-\176])/sprintf('\\x{%X}',ord($1))/eg;

  return qq("$_");
}

1;
#ABSTRACT: Dump data structures as single-line strings

__END__

=pod

=encoding UTF-8

=head1 NAME

Data::Dump::OneLine - Dump data structures as single-line strings

=head1 VERSION

This document describes version 0.04 of Data::Dump::OneLine (from Perl distribution Data-Dump-OneLine), released on 2014-10-03.

=head1 SYNOPSIS

 use Data::Dump::OneLine qw(dump);

 $str = dump(@list);
 @copy_of_list = eval $str;

 # or use it for easy debug printout
 use Data::Dump::OneLine; dd localtime;

=head1 DESCRIPTION

This module is a fork of L<Data::Dump> 1.22 which removes newlines in the output
so the output is a single line. Aside from that, the whitespaces in the output
are also minimized. If an output contains literal newlines, that is considered a
bug. You can use this module just like L<Data::Dump>.

=for Pod::Coverage ^(.+)$

=head1 SEE ALSO

L<JSON> should also encode to a single-line string, but some data structures
(cyclical, contains globs or other special Perl data) cannot be encoded out of
the box to JSON.

L<Data::Dumper::OneLine> strives to do the same for L<Data::Dumper>, but last
time I tried it (at v0.05) it's still buggy.

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Data-Dump-OneLine>.

=head1 SOURCE

Source repository is at L<https://github.com/sharyanto/perl-Data-Dump-OneLine>.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Data-Dump-OneLine>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by perlancar@cpan.org.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
