#!/usr/bin/env perl

=head1 NAME

create-ref.pl -- create a citation.

=head1 DESCRIPTION

create-ref.pl creates a citation between from a resource in gcis and a
publication.  The list of resource/citation pairs are read from STDIN.

Some cititation information (authors, etc.) is either obtained from an 
existing citation if one exists.  All other information is obtained 
from crossref.org.  Information from crossref.org superseeds information 
from the existing citation.

Both the resource and publication must already exist.  If the publication is 
and article, the corresponding journal must also exist.  If the citation 
already exists, a new one is not created.

For a few NCA3 references, a table was created for the specific biblio
entries (see get_bib).

=head1 SYNOPSIS

./create-ref.pl [OPTIONS]

=head1 OPTIONS

=over

=item B<--url>

GCIS url, e.g. http://data-stage.globalchange.gov

=item <stdin>

Resource/pubication pairs (comma separated, one pair per line)

=item B<--max_updates>

Maximum number of update (defaults to 10)

=item B<--verbose>

Verbose option

=item B<--dry_run>

Set to perform dry run (no actual update)

=back

=head1 EXAMPLES

./create-ref.pl -u http://data-stage.globalchange.gov < citation_list.txt

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
  'max_updates=i' => \(my $max_updates = 10),
  'verbose'       => \(my $verbose),
  'dry_run|n'     => \(my $dry_run),
  'help|?'        => sub { pod2usage(verbose => 2) },
) or die pod2usage(verbose => 1);

pod2usage(msg => "missing url", verbose => 1) unless $url;

my $n_updates = 0;

&main;

