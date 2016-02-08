#!/usr/bin/env perl
use Gcis::Client 0.12;
use List::Util qw/min/;
use Data::Dumper;
use Smart::Comments;
use YAML qw/Dump/;
use v5.16;

no warnings 'uninitialized';

my $dry_run = 1;  # change for a dry run 0 = not dry run
my $limit = 0;    # change to limit
my $url = shift || usage('no url');
$url =~ /http/ or usage("bad url: $url");
my $url_to_show = "http://data.globalchange.gov"; #localhost:3000";

$|= 1;

&main;

sub usage {
    say shift;
    exit;
}

sub debug($) {
    #say shift;
}

sub match {
    my ($this,$that) = @_;
    #say "Matching $this->{last_name} and $that->{last_name}";
    my ($f1,$l1) = map { lc s/\W//gr; } @$this{qw/first_name last_name/};
    my ($f2,$l2) = map { lc s/\W//gr; } @$that{qw/first_name last_name/};
    return 0 unless $l1 eq $l2;
    #return 0 if veto($this,$that);
    if (index($f1,$f2) == 0) {
        #say "Match for $f1 and $f2";
        return 1;
    }
    if (index($f2,$f1) == 0) {
        #say "Match for $f1 and $f2";
        return 1;
    }
    
    if (substr($f2,0,1) eq substr($f1,0,1)) {
        #say "Match for $f1 and $f2";
        return 1;
    }

    #say "no dice for $f1 and $f2";
    return 0;
}

sub pick_one {
    my @group = @_;
    my %action;
    # 1 orcid, 2 longest first name, 3 first
    my $save = min map $_->{id}, @group;
    my $longest = length($group[0]->{first_name});
    for (@group) {
        if (length($_->{first_name}) > $longest) {
            $save = $_->{id};
            $longest = length($_->{first_name});
        }
    }
    if (my ($orc) = grep $_->{orcid}, @group) {
        $save = $orc->{id};
    }
    die "error picking" unless $save;
    return $save;
}

sub main {
    my $gcis = $dry_run ? Gcis::Client->new(url => $url) : Gcis::Client->connect(url => $url);

    my @all = $gcis->get("/person", { all => 1});
    say "Count: ".@all;

    @all = sort {
        ( lc $a->{last_name} cmp lc $b->{last_name} )
        || (lc $a->{first_name} cmp lc $b->{first_name})
    } @all;

    my $last = shift @all;
    my $this = shift @all;
    my $current_group = [ $last ];
    my @groups;
    while (@all) {
        if (match($this,$last)) {
            push @$current_group, $this;
        }  else {
            push @groups, $current_group if @$current_group > 1;
            $current_group = [ $this ];
        }
        $last = $this;
        $this = shift @all;
    }
    my $i = 1;
    for (@groups) {
        my $save = pick_one(@$_);
        print "---- $i: \n";
        $i++;
        for (@$_) {
            my $link = "$url_to_show/person/$_->{id}";
            my $action = $_->{id} == $save ? "save" : "remove";
            say sprintf("%-20s %-20s %22s %20s %20s",@$_{qw[last_name first_name orcid]},$link,$action);
            next if $dry_run;
            next if $_->{id} == $save;
            $gcis->delete("/person/$_->{id}", { replacement => "/person/$save" } ) or die $gcis->error."\n".$gcis->tx->res->body;
        }
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


