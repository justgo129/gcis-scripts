#!/usr/bin/env perl


=head1 NAME

check-dois.pl -- Check to see if dois exist in GCIS.

=head1 DESCRIPTION

check-dois.pl checks a list of dois to see if they exist in GCIS.  The output
is a list with each line indicating whether the doi exists in GCIS.  Each 
output line includes the input doi, an optional doi tag and if the doi is
in GCIS, the uri.  If it doesn't exist, field is set "no".  Or if more than 
one entry exists (this should not occur, then the field is set to "not unique".

=head1 SYNOPSIS

./check-dois.pl [OPTIONS]

=head1 OPTIONS

=over

=item B<--url>

GCIS url, e.g. http://data-stage.globalchange.gov

=item <stdin>

List of dois (one per line)

The list may also include a second field that corresponds to the doi and is 
included when the doi is written out.

=back

=head1 EXAMPLES

    # check to see if dois are in gcis
    ./check-dois.pl -u http://data-stage.globalchange.gov < doi_list.txt

=cut

use v5.20.1;
use Mojo::UserAgent;
use Gcis::Client;
use Data::Dumper;
use Getopt::Long qw/GetOptions/;
use Pod::Usage;

GetOptions(
    'url=s'              => \(my $url),
    'help|?'             => sub { pod2usage(verbose => 2) },
) or die pod2usage(verbose => 1);

pod2usage(msg => "missing url", verbose => 1) unless $url;

{ 
    say " checking dois";
    say "     url : $url";

    my $g = Gcis::Client->new(url => $url);

    for (<STDIN>) {

        s/\r//;
        chomp;
        my ($doi, $ref) = split /,/;
        $doi =~ s/ //g;
        $ref =~ s/ //g;
        $ref = ",$ref" if $ref;
        # say " doi : $doi, ref : $ref";
        my $r = $g->get("/article/$doi");
        
        if ($r) {
            say "$doi$ref,$r->{uri}";
            next;
        }

        $r = $g->get("/autocomplete?q=$doi");
        my $n = @$r;
        if ($n == 1) {
            my ($u) = (@$r[0] =~ /^\[(.*?)\]/);
            if ($u ne 'chapter') {
                my ($d) = (@$r[0] =~ /{(.*?)}/);
                $u = "/$u/$d";
            } else {
                my ($d, $t) = (@$r[0] =~ /{(.*?)} {(.*?)}/);
                $u = "/report/$t/$u/$d";
            }
            $r = $g->get("$u") or do {
                 say "$doi$ref,$u not found";
                 next;
                 };
            say "$doi$ref,$r->{uri}";
            next;
        } elsif ($n > 1) {
            say "$doi$ref,not unique";
            next;
        }
        say "$doi$ref,no"; 

    }

    say " done";

}

1;
