#!/usr/bin/env perl

=head1 NAME

gen-ref.pl -- generate a reference and citation.

=head1 DESCRIPTION

gen-ref.pl creates a publication in gcis and citation from a resource to that 
publication.  The details of the publication and the resource to link to 
are read from a file.

The resource must already exist.  The input file format is yaml.  If the 
reference (or citation) already exists, a new is not created.

=head1 SYNOPSIS

./gen-ref.pl [OPTIONS]

=head1 OPTIONS

=over

=item B<--url>

GCIS url, e.g. http://data-stage.globalchange.gov

=item B<--file>

File containing the reference information and the publication citing it
(yaml format, more informatoin in example)

=item B<--max_updates>

Maximum number of update (defaults to 20)

=item B<--verbose>

Verbose option

=item B<--dry_run>

Set to perform dry run (no actual update)

=back

=head1 EXAMPLES

./gen-ref.pl -u http://data-stage.globalchange.gov < ref_list.yaml

Example input file (yaml format): 

    ---
    - author: First, A. B.; Second, C. D.
      year: 2012
      type: report
      title: "A Very Long Report"
      url: http://www.big_agency.gov/pubs/999123
      pages: 999
      place: Close By, MD
      doi: 10.1234/999.a.test.doi
      cited_by: /report/another-test-report
      pub: Test of a Technical Report Series - XL-999

=cut

use Getopt::Long qw/GetOptions/;
use Pod::Usage qw/pod2usage/;

use Gcis::Client;
use YAML::XS;
use Data::Dumper;
use Clone::PP qw(clone);
use Tuba::Util qw(new_uuid);

use strict;
use v5.14;

GetOptions(
  'url=s'         => \(my $url),
  'file=s'	  => \(my $file), 
  'max_updates=i' => \(my $max_updates = 20),
  'verbose'       => \(my $verbose),
  'dry_run|n'     => \(my $dry_run),
  'help|?'        => sub { pod2usage(verbose => 2) },
) or die pod2usage(verbose => 1);

pod2usage(msg => "missing url", verbose => 1) unless $url;
pod2usage(msg => "missing file", verbose => 1) unless $file;

my $n_updates = 0;

&main;

sub main {

    say " generating reference";
    say "     url : $url";
    say "     file : $file";
    say "     max updates : $max_updates";
    say "     verbose on" if $verbose;
    say "     dry run" if $dry_run;

    my $g = $dry_run ? Gcis::Client->new(url => $url) :
                       Gcis::Client->connect(url => $url);

    my $r = load_gen($file);
    for (@{ $r }) {
        say " $_->{type} : $_->{title}";
        my $t = $_->{type};
        grep $t eq $_, qw(webpage report generic) or do {
            say " type not supported : $t";
            next;
        };
        add_gen($g, $_) or next;
        add_bib($g, $_);
        last if $n_updates >= $max_updates;
    }

    say " done";
}

sub load_gen {
    my $file = shift;

    open my $f, '<:encoding(UTF-8)', $file or die "can't open file : $file";

    my $yml = do { local $/; <$f> };
    my $y = Load($yml);

    my @required = qw(
        title type url 
        year cited_by organization
        );
    my @key_list = (@required, qw(
        pub issue issn
        pages data_source author
        volume editor sub_title
        place doi
        ));

    my $e;
    ref $y eq 'ARRAY' or die "top level not a array";
    for my $r (@{ $y }) {
        ref $r eq 'HASH' or die "second level not a hash";
        for my $m (@required) {
            grep $m eq $_, keys %{ $r } or die "keyword missing : $m";
        }
        for my $k (keys %{ $r }) {
            grep $k eq $_, @key_list or die "invalid keyword : $k";
        }
        push @{ $e }, $r;
    }

    return $e;
}