sub main {

    say " creating reference";
    say "     url : $url";
    say "     max updates : $max_updates";
    say "     verbose on" if $verbose;
    say "     dry run" if $dry_run;

    my $g = $dry_run ? Gcis::Client->new(url => $url) :
                       Gcis::Client->connect(url => $url);

    my $d = Gcis::Client->new
              ->accept("application/vnd.citationstyles.csl+json;q=0.5")
              ->url("http://api.crossref.org");

    $d->logger($g->logger);

    for (<STDIN>) {
        last if $n_updates >= $max_updates;

        s/\r//;
        chomp;
        my ($pub, $res) = split /,/;
        $pub =~ s/ //g;
        fix_uri(\$pub);
        $res =~ s/ //g;
        say " pub : $pub, res : $res";

        my $r_gcis = $g->get($res) or do {
            say "   resource not in gcis : $res";
            next;
        };
        # say "   res gcis :\n".Dumper($r_gcis) if $verbose;
        if (ref_exists($g, $res, $pub)) {
            say "   reference already exists : $pub";
            next;
        };

        my $p_gcis = $g->get($pub) or do {
            say "   publication not in gcis : $pub";
            next;
        };
        # say "   pub gcis :\n".Dumper($p_gcis) if $verbose;

        my ($type) = ($pub =~ /^\/(.*?)\//);
        if ($type eq 'article') {
            my $art = get_article($d, $pub) or do {
                say "   article not found in crossref : $pub";
                next;
            };
            # say "   art doi :\n".Dumper($art) if $verbose;
            my $jou = $g->get("/journal/$p_gcis->{journal_identifier}") or do {
                say "   journal not found in gcis : ".
                    $p_gcis->{journal_identifier};
                next;
            };
            # say "   jou :\n".Dumper($jou) if $verbose;
            put_ref_art($g, $r_gcis, $p_gcis, $art, $jou);
            next;
        } 

        if ($type eq 'report') {
            my $bib = get_bib($g, $p_gcis);
            # say "   bib :\n".Dumper($bib) if $verbose;
            put_ref_rep($g, $r_gcis, $p_gcis, $bib);
            next;
        }

        say "   not an article or report (skipped) - $type not supported";
    }

    say " done";
}

sub ref_exists {
    my ($g, $res, $pub) = @_;

    my $ref = $g->get("$res/reference?all=1") or return 0;
    for (@{ $ref }) {
        my $child = $g->get("/publication/$_->{child_publication_id}") or
            next;
        fix_uri(\$child->{uri});
        return 1 if $child->{uri} eq $pub;
    }
    return 0;
}

sub get_article {
    my ($d, $pub) = @_;

    my ($doi) = ($pub =~ s/^\/.*?\///r);

    # say " doi : $doi";

    my $c = $d->get("/works/$doi") or do {
        say "   no article for $doi";
        return 0;
    };
    my $cr = $c->{message} or do {
        say "   no article content for $doi";
        return 0;
    };

    # say "   cr :\n".Dumper($cr);

    my $a;
    $a->{doi} = $doi;
    $a->{identifier} = $doi;

    $a->{title} = $cr->{title}[0] or 
        say "   no title for $doi";

    $a->{year} = $cr->{issued}{'date-parts'}[0][0] or do {
        say "   no year for $doi";
        return 0;
    };

    if ($cr->{volume}) {
        $a->{journal_vol} = $cr->{volume};
    }
    if ($cr->{page}) {
        $a->{journal_pages} = $cr->{page};
    }
    if ($cr->{author}[0]) {
        $a->{author} = clone($cr->{author});
    }
    if ($cr->{issue}) {
        $a->{issue} = $cr->{issue};
    }

    my $isn;
    if ($cr->{ISSN}[0]) {
       $a->{issn} = clone($cr->{ISSN});
    } elsif ($cr->{ISBN}[0]) {
       $a->{isbn} = clone($cr->{ISBN});
    } else {
       say "   no ISSN or ISBN for $doi";
    }

    if ($cr->{'container-title'}[0]) {
        $a->{parent_title} = clone($cr->{'container-title'});
    }

    $a->{type} = $cr->{type};

    return $a;
}

sub put_ref_art {
    my ($g, $r_gcis, $p_gcis, $art, $jou) = @_;


    my $uri = $r_gcis->{uri};
    my $ref;
    $ref->{publication_uri} = $uri;
    $ref->{identifier} = new_uuid();

    say " ref :\n".Dumper($ref) if $verbose;

    my $attrs;
    if ($art->{author}[0]) {
        for (@{ $art->{author} }) {
            my $name = author_name($_) or next;
            $attrs->{Author} .= ($attrs->{Author} ? "; " : "").$name;
        }
    }
    $attrs->{Issue} = $art->{issue} if ($art->{issue});

    for (qw(online_issn print_issn)) {
        $attrs->{ISSN} = $jou->{$_} or next;
        last;
    }
    # $attrs->{Issue} = $art->{};
    my %list = (
        journal_pages => 'Pages',
        title         => 'Title',
        journal_vol   => 'Volume',
        year          => 'Year',
        doi           => 'doi',
        );
    for (keys %list) {
        my $v = $list{$_};
        $attrs->{$v} = $p_gcis->{$_} if $p_gcis->{$_};
        next if $attrs->{$v};
        $attrs->{$v} = $art->{$_} if $art->{$_};  
    }
    $attrs->{Journal} = $jou->{title} if $jou->{title};
    $attrs->{_uuid} = $ref->{identifier};
    $attrs->{reftype} = 'Journal Article';
    $attrs->{'Type of Article'} = 'Article';
    $attrs->{'.reference_type'} = '0';

    say " attrs :\n".Dumper($attrs) if $verbose;

    if ($dry_run) { 
        say "   would add reference for : $uri";
        return 0;
    }

    say "   adding reference for : $uri";

    $g->post("/reference", $ref) or die $g->error;
    my $child_uri = $p_gcis->{uri};
    fix_uri(\$child_uri);

    my $ref_uri = "/reference/$ref->{identifier}";
    $g->post($ref_uri, {
        identifier => $ref->{identifier},
        attrs => $attrs,
        child_publication_uri => $child_uri,
        }) or 
        die "   unable to set child pub : $ref_uri";

    $n_updates++;

    return 0;
}

sub fix_uri {
    my $u = shift; 

    return 0 unless $$u =~ m/%/;

    my %list = (
        '%28' => '(', '%29' => ')',
        '%3A' => ':', '%3B' => ';', 
        '%3C' => '<', '%3E' => '>', 
        '%5B' => '[', '%5D' => ']',
        );
    for (keys %list) {
        next unless $$u =~ m/$_/;
        $$u =~ s/$_/$list{$_}/g;
    }

    return 0;
}

sub author_name {
    my $n = shift;

    my $last = $n->{family} or return 0;
    $last =~ s/(\w+)/\u\L$1/g;
    $last =~ s/^\s+|\s+$//g;

    # exceptions, see: 
    #   http://en.wikipedia.org/wiki/Capitalization#Compound_names

    if ((split / /, $last) gt 1) {
        $last =~ s/^Van De /Van de /;
        $last =~ s/^Van Der /Van der /;
        $last =~ s/^Van Ter /Van ter /;
        $last =~ s/^De La /de La /;
        $last =~ s/^D'/d'/;
        $last =~ s/^Di /di /;
        $last =~ s/^Von /von /;
        $last =~ s/^Av /av /;
        $last =~ s/^Af /af /;
        $last =~ s/^'T /'t /;
        $last =~ s/^'N /'n /;
        $last =~ s/^'S /'s /;
    } else {
        $last =~ s/^'T-/'t-/;
        $last =~ s/^'N-/'n-/;
        $last =~ s/^'S-/'s-/;
        $last =~ s/^D'/d'/;
        $last =~ s/^Mc(.)/Mc\u$1/;
        $last =~ s/^Mac(.)/Mac\u$1/;
    }

    my $name = $last;
    return $name unless $n->{given};

    my ($first, $middle) = split / /, $n->{given};
    return $name unless $first;

    my $first_initial = substr $first, 0, 1;
    $name .= ", $first_initial.";

    return $name unless $middle;

    my $middle_initial = substr $middle, 0, 1;
    $name .= " $middle_initial.";

    return $name;
}

sub get_bib {
    my ($g, $p_gcis) = @_;

    my %nca3_refs = (
        '/report/nca3' => 'dd5b893d-4462-4bb3-9205-67b532919566',
        '/report/nca3/chapter/appendix-climate-science-supplement' =>
            '0e8c6a81-f8a3-4b05-8f15-5e1c78830b9f',
        '/report/nca3/chapter/biogeochemical-cycles' =>
            '59f6037c-2f7d-431f-87d4-092f003a0129',
        '/report/nca3/chapter/ecosystems' =>
            'c343ebfa-929a-4ae6-b4ca-7e3a067e374a',
        '/report/nca3/chapter/energy-supply-and-use' =>
            '686dd899-0f98-4423-ba29-fce90af74586',
        '/report/nca3/chapter/land-use-land-cover-change' =>
            '8cbef4be-90a3-4191-b203-4f967eb0e8a4',
        '/report/nca3/chapter/oceans-marine-resources' =>
            '080d8278-2267-4892-a747-8e0c686628ce',
        '/report/nca3/chapter/our-changing-climate' =>
            'a6a312ba-6fd1-4006-9a60-45112db52190',
        );

    my $uri = $p_gcis->{uri};
    if ($nca3_refs{$uri}) {
        my $b = $g->get("/reference/$nca3_refs{$uri}");
        return ($b ? $b : 0);
    }
 
    for (@{ $p_gcis->{parents} }) {
        next unless $_->{relationship} eq "cito:isCitedBy";
        my $ref = $_->{reference} or next;
        my $b = $g->get($ref);
        return $b if $b;
    }

    return 0;
}

sub put_ref_rep {
    my ($g, $r_gcis, $p_gcis, $bib) = @_;


    my $uri = $r_gcis->{uri};
    my $ref;
    $ref->{publication_uri} = $uri;
    $ref->{identifier} = new_uuid();

    say " ref :\n".Dumper($ref) if $verbose;

    my $attrs;
    if ($bib) {
        my @exclude = (
            'Custom 4',
            '_uuid',
            '_record_number',
            '_chapter',
            'Volume',
            'Pages',
            'URL',
            );

        for my $k (keys %{ $bib->{attrs} }) {
            next if grep $k eq $_, @exclude;
            $attrs->{$k} = $bib->{attrs}->{$k};
        }
    } else {
        $attrs->{'.reference_type'} = '10';
        $attrs->{reftype} = 'Report';
        my %org;
        my $o_list;
        my $a_list;
        for (@{ $p_gcis->{contributors} }) {
            my $role = $_->{role_type_identifier} or next;
            next unless $role =~ m/author$|editor$/;
            if (my $o = $_->{organization}) {
                if (!$org{$o->{identifier}}) {
                    $org{$o->{idenifier}} = $o->{name};
                    $o_list .= ($o_list ? ", " : "").$o->{name};
                }
            }

            my $p = $_->{person} or next;
            $a_list .= ($a_list ? "; " : "").$p->{last_name};
            $a_list .= ", $p->{first_name}" if $p->{first_name};
            $a_list .= " $p->{middle_name}" if $p->{middle_name};
        }
        $attrs->{Institution} = $o_list if $o_list;
        $attrs->{Author} = $a_list if $a_list;
    }

    my %list = (
        title => 'Title',
        publication_year => 'Year', 
        doi => 'DOI',
        );
    for (keys %list) {
        next unless $p_gcis->{$_};
        $attrs->{$list{$_}} = $p_gcis->{$_};
    }
    $attrs->{_uuid} = $ref->{identifier};

    say " attrs :\n".Dumper($attrs) if $verbose;

    if ($dry_run) {
        say "   would add reference for : $uri";
        return 0;
    }

    say "   adding reference for : $uri";

    $g->post("/reference", $ref) or die $g->error;
    my $child_uri = $p_gcis->{uri};
    fix_uri(\$child_uri);

    my $ref_uri = "/reference/$ref->{identifier}";
    $g->post($ref_uri, {
        identifier => $ref->{identifier},
        attrs => $attrs,
        child_publication_uri => $child_uri,
        }) or
        die "   unable to set child pub : $ref_uri";

    $n_updates++;

    return 0;
}


1;
