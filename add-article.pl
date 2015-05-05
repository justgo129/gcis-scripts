#!/usr/bin/env perl

=head1 NAME

add-article.pl -- Add articles to GCIS.

=head1 DESCRIPTION

add-article.pl adds a list of articles to GCIS based on their DOIs.  Journals
containing the article may also be added (optional).  

If an article (or journal) already exists in GCIS, it is not added.

'crossref.org' is used to obtain biblio information for the articles and 
journals.

An errata file may be used when verifying the journal information.  This allows for the journal information obtained from the doi to be different from 
the information stored in gcis (the gcis information is not changed).

[Note: Books and book sections are not fully implemented and so are not added.]

=head1 SYNOPSIS

./add-article.pl [OPTIONS]

=head1 OPTIONS

=over

=item B<--url>

GCIS url, e.g. http://data-stage.globalchange.gov

=item <stdin>

List of article dois (one per line)

=item B<--max_updates>

Maximum number of update (defaults to 10)

=item B<--do_not_add_journal>

Flag indicating journals are not to be added

=item B<--errata>

Errata file (yaml) - contains aliases for articles or journals that 
already exists (see below for file example)

=item B<--verbose>

Verbose option

=item B<--dry_run> or B<--n>

Dry run

=back

=head1 EXAMPLES

# add a set of articles to gcis

./add-article.pl -u http://data-stage.globalchange.gov < article_list.txt

Example errata file (value corresponds to gcis, alias to crossref):

   ---
   article:
   - uri: /article/10.9999/1999.abc
     errata:
     - item: issn
       source: crossref
       value: 0001-0002
       alias: 9991-9992

=cut

use Gcis::Client;
use YAML::XS;
use Data::Dumper;
use Clone::PP qw(clone);
use Getopt::Long qw/GetOptions/;
use Pod::Usage;

use strict;
use v5.14;

GetOptions(
    'url=s'              => \(my $url),
    'max_updates=i'      => \(my $max_updates = 10),
    'do_not_add_journal' => \(my $do_not_add_journal), 
    'errata=s'           => \(my $errata),
    'verbose'            => \(my $verbose),
    'dry_run|n'          => \(my $dry_run),
    'help|?'             => sub { pod2usage(verbose => 2) },
) or die pod2usage(verbose => 1);

pod2usage(msg => "missing url", verbose => 1) unless $url;

my $n_updates = 0;

&main;

sub main {

    say " adding articles";
    say "     url : $url";
    say "     max updates : $max_updates";
    say "     do not add journal" if $do_not_add_journal;
    say "     errata file : $errata" if $errata;
    say "     verbose on" if $verbose;
    say "     dry run" if $dry_run;

    my $g = $dry_run ? Gcis::Client->new(url => $url) :
                       Gcis::Client->connect(url => $url);

    my $d = Gcis::Client->new
              ->accept("application/vnd.citationstyles.csl+json;q=0.5")
              ->url("http://api.crossref.org");

    my $e = load_errata($errata) if $errata;

    $d->logger($g->logger);

    for (<STDIN>) {
        s/\r//;
        chomp;
        my $doi = $_;
        say " doi : $doi";
        if (doi_exists($g, $doi)) {
           say "   already in gcis : $doi";
           next;
        }
        my $art = get_article($d, $doi) or do {
           say "   not found or error in crossref : $doi";
           next;
        };
        say "   art :\n".Dumper($art) if $verbose;

        fix_article($e, $art);
        $art->{title} or do {
           say "   no title (after errata) for $doi";
           next;
        };

        my $pub;
        if ($art->{issn}) {
            $pub = get_journal_gcis($g, $art);
            next if $pub eq 1;
            if ($pub) {
                fix_journal($e, $pub);
                titles_match($art, $pub) or next;
            } else {
                $pub = get_journal_doi($d, $art);                
                fix_journal($e, $pub);
                titles_match($art, $pub) or next;
                put_journal($g, $pub) or next;
            }
        } elsif ($art->{isbn}) {
            say "   skipping book sections for now : $doi";
            next;
            $pub = get_book($d, $art) or next;
            put_book($g, $pub) or next;
        } else {
            say "   no issn or isbn for $doi";
            next;
        }
        
        $art->{journal_identifier} = $pub->{identifier};
        put_article($g, $art);
        last if $n_updates >= $max_updates;
    }

    say " done";
}

