#!/usr/bin/env perl


=head1 NAME

update-attrs.pl -- update citation attributes

=head1 DESCRIPTION

update-attrs.pl updates the attributes of a citation.

An attribute is deleted if the input value is null.  No update is made if the 
existing and the update values are the same.

=head1 SYNOPSIS

./update-attrs.pl [OPTIONS]

=head1 OPTIONS

=over

=item B<--url>

GCIS url, e.g. http://data-stage.globalchange.gov

=item B<--file>

File containing the citation to be updated and the updated information (yaml 
format, more informatoin in example)

=item B<--max_updates>

Maximum number of update (defaults to 20)

=item B<--verbose>

Verbose option

=item B<--dry_run>

Set to perform dry run (no actual update)

=back

=head1 EXAMPLES

./update-attrs.pl -u http://data-stage.globalchange.gov < update_list.yaml

Example input file (yaml format):

    ---
    - uri: /reference/11112222-3333-4444-5555-666677778888
      URL: http://new_www.org/data/doc/12345.6789

=cut

use Getopt::Long qw/GetOptions/; use Pod::Usage qw/pod2usage/;

use Gcis::Client; use YAML::XS; use Data::Dumper; use Clone::PP qw(clone);
# use Tuba::Util qw(new_uuid);

use strict; use v5.14;

GetOptions(
  'url=s' => \(my $url),
  'file=s' => \(my $file),
  'max_updates=i' => \(my $max_updates = 20),
  'verbose' => \(my $verbose),
  'dry_run|n' => \(my $dry_run),
  'help|?'  => sub { pod2usage(verbose => 2) }, ) or die pod2usage(verbose => 
1);

pod2usage(msg => "missing url", verbose => 1) unless $url; pod2usage(msg => 
"missing file", verbose => 1) unless $file;

my $n_updates = 0;

&main;

sub main {

    say " updating attributes";
    say " url : $url";
    say " file : $file";
    say " max updates : $max_updates";
    say " verbose on" if $verbose;
    say " dry run" if $dry_run;

    my $g = $dry_run ? Gcis::Client->new(url => $url) :
                       Gcis::Client->connect(url => $url);

    my $y = load_ref($file);
    say " uri: $y->{uri}";
    say " y :\n".Dumper($y) if $verbose;
    add_ref($g, $y);
    say "done";
}

sub load_ref {
    my $file = shift;

    open my $f, '<:encoding(UTF-8)', $file or die "can't open file : $file";

    my $yml = do { local $/; <$f> };
    my $y = Load($yml);

    return $y;
}

sub add_ref {
    my ($g, $u) = @_;

    my $uri = $u->{uri};
    if ($g->get($uri)) {
        say " reference already exist : $uri";
        return 0;
    };

    my $r = {
      attrs => $u->{attrs}, 
      identifier => $u->{identifier},
    };

    say " r :\n".Dumper($r) if $verbose;

    if ($dry_run) {
        say " would update reference for : $uri";
        return 0;
    }

    say " updating reference for : $uri";
    $g->post($r) or 
        die " unable to add reference for : $uri";

    $n_updates++;

    return 1;
}
