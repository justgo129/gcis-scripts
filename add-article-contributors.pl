#!/usr/bin/env perl

use Gcis::Client;
use Smart::Comments;
binmode(STDOUT, ':encoding(utf8)');
use Data::Dumper;
use YAML::XS qw/Dump/;
use v5.16;
use experimental 'signatures';

my $url = shift || die 'missing url';
my $gcis  = Gcis::Client->connect(url => $url);
my $orcid = Gcis::Client->new->url("http://pub.orcid.org")->accept("application/orcid+json");
my $xref  = Gcis::Client->new->url("http://dx.doi.org")->accept("application/vnd.citationstyles.csl+json;q=0.5");

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
        if (@matches==2) {
            warn "too many matches, cannot merge".Dumper(\@matches);
            return;
        }
    }

    return \@authors;
}

for my $article ($gcis->get("/article", { all => 1 })) {    ### Getting--->   done
    my $doi = $article->{doi} or next;
    my $some = get_orcid_authors($doi);
    my $all = get_xref_authors($doi) or die "no authors for $doi";
    my $merged = combine_author_list($some,$all) or next;
    printf "%100s\n",$doi;
    for (@$merged) {
        printf "%-25s %-30s %-30s\n",$_->{orcid},$_->{first_name},$_->{last_name};
    }
}


