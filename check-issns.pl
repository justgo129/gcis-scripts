#!/usr/bin/env perl
use v5.14;
use Gcis::Client;
use Business::ISSN qw/is_valid_checksum/;

my $url = shift or die "no url";
my $gcis = Gcis::Client->new(url => $url);
for my $journal ($gcis->get("/journal?all=1")) {
    unless ($journal->{print_issn} || $journal->{online_issn}) {
        say "No issn for $url";
        next;
    }
    if ($journal->{print_issn} && !is_valid_checksum($journal->{print_issn})) {
        say "Invalid print issn: $journal->{print_issn} for $journal->{uri}";
    }
    if ($journal->{online_issn} && !is_valid_checksum($journal->{online_issn})) {
        say "Invalid online issn: $journal->{online_issn} for $journal->{uri}";
    }
}
