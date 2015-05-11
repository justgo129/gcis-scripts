#!/usr/bin/env perl

=head1 NAME

add-urls.pl -- Add a list of urls to GCIS.

=head1 SYNOPSIS

./add-urls.pl [OPTIONS]

=head1 OPTIONS

=over

=item B<--url>

GCIS url, e.g. http://data-stage.globalchange.gov

=item <stdin>

List of uri/url pairs to add (comma separated, one per line)
   Note: use "#" at start of line to denote a commment (not deleted)

=item B<--max_update>

Max update (default = 10)
 
=item B<--dry_run> or B<--n> 

Dry run

=back

=head1 EXAMPLES

# delete a set of uris from a list

./detete-uris.pl -u http://data-stage.globalchange.gov < uri_list.txt

=cut

use Gcis::Client;
use Getopt::Long qw/GetOptions/;
use Pod::Usage;
use Data::Dumper;
use strict;
use v5.14;

GetOptions(
    'url=s'	=> \(my $url),
    'max_updates=i' => \(my $max_updates = 10),
    'dry_run|n' => \(my $dry_run),
    'help|?'	=> sub { pod2usage(verbose => 2) },
) or die pos2usage(verbose => 1);

pod2usage(msg => "missing url", verbose => 1) unless $url;

{
    my $a = $dry_run ? Gcis::Client->new(url => $url) :
                       Gcis::Client->connect(url => $url);

    my $n_updates = 0;
    say " adding urls";
    say "     url : $url";
    say "     max_updates : $max_updates";
    say "     dry run" if $dry_run;

    while (<>) {
       chomp;
       my ($uri, $u) = split ",";
       if (!($uri =~ /^\//)) { 
           $uri = "/".$uri;
       }
       say " uri : $uri";
       say "     - url: $u";
       if ($uri =~ /^# /) {
           say "     - skipping uri";
           next;
       }
       my $f = $uri;
       $f =~ s[/figure/][/figure/form/update/] if !$dry_run;
       # say " f : $f";
       my $r = $a->get($f);
       if (!$r) {
           say "     - does not exist";
           next;
       }
       # say "   r :\n".Dumper($r);
       # say " current url value: $r->{url}";
       if ($r->{url}) {
           if ($r->{url} eq $u) {
              say "     - urls match, skipping";
           } else {
              say "     - url already has a value, skipping";
           }
           next;
       }       
       if ($dry_run) {
           say "     - would add url";
           next;
       }
       $r->{url} = $u;
       $a->post($uri, $r) or 
           say "     ** update error **";
       say  "     - added url";
       $n_updates++;  
       last if $n_updates >= $max_updates;
    } 
    say " done";
}

1;

