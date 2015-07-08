#!/usr/bin/env perl


=head1 NAME

update-attrs.pl -- update citation attributes

=head1 DESCRIPTION

update-attrs.pl updates the attributes of a citation.  

An attribute is deleted if the input value is null.  No update is made if 
the existing and the update values are the same.

=head1 SYNOPSIS

./update-attrs.pl [OPTIONS]

=head1 OPTIONS

=over

=item B<--url>

GCIS url, e.g. https://data-stage.globalchange.gov

=item B<--file>

File containing the citation to be updated and the updated information
(yaml format, more informatoin in example)

=item B<--max_updates>

Maximum number of update (defaults to 20)

=item B<--verbose>

Verbose option

=item B<--dry_run>

Set to perform dry run (no actual update)

=back

=head1 EXAMPLES

./update-attrs.pl -u http://data-stage.globalchange.gov -f update_list.yaml

Example input file (yaml format):

    ---
    - uri: /reference/11112222-3333-4444-5555-666677778888
      URL: http://new_www.org/data/doc/12345.6789

=cut

use Getopt::Long qw/GetOptions/;
use Pod::Usage qw/pod2usage/;

use Gcis::Client;
use YAML::XS;
use Data::Dumper;
use Clone::PP qw(clone);

use strict;
use v5.14;

GetOptions(
  'url=s'         => \(my $url),
  'file=s'        => \(my $file),
  'max_updates=i' => \(my $max_updates = 20),
  'verbose'       => \(my $verbose),
  'dry_run|n'     => \(my $dry_run),
  'help|?'        => sub { pod2usage(verbose => 2) },
) or die pod2usage(verbose => 1);

pod2usage(msg => "missing url", verbose => 1) unless $url;
pod2usage(msg => "missing file", verbose => 1) unless $file;

my $n_updates = 0;

&main;

sub main {

    say " updating attributes";
    say "     url : $url";
    say "     file : $file";
    say "     max updates : $max_updates";
    say "     verbose on" if $verbose;
    say "     dry run" if $dry_run;

    my $g = $dry_run ? Gcis::Client->new(url => $url) :
                       Gcis::Client->connect(url => $url);

    my $r = load_update($file);
    for my $u (@{ $r }) {
        say " uri: $u->{uri}";
        say "   u :\n".Dumper($u) if $verbose;
        update_ref($g, $u);
    }
    say " done";
}

sub load_update {
    my $file = shift;

    open my $f, '<:encoding(UTF-8)', $file or die "can't open file : $file";

    my $yml = do { local $/; <$f> };
    my $y = Load($yml);

    my @required = qw(uri);
    my @key_list = (@required, 
        'Pages', 'Volume', 'Editor', 
        'Author', 'ISSN', 'Title', 
        'Publication', 'Sub Title', 'Year', 
        'Place Published', 'Publisher',
        'URL', '.reference_type', 'reftype',
        '.publisher', 'Journal', '.place_published', 
        '_chapter', '_record_number', 
        'Issue', 'Type of Article', 'DOI',   
        'Department', 'Book Title', '_uuid', 
        'Number of Pages', 'doi', 
        );

    my $e;
    ref $y eq 'ARRAY' or die "top level not a array";
    for my $r (@{ $y }) {
        ref $r eq 'HASH' or die "second level not a hash";
        for my $m (@required) {
            grep $m eq $_, keys %{ $r } or die "no keyword $m";
        }
        for my $k (keys %{ $r }) {
            grep $k eq $_, @key_list or die "invalid keyword : $k";
        }
        push @{ $e }, $r;
    }

    return $e;
}

sub update_ref {
    my ($g, $u) = @_;

    my $uri = $u->{uri};
    my $ref = $g->get($uri) or do {
        say "   unable to get reference for : $uri";
        return 0;
    };

    my $attrs = $ref->{attrs};

    my $update = 0;
    for (keys %{ $u }) {
        next if $_ eq 'uri';
        if (defined $u->{$_}) {
            next if $attrs->{$_} eq $u->{$_};
            $attrs->{$_} = $u->{$_};
            $update = 1;
            say " updating attr $_" if $verbose;
        } else {
            delete $attrs->{$_};
            $update = 1;
            say " deleting attr $_" if $verbose;
        }
    }

    if (!$update) {
       say "   nothing to update for : $uri";
       return 1;
    }

    say " attrs :\n".Dumper($attrs) if $verbose;

    if ($dry_run) {
        say "   would update reference for : $uri";
        return 0;
    }

    say "   updating reference for : $uri";
    $g->post($uri, {
        identifier => $ref->{identifier},
        attrs => $attrs,
        }) or
        die "   unable to update reference for : $uri";

    $n_updates++;

    return 1;
}
