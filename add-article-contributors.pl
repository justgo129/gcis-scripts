#!/usr/bin/env perl

use Gcis::Client;
use Smart::Comments;
use Data::Dumper;
use YAML::XS qw/Dump/;

use v5.16;
use experimental 'signatures';

binmode(STDOUT, ':encoding(utf8)');

my $all = 1;         # all articles or just the first 20?
my $just_dump = 0;   # just dump the list or change GCIS?
my $dry_run = 1;     # no changes

my $url = shift || die 'missing url';
my $gcis  = Gcis::Client->connect(url => $url);
my $orcid = Gcis::Client->new->url("http://pub.orcid.org")->accept("application/orcid+json");
my $xref  = Gcis::Client->new->url("http://dx.doi.org")->accept("application/vnd.citationstyles.csl+json;q=0.5");

sub debug($) {
    # warn "# @_\n";
}

sub get_orcid_authors($doi) {
    my @authors;
    my $r = $orcid->get("/v1.2/search/orcid-bio/", { q => qq[digital-object-ids:"$doi"] });
    my $count = $r->{'orcid-search-results'}{'num-found'} or return \@authors;
    for (0..$count-1) {
        my $id = $orcid->tx->res->json("/orcid-search-results/orcid-search-result/$_/orcid-profile/orcid-identifier/path");
        my $p = $orcid->tx->res->json("/orcid-search-results/orcid-search-result/$_/orcid-profile/orcid-bio/personal-details");
        push @authors, {
              last_name  => $p->{'family-name'}{'value'},
              first_name => $p->{'given-names'}{'value'},
              orcid      => $id,
        };
    }
    return \@authors; 
}

sub get_xref_authors($doi) {
    my $r = $xref->get("/$doi");
    my @authors;
    for (@{ $r->{author} } ) {
        push @authors, { last_name => $_->{family}, first_name => $_->{given} };
    }
    return \@authors;
}

sub combine_author_list($some,$all) {
    my @authors = @$all;
    for my $p (@$some) {
        my @matches = grep { $_->{last_name} eq $p->{last_name} } @authors;
        if (@matches==1) {
            @authors = grep { $_->{last_name} ne $p->{last_name} } @authors;
            push @authors, $p;
        }
        if (@matches > 1) {
            warn "too many matches, cannot merge".Dumper(\@matches);
            return;
        }
    }

    return \@authors;
}

sub find_or_create_gcis_person($person) {
    my $match;

    # ORCID
    if ($person->{orcid} and $match = $gcis->get("/person/$person->{orcid}")) {
        debug "Found orcid: $person->{orcid}";
        return $match;
    }

    # Match first + last name
    if ($match = $gcis->post_quiet("/person/lookup/name",
            { last_name => $person->{last_name},
              first_name => $person->{first_name}
          })) {
        if ($match->{id}) {
            return $match;
        }
    }

    # Add more heuristics here

    return if $dry_run;

    debug "adding new person $person->{first_name} $person->{last_name}";
    my $new = $gcis->post("/person" => {
            first_name => $person->{first_name},
             last_name => $person->{last_name},
                 orcid => $person->{orcid}
            }) or do {
            warn "Error creating ".Dumper($person)." : ".$gcis->error;
            return;
        };

    return $new;
}

sub add_contributor_record($person,$article) {
    return if $dry_run;

    my $uri = $article->{uri};
    $uri =~ s[article][article/contributors];
    $gcis->post( $uri => {
            person_id => $person->{id},
            role => 'author'
        }) or debug "error posting to $uri: ".$gcis->error;
}

for my $article ($gcis->get("/article", { all => $all })) {    ### Getting--->   done
    my $doi = $article->{doi} or next;
    my $some = get_orcid_authors($doi);
    my $all = get_xref_authors($doi) or die "no authors for $doi";
    my $merged = combine_author_list($some,$all) or next;
    if ($just_dump) {
        printf "%100s\n",$doi;
        for (@$merged) {
            printf "%-25s %-30s %-30s\n",$_->{orcid},$_->{first_name},$_->{last_name};
        }
        next;
    }
    for my $person (@$merged) {
        my $found = find_or_create_gcis_person($person);
        next unless $found;
        add_contributor_record($found, $article);
    }
}