sub add_gen {
    my ($g, $r) = @_;

    my $type = $r->{type};

    my $s = $r->{url};
    my $e = $g->get("/autocomplete?type=$type&q=$s");
    if (scalar @{ $e }) {
        say "   item already exits : $e->[0]";
        my ($id) = (@$e[0] =~ /{(.*?)}/);
        $r->{identifier} = $id;
        $r->{uri} = "/$type/$id";
        return 1;
    }

    if (grep $type eq $_, qw(webpage report)) {
        $r->{identifier} = make_id($r->{title});
    } else {
        "   type not implemented : $type";
        return 0;
    }

    my $v;
    $v->{$_} = $r->{$_} for qw(title url identifier);
    if ($type ne 'webpage') {
        $v->{doi} = $r->{doi} if $r->{doi};
    }
    if ($type eq 'report') {
       $v->{publication_year} = $r->{year} or do {
           say "   year must be present for report";
           return 0;
       };
    }

    say " v :\n".Dumper($v) if $verbose;
    
    if ($dry_run) {
        say "   would add $type : $v->{title}";
        return 0;
    }

    say "   adding $type : $v->{title}";

    $g->post("/$type" => $v) or die $g->error;
    $n_updates++;

    $r->{uri} = "/$type/$r->{identifier}";

    return 1;
}

sub add_bib {
    my ($g, $r) = @_;

    my $type = $r->{type};
    my $uri = $r->{cited_by};
    my $child_uri = $r->{uri};

    if (ref_exists($g, $uri, $child_uri)) {
        say "   reference already exists : $uri";
        return 1;
    }

    my $ref;
    $ref->{publication_uri} = $uri;
    $ref->{identifier} = new_uuid();

    say " ref :\n".Dumper($ref) if $verbose;

    my $attrs;
    if ($type eq 'webpage') {
        $attrs->{'.reference_type'} = '16';
        $attrs->{reftype} = 'Web Page';
    } elsif ($type eq 'report') {
        $attrs->{'.reference_type'} = '10';
        $attrs->{reftype} = 'Report';
    } else {
        say "   $type not implemented";
        return 0;
    }
    $attrs->{_uuid} = $ref->{identifier};

    my %map_all = (
        'author' => 'Author',
        'title' => 'Title',
        'year' => 'Year',
        'url' => 'URL',
        'place' => 'Place Published',
        'organization' => 'Publisher',
        'doi' => 'DOI',
        );

    my %map = (
        'webpage' => {
            %map_all, 
            }, 
        'report' => {
            %map_all, 
            'pages' => 'Pages',
            'pub' => 'Publication', 
            'editor' => 'Editor', 
            'volume' => 'Volume', 
            'sub_title' => 'Sub Title', 
            'issn' => 'ISSN',
            }
        );
    my $map_type = $map{$type};
    for (keys %{ $map{$type} }) {
        next unless $r->{$_};
        my $m = $map{$type}->{$_};
        $attrs->{$m} = $r->{$_};
    }

    $attrs->{_uuid} = $ref->{identifier};

    say " attrs :\n".Dumper($attrs) if $verbose;

    if ($dry_run) {
        say "   would add reference for : $uri";
        return 0;
    }

    say "   adding reference for : $uri";

    $g->post("/reference", $ref) or die $g->error;

    my $ref_uri = "/reference/$ref->{identifier}";
    $g->post($ref_uri, {
        identifier => $ref->{identifier},
        attrs => $attrs,
        child_publication_uri => $child_uri,
        }) or
        die "   unable to set child pub : $ref_uri";

    $n_updates++;

    return 1;
}

sub make_id {
    my $t = shift;

    my $id;
    for (split / /, $t) {
       chomp;
       s/&/and/g;
       s/:|;|,|\.|!|\"|\'|_|\//-/g;
       s/\(|\)|\[|\]|\{|\}/-/g;
       $id = $id.($id ? "-" : "").(lc $_);
    }
    $id =~ s/-+/-/g;
    $id =~ s/^-|-$//g;

    return $id;
}

sub ref_exists {
    my ($g, $parent_uri, $child_uri) = @_;

    my $ref = $g->get("$parent_uri/reference?all=1") or return 0;
    for (@{ $ref }) {
        my $child = $g->get("/publication/$_->{child_publication_id}") or
            next;
        return 1 if $child->{uri} eq $child_uri;
    }
    return 0;
}
