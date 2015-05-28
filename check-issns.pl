#!/usr/bin/env perl
use v5.14;
use Gcis::Client;

my $url = shift or die "no url";
my $gcis = Gcis::Client->new(url => $url);
for my $journal ($gcis->get("/journal?all=1")) {
    next if $journal->{print_issn} || $journal->{online_issn};
    say "no issn for $url".$journal->{uri};
}
