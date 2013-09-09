package Data::Dump::OneLine;

use 5.010001;
use strict;
use warnings;

use Data::Dump;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(dump_oneline dump_one_line dump1 dd1);

our $VERSION = '0.03'; # VERSION

sub dump_one_line {
    local $_ = Data::Dump::dump(@_);

    s/^\s*#.*//mg; # comments
    s/^\s+//mg; # indents
    s/\n+/ /g; # newlines

    print STDERR "$_\n" unless defined wantarray;
    $_;
}

sub dump1 { dump_one_line(@_) }

# old spelling
sub dump_oneline { dump_one_line(@_) }

1;
# ABSTRACT: Use Data::Dump to produce dumps that fit in one line

__END__

=pod

=head1 NAME

Data::Dump::OneLine - Use Data::Dump to produce dumps that fit in one line

=head1 VERSION

version 0.03

=head1 SYNOPSIS

 use Data::Dump::OneLine qw(dump_one_line dump1);

 # just use like Data::Dump's dump()
 dump_one_line(...);

=head1 DESCRIPTION

This module uses L<Data::Dump> to produce dumps that fits in one line, that is,
it strips all literal newlines. Great for dumping on to a shell-style comment in
code, etc.

=for Pod::Coverage ^(dump_oneline)$

=head1 FUNCTIONS

=head2 dump_one_line(...)

Dump one or more data structures on a single line. Uses L<Data::Dump> as the
backend.

=head2 dump1

A shorter alias for dump_one_line().

=head1 SEE ALSO

L<Data::Dump>

=head1 AUTHOR

Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
