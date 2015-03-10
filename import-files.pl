#!/usr/bin/env perl

use v5.20.1;
use Mojo::UserAgent;
use Gcis::Client;
use Gcis::Exim;
use YAML::XS qw/Dump/;
use Text::Diff qw/diff/;
use Data::Dumper;
use File::Basename;

my $src_file = "report_nca3_stage_short.txt";
my $dst_file = "report_nca3_short.txt";
my $map_file = "map_files_nca3_short_x.txt";

my $what = q[file];
my $whats = $what.'s';
my $verbose = 1;
my $dry_run = 1;
my $max_change = 1000;

my $e_src = Exim->new;
my $e_dst = Exim->new;

say "src file : $src_file";
say "dst file : $dst_file";

$e_dst->load($dst_file);
$e_src->load($src_file);

my $comp = Exim->new;

say "dry_run" if $dry_run;

sub reduce {
    my $x = shift;
    my %r = ( %$x );
    my $id = $r{identifier};
    $r{uri} =~ s/$id/_ID_/;
    delete $r{thumbnail}; # thumbnail is generated on the fly
    delete $r{identifier};

    return \%r;
}

sub same {
    my ($x,$y) = @_;
    my $x1 = reduce($x);
    my $y1 = reduce($y);
    return !( Dump($x1) cmp Dump($y1) );
}

my $src_url = $e_src->{base};
my $dst_url = $e_dst->{base};

my $src = Gcis::Client->new(url => $src_url);

my $dst = $dry_run ? Gcis::Client->new(    url => $dst_url)
                   : Gcis::Client->connect(url => $dst_url);

say "src : ".$src->{url};
say "dst : ".$dst->{url};
say "resource : $what";

my %w_src = %{ $e_src->{$whats} };
my %w_dst = %{ $e_dst->{$whats} };

say "counts :";
say "         src : ".keys %w_src;
say "         dst : ".keys %w_dst;

# key on sha1
my %src = map {$w_src{$_}->{sha1} => $w_src{$_}} keys %w_src;
my %dst = map {$w_dst{$_}->{sha1} => $w_dst{$_}} keys %w_dst;

say "identifiers :";
my @only_in_src = grep !exists($dst{$_}), keys %src;
my @only_in_dst = grep !exists($src{$_}), keys %dst;
my @common      = grep exists($dst{$_}), keys %src;
say "      common : ".@common;
say " only in src : ".@only_in_src;
say " only in dst : ".@only_in_dst;

say "content : ";
my @same      = grep same($src{$_},$dst{$_}), @common;
my @different = grep !same($src{$_},$dst{$_}), @common;
say "        same : ".@same;
say "   different : ".@different;

if ($verbose) {
    say "\nonly in $src_url (uri, sha1): ";
    say " ".$src{$_}->{uri}.", ".$_ for @only_in_src;
    say "\nonly in $dst_url : ";
    say " ".$dst{$_}->{uri}.", ".$_ for @only_in_dst;
    say "\ndifferences between resources in both places : ";
    for (@different) {
        say "sha1 : ".$_;
        say diff(\Dump(reduce($src{$_})), \Dump(reduce($dst{$_})));
    }
}

say "\nmapping from src to dst" if ($verbose);

my $n = 0;
for my $src_sha1 (@same) {
    my $src_uri = $src{$src_sha1}->{uri};
    my $dst_uri = $dst{$src_sha1}->{uri};
    next if $src_uri eq $dst_uri;
    if ($verbose) {
        say " $src_uri : $dst_uri";
    }
    $comp->{files}->{$src_uri} = {uri => $src_uri, dst => $dst_uri};
    $n++;
}
say "\nnumber of mappings : $n";

if ($n) {
  $comp->{base} = {
      src => $e_src->{base},
      dst => $e_dst->{base}};
  $comp->dump($map_file);
}

say "";
$dry_run ? say "$whats to add to $dst_url (uri, sha1)"
         : say "adding $whats to $dst_url (uri, sha1)";
my $n = 0;
for my $src_uri (@only_in_src) {
    my $obj = $src{$src_uri};
    last if $n >= $max_change;
    $n++;
    say " $src{$src_uri}->{uri}, $src_uri";
    next if $dry_run;

    delete $obj->{uri};
    $dst->upload_file($obj) or error $dst->error;
}

say "\ndone";
