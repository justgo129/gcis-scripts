#!/usr/bin/env perl

use Gcis::Client;
use Smart::Comments;
binmode(STDOUT, ':encoding(utf8)');
use Data::Dumper;
use YAML::XS qw/Dump/;
use v5.14;

my $url = shift || die 'missing url';
my $c = Gcis::Client->connect(url => $url);

sub get_from_orcid {
    my $d = Gcis::Client->new->url("http://pub.orcid.org")
        ->accept("application/orcid+json");
    # see https://members.orcid.org/api/tutorial-searching-api-12-and-earlier
    for my $article ($c->get("/article", { all => 1 })) {  ### Getting-->            done
        my $doi = $article->{doi} or next;
        say "doi: $doi";
        my $r = $d->get("/v1.2/search/orcid-bio/", { q => qq[digital-object-ids:"$doi"] });
        my $count = $r->{'orcid-search-results'}{'num-found'};
        next unless $count;
        #say "authors: $count";
        for (0..$count-1) {
            my $id = $d->tx->res->json("/orcid-search-results/orcid-search-result/$_/orcid-profile/orcid-identifier");
            my $p = $d->tx->res->json("/orcid-search-results/orcid-search-result/$_/orcid-profile/orcid-bio/personal-details");
            say "author: ".$id->{path}." : ".$p->{'family-name'}{'value'}.', '.$p->{'given-names'}{'value'};
        }
        sleep 1;
    }
}

sub get_from_dx {
    my $d = Gcis::Client->new
                ->url("http://dx.doi.org")
                ->accept("application/vnd.citationstyles.csl+json;q=0.5");

    for my $article ($c->get("/article", { all => 1 })) {  ### Getting-->            done
        my $doi = $article->{doi} or next;
        my $r = $d->get("/$doi");
        for (@{ $r->{author} } ) {
            printf("%-30s %-30s\n", $_->{family}, $_->{given});
        }
    }
}

sub get_from_crossref {
    my $d = Gcis::Client->new->url("http://api.crossref.org");
    for my $article ($c->get("/article", { all => 1 })) {  ### Getting-->            done
        my $doi = $article->{doi} or next;
        my $r = $d->get("/works/$doi");
        say Dumper($r);
        sleep 1;
    }
}

get_from_orcid();

