#!/usr/bin/env perl
use Gcis::Client 0.12;
use List::Util qw/min/;
use Data::Dumper;
use v5.16;

no warnings 'uninitialized';

my $dry_run = 0;  # change for a dry run
my $limit = 0;    # change to limit

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

sub find_key {
    my $person = shift;
    my $people = shift;
    my @matching_last_names = grep { lc $_->{last_name} eq lc $person->{last_name} } @$people;
    if (@matching_last_names==1) {
        return make_key($matching_last_names[0]);
    }
    my $first = $person->{first_name};
    $first =~ s/\W//g;
    for (@matching_last_names) {
        if ($_->{first_name} =~ /^$first/) {
            return make_key($_);
        }
    }
    return;
}

my $url = shift || usage('no url');
$url =~ /http/ or usage("bad url: $url");
my $url_to_show = 'http://data-stage.globalchange.gov';
my $gcis = Gcis::Client->connect(url => $url);

my @all = $gcis->get("/person", { all => 1});
say "Count: ".@all;

my %groups;
for my $person (@all) {
    my $key = find_key($person,\@all) || make_key($person);
    $groups{$key} //= [];
    push @{ $groups{$key} }, $person;
}

say "groups: ".values %groups;

my $i = 0;
for my $key (keys %groups) {
    my $group = $groups{$key};
    next unless @$group > 1;
    say "--$i-- ($key)"; $i++;
    my %action;
    my $save = min map $_->{id}, @$group;
    if (my ($orc) = grep $_->{orcid}, @$group) {
        $save = $orc->{id};
    }
    my @remove = map $_->{id}, grep { $_->{id} != $save } @$group;
    $action{$save} = 'save';
    @action{$_} = 'remove' for @remove;

    for (@$group) {
        my $link = "$url_to_show/person/$_->{id}";
        say sprintf("%-20s %-20s %22s %20s %20s",@$_{qw[last_name first_name orcid]},$link,$action{$_->{id}});
    }
    next if $dry_run;
    for my $person (@remove) {
        $gcis->delete("/person/$person", { replacement => "/person/$save" } );
    }
    last if $limit && $i >= $limit;
}