sub load_errata {
    my $file = shift;

    open my $f, '<:encoding(UTF-8)', $file or die "can't open file : $file";

    my $yml = do { local $/; <$f> };
    my $y = Load($yml); 

    my @resource_list = qw(journal article);
    my @detail_list = qw(item source value alias);
    my @source_list = qw(crossref);

    my $e;
    ref $y eq 'HASH' or die "top level not a hash";
    for my $r (keys %{ $y }) {
        grep $r eq $_, @resource_list or next;
        ref $y->{$r} eq 'ARRAY' or die "second level must be an array";
        for my $h (@{ $y->{$r} }) {
            ref $h eq 'HASH' or die "third level must be a hash";
            my $uri = $h->{uri} or die "no uri";
            $h->{errata} or die "no errata";
            ref $h->{errata} eq 'ARRAY' or die "forth level must be an array";
            for my $g (@{ $h->{errata} }) {
                my $i = $g->{item} or die "no item";
                grep $g->{source}, $_, @source_list or next;
                for my $d (keys %{ $g }) {
                    next if $d eq 'item';
                    grep $d eq $_, @detail_list or die "invalid detail";
                    $e->{$uri}->{$i}->{$d} = $g->{$d};
                }
            }
        }
    }

    return $e;
}

sub doi_exists {
    my ($g, $doi) = @_;

    return 1 if $g->get("/article/$doi");

    my $r = $g->get("/autocomplete?q=$doi");
    my $n = @$r;
    return 0 if $n eq 0;
    if ($n > 1) {
        say "   more than one entry with this doi";
        return 1;
    }

    my ($u) = (@$r[0] =~ /^\[(.*?)\]/);
    return 0 if $u eq 'dataset';

    if ($u eq 'chapter') {
        my ($d, $t) = (@$r[0] =~ /{(.*?)} {(.*?)}/);
        $u = "/report/$t/$u/$d";
    } else {
        my ($d) = (@$r[0] =~ /{(.*?)}/);
        $u = "/$u/$d";
    }
    return 1 if $r = $g->get("$u");

    say "   doi not found (autocomplete)";
    return 0;
}

