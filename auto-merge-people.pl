#!/usr/bin/env perl
use Gcis::Client 0.12;
use List::Util qw/min/;
use Data::Dumper;
use Smart::Comments;
use v5.16;

no warnings 'uninitialized';

my $dry_run = 1;  # change for a dry run
my $limit = 0;    # change to limit
my $url = shift || usage('no url');
$url =~ /http/ or usage("bad url: $url");
my $url_to_show = "http://localhost:3000";

$|= 1;

&main;

sub usage {
    say shift;
    exit;
}

sub debug($) {
    #say shift;
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
    state $index;
    unless ($index) {
        for ( @$people ) {
            my $k = lc $_->{last_name};
            $index->{ $k } ||= [];
            push @{ $index->{$k} }, $_;
        }
    }

    my @matching_last_names = @{ $index->{ (lc $person->{last_name} ) } };
    if (@matching_last_names==1) {
        return make_key($matching_last_names[0]) unless veto($matching_last_names[0], $person);
    }
    my $first = $person->{first_name};
    $first =~ s/\W//g;
    for (@matching_last_names) {
        next if veto($_, $person);
        if ($_->{first_name} =~ /^$first/) {
            return make_key($_);
        }
    }
    return;
}

sub main {
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
    for my $key (keys %groups) {  ### grouping...[%]        done
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
}

sub veto { # veto this match
    my ($p,$q) = @_;
    my @q_pieces = map { s/\W//; lc } split / /, $q->{first_name};
    my @p_pieces = map { s/\W//; lc } split / /, $p->{first_name};

    # distinguish
    # Michael J Fox
    # Michael L Fox
    if (@q_pieces > 1 && @p_pieces > 1 && length($q_pieces[-1])==1 && length($p_pieces[-1])==1) {
        if ($q_pieces[-1] ne $p_pieces[-1]) {
            debug "# middle initial veto rule ($p->{last_name}==$q->{last_name}) $p->{first_name} vs $q->{first_name}";
            return 1;
        }
    }

    return 0;
}


