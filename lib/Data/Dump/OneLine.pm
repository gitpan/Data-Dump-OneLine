package Data::Dump::OneLine;
BEGIN {
  $Data::Dump::OneLine::VERSION = '0.01';
}
# ABSTRACT: Use Data::Dump to produce dumps that fit in one line

use 5.010;
use strict;
use warnings;
use Data::Dump;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(dump_oneline dump1);



sub dump_oneline {
    local $_ = Data::Dump::dump(@_);

    s/^\s*#.*//mg; # comments
    s/^\s+//mg; # indents
    s/\n+/ /g; # newlines

    print STDERR "$_\n" unless defined wantarray;
    $_;
}

1;


sub dump1 { dump_oneline(@_) }


__END__
=pod

=head1 NAME

Data::Dump::OneLine - Use Data::Dump to produce dumps that fit in one line

=head1 VERSION

version 0.01

=head1 SYNOPSIS

 use Data::Dump::OneLine qw(dump_oneline dump1);

 # just use like Data::Dump's dump()
 dump_oneline(...);

=head1 DESCRIPTION

This module uses L<Data::Dump> to produce dumps that fits in one line, that is,
it strips all literal newlines. Great for dumping on to a shell-style comment in
code, etc.

=head1 FUNCTIONS

=head2 dump_oneline(...)

Dump one or more data structures on a single line. Uses L<Data::Dump::Filtered>
as the backend.

=head2 dump1

An alias for dump_oneline().

=head1 SEE ALSO

L<Data::Dump>

=head1 AUTHOR

Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