sub get_article {
    my ($d, $doi) = @_;

    my $c = $d->get("/works/$doi") or do {
        say "   no article for $doi";
        return 0;
    };
    my $cr = $c->{message} or do {
        say "   no article content for $doi";
        return 0;
    };

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

sub fix_article {
    my ($e, $a) = @_;

    my $uri = "/article/$a->{identifier}";
    my $f = $e->{$uri} or return 0;
    for (keys %{ $f }) {
        my $i = $f->{$_};
        if (ref $a->{$_} eq 'ARRAY') {
            for my $v (@{ $a->{$_} }) {
                $v = $i->{alias} if $v eq $i->{value};
            }
        } else {
            $a->{$_} = $i->{alias} if $a->{$_} eq $i->{value};
        }
    }
    return 0;
}

sub fix_journal {
    my ($e, $p) = @_;

    my $uri = "/journal/$p->{identifier}";
    my $f = $e->{$uri} or return 0;
    for (keys %{ $f }) {
        $p->{$_} or next;
        my $i = $f->{$_};
        if (ref $p->{$_} eq 'ARRAY') {
            for my $v (@{ $a->{$_} }) {
                $v = $i->{alias} if $v eq $i->{value};
            }
        } else {
            $p->{$_} = $i->{alias} if $p->{$_} eq $i->{value};
        }
        $_ eq 'title' or next;
        $p->{identifier} = make_id($i->{alias});
    }
    return 0;
}

sub get_journal_gcis {
    my ($g, $art) = @_;

    my $n = @{ $art->{issn} } or return 0;

    my $issn;
    my $id;
    my $r;
    for $issn (@{ $art->{issn} }) {
        $r = $g->get("/autocomplete?type=journal&q=$issn") or do {
           say "   can not do autocomplete for : $issn";
           next;
        };
    }
    return 0 if @$r eq 0;

    if (@$r gt 1) {
        say "   more than one journal with same issn : $issn";
        return 1;
    }

    my ($t) = (@$r[0] =~ /^\[(.*?)\]/);
    if ($t ne 'journal') {
        say "   not a journal : @$r[0]";
        return 1;
    };

    my ($id) = (@$r[0] =~ /{(.*?)}/);

    my $p = $g->get("/journal/$id") or do {
        say "   journal not found : $id";
        return 1;
    };

    return $p;
}

sub titles_match {
    my ($a, $p) = @_;

    my $match = 0;
    for (@{ $a->{parent_title} }) {
        $match = $p->{title} eq $_;
        last if $match;
    }
    return 1 if $match;

    say "   same journal with different title : $p->{identifier}";
    say "     article title(s) : $_" for @{ $a->{parent_title} };
    say "     journal title :    $p->{title}";
    return 0;
}

sub get_journal_doi {
    my ($d, $art) = @_;

    my $n = @{ $art->{issn} } or return 0;

    my $c;
    my $issn;
    for (@{ $art->{issn} }) {
       $c = $d->get("/journals/issn:$_") or next;
       $issn = $_;
       last;
    }
    if (!$c) {
        say "   no journal for $art->{doi}";
        return 0;
    }

    my $cr = $c->{message} or do {
        say "   no journal content for $issn";
        return 0;
    };

    my $p;

    $p->{print_issn} = $cr->{ISSN}[0] or do {
        say "   no issn for $issn";
        return 0;
    };
    if ($cr->{ISSN}[1]) {
        $p->{online_issn} = $cr->{ISSN}[1];
    }

    $p->{title} = $cr->{title} or do {
        say "   no title for $issn";
        return 0;
    };

    $p->{publisher} = $cr->{publisher} or do {
        say "   no publisher for $issn";
        return 0;
    };

    $p->{identifier} = make_id($p->{title});

    return $p;
}

sub get_book {
    my ($d, $art) = @_;

    my $n = @{ $art->{isbn} } or return 0;
    my $id = $art->{doi};
    $id =~ s/\/.*//;
    my $c;
    my $isbn;
    for (@{ $art->{isbn} }) {
        s/.*\///;
        $c = $d->get("/works/$id/$_") or next;
        $isbn = $_;
        last;
    }
    if (!$c) {
        say "   no book for $art->{doi}";
        return 0;
    }

    my $cr = $c->{message} or do {
        say "   no journal content for $isbn";
        return 0;
    };

    my $a;
    $a->{isbn} = $isbn;
    $a->{title} = $cr->{title} or do {
        say "   no title for $isbn";
        return 0;
    };
    $a->{publisher} = $cr->{publisher} or do {
        say "   no publisher for $isbn";
        return 0;
    };
    $a->{year} = $cr->{issued}{'date-parts'}[0][0] or do {
        say "   no year for $isbn";
        return 0;
    };

    $a->{type} = $cr->{type};

    return $a;
}

sub check_book {
    my ($g, $pub) = @_;

    my $isbn = $pub->{isbn};
    my $r = $g->get("/autocomplete?type=book&q=$isbn") or do {
        say "   can not do autocomplete for : $isbn";
        return 0;
    };
    if (@$r gt 1) {
        say "   more than one book with same isbn : $isbn";
        return 1;
    }
    return 0 unless @$r eq 1;

    my ($t) = (@$r[0] =~ /^\[(.*?)\]/);
    if ($t ne 'book') {
        say "  not a book : @$r[0]";
        return 1;
    };

    my ($id) = (@$r[0] =~ /{(.*?)}/);
    my $p = $g->get("/book/$id") or do {
        say "   book not found : $id";
        return 0;
    };
    if ($p->{title} ne $pub->{title}) {
        say "   same book with different title : $isbn";
        return 1;
    }
    return $id;
}

sub make_id {
    my $t = shift;

    my $id;
    for (split / /, $t) {
       chomp;
       s/&/and/;
       s/:|;|,|\.|!|\"|\'|_/-/g;
       s/\(|\)|\[|\]|\{|\}/-/g;
       $id = $id.($id ? "-" : "").(lc $_);
    }
    $id =~ s/-+/-/g;
    $id =~ s/^-|-$//g;

    return $id;
}

sub put_book {
    my ($g, $pub) = @_;

    my $p = clone($pub);
    delete $p->{type};
    my $t = $p->{title}[0];
    delete $p->{title};
    $p->{title} = $t;

    my $id = check_book($g, $p);
    return $id if $id;

    if ($dry_run) { 
       say "   would add book : $p->{title}";
       return 1;
    }

    say "   adding book : $p->{title}"; 

    $p->{identifier} = make_id($p->{title});
    $g->post("/book" => $p) or die $g->error;
    $n_updates++;

    return check_book($g, $p);
}

sub put_journal {
    my ($g, $pub) = @_;

    my $id;

    my $p = clone($pub);
    delete $p->{type};

    if ($dry_run or $do_not_add_journal) {
       say "   would add journal : $p->{identifier}";
       return 1;
    }

    say "   adding journal : $p->{identifer}";

    $g->post("/journal" => $p) or die $g->error;
    $n_updates++;

    return 0;
}

sub put_article {
    my ($g, $art) = @_;

    my $a = clone($art);
    delete $a->{$_} for qw(issn isbn type parent_title);
    my $doi = $a->{doi};

    if ($dry_run) { 
        say "   would add article : $doi";
        return 0;
    }

    say "   adding article : $doi";

    $g->post("/article" => $a) or die $g->error;
    $n_updates++;

    return 0;
}

1;
