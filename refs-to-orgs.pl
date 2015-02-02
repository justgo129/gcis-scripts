#!/usr/bin/env perl

# Convert organizations in bibliographic entries (which are
# of type 'Report') into orgs.  Associate those orgs with
# the reference from which they came.


use v5.14;

use Gcis::Client;
use Data::Dumper;
use Smart::Comments;
use Encode;

sub usage {
    print q[
Usage : ./refs-to-orgs [-n] <url> <report>
Example : ./refs-to-orgs -n http://data.gcis-dev-front.joss.ucar.edu nca3draft
];
    exit;
}

usage() unless @ARGV;

my $dry_run;
$dry_run   = shift @ARGV if $ARGV[0] eq '-n';
my $url    = $ARGV[0] or usage();
my $report = $ARGV[1] || 'nca3';

my $c = Gcis::Client->connect(url => $url);

say "Dry run" if $dry_run;

sub split_orgs {
    my $str = shift;
    my @orgs;

    @orgs = split/,/, $str;
    do {
          s/^ +//g;
          s/ +$//g;
          s/^//;
          s/^and //;
          s/; //;
          s/\.$//;
          s/^U\.?S\.? /U.S. /;

      }
      for @orgs;
    return [ grep defined && length && $_ !~ /^(inc|llc)$/i, @orgs ];
}

my %stats = ( existing => 0, new => 0 );

for my $ref ($c->get("/report/$report/reference?all=1")) {  ### Processing--->[%]          done
  next unless $ref->{attrs}{reftype} eq 'Report';
  my $reference_identifier = $ref->{identifier};
  # say "examining $reference_identifier";
  my $organizations = split_orgs($ref->{attrs}{Institution} || $ref->{attrs}{institution} || $ref->{attrs}{publisher});
  unless (@$organizations) {
      #say "no orgs for /reference/$reference_identifier";
  }
  for my $organization_name (@$organizations) {
    my $org = $c->post_quiet("/organization/lookup/name",
      {name => $organization_name});
    if ($org) {
      $stats{existing}++;
      # say "Found " . encode('UTF-8', $organization_name);
    } else {
      $stats{new}++;
      # say "Creating " . encode('UTF-8', $organization_name);
      unless ($dry_run) {
        $org = $c->post("/organization", {name => $organization_name}) or do {
          warn $c->error;
          next;
        };
      }
    }

   # Now add this as a contributor to the publication, including the reference.
    my $pub = $c->get("/publication/$ref->{child_publication_id}");

    my $add_contributor_uri = $pub->{uri};
    $add_contributor_uri =~ s[/report][/report/contributors] or do {
      warn "could not match update_contributors in uri : $add_contributor_uri";
      next;
    };
    # say "posting to $add_contributor_uri";
    !$dry_run and do {
      $c->post(
        $add_contributor_uri => {
          organization_identifier => $org->{identifier},
          role                    => 'author',
          reference_identifier    => $reference_identifier
        }
      ) or warn $c->error;
    };
    # say "posted to $add_contributor_uri";
  }
}

say "stats : ".Dumper(\%stats);

