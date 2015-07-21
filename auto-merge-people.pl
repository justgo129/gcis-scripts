#!/usr/bin/env perl
use Gcis::Client 0.12;
use List::Util qw/min/;
use Data::Dumper;
use v5.16;

my $dry_run = 0;

sub usage {
    say shift;
    exit;
}

sub make_key {
    my $person = shift;
    my ($first) = $person->{first_name} =~ /^(\w+)/;
    $first = lc $first;
    my ($last)  = lc $person->{last_name};
    return "$last-$first";
}

my $url = shift || usage('no url');
$url =~ /http/ or usage("bad url: $url");
my $gcis = Gcis::Client->connect(url => $url);

my @all = $gcis->get("/person", { all => 1});
say "Count: ".@all;

my %groups;
for my $person (@all) {
    my $key = make_key($person);
    $groups{$key} //= [];
    push @{ $groups{$key} }, $person;
}

say "groups: ".values %groups;

my $i = 0;
for my $key (keys %groups) {
    my $group = $groups{$key};
    next unless @$group > 1;
    say "$i : $key"; $i++;
    my %action;
    my $save = min map $_->{id}, @$group;
    if (my ($orc) = grep $_->{orcid}, @$group) {
        $save = $orc->{id};
    }
    my @remove = map $_->{id}, grep { $_->{id} != $save } @$group;
    $action{$save} = 'save';
    @action{$_} = 'remove' for @remove;

    for (@$group) {
        say sprintf('%-20s %-20s %6d %20s %10s',@$_{qw[last_name first_name id orcid]},$action{$_->{id}});
    }
    next if $dry_run;
    for my $person (@remove) {
        $gcis->delete("/person/$person", { replacement => "/person/$save" } );
    }
}

