#!/usr/bin/env perl

=head1 NAME

delete-uris.pl -- Delete a list of uris from GCIS.

=head1 SYNOPSIS

./delete-uris.pl [OPTIONS]

=head1 OPTIONS

=over

=item B<--url>

GCIS url, e.g. http://data-stage.globalchange.gov

=item <stdin>

List of uris to delete (one per line)
   Note: use "#" at start of line to denote a commment (not deleted)

=item B<--dry_run> or B<--n> 

Dry run

=back

=head1 EXAMPLES

# delete a set of uris from a list

./detete-uris.pl -u http://data-stage.globalchange.gov < uri_list.txt

=cut

use Gcis::Client;
use Gcis::Exim;
use Getopt::Long qw/GetOptions/;
use Pod::Usage;

use strict;
use v5.14;

GetOptions(
    'url=s'	=> \(my $url),
    'dry_run|n' => \(my $dry_run),
    'help|?'	=> sub { pod2usage(verbose => 2) },
) or die pos2usage(verbose => 1);

pod2usage(msg => "missing url", verbose => 1) unless $url;

{
    my $a = Exim->new($url, 'update');

    say " deleting uris";
    say "     url : $url";
    say "     dry run" if $dry_run;

    while (<>) {
       chomp;
       if ($_ =~ /^# /) {
           say " skipping uri : $_";
           next;
       }
       say " uri : $_";
       if (!$a->{gcis}->get($_)) {
           say "     - does not exist";
           next;
       }
       if ($dry_run) {
           say "     - would delete";
           next;
       }
       $a->{gcis}->delete($_) or say "     ** delete error **";
       say "     - deleted";
    }
    say " done";
}

1;
