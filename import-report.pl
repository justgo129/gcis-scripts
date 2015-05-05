#!/usr/bin/env perl

use Getopt::Long qw/GetOptions/;
use Pod::Usage qw/pod2usage/;

use Gcis::Client;
use Gcis::Exim;
use YAML;
use Data::Dumper;

use strict;
use v5.14;

# local $YAML::Indent = 2;

GetOptions(
  'url=s'       => \(my $url),
  'log_file=s'  => \(my $log_file = '/tmp/gcis-import.log'),
  'log_level=s' => \(my $log_level = "info"),
  'input=s'     => \(my $input),
  'map_file=s'  => \(my $map_file),
  'max_import=i' => \(my $max_import = 100), 
  'local=s'     => \(my $local = '.'),
  'not_all'     => \(my $not_all),
  'dry_run|n'   => \(my $dry_run),
  'help|?'	=> sub { pod2usage(verbose => 2) },
) or die pod2usage(verbose => 1);

pod2usage(msg => "missing url", verbose => 1) unless $url;

my $n = 0;
&main;

sub main {
    say " importing a report";
    say "     url : $url";
    say "     log file : $log_file";
    say "     log level : $log_level";
    say "     input : $input" if $input;
    say "     map file : $map_file" if $map_file;
    say "     max import : $max_import";
    say "     local : $local";
    say "     not all" if $not_all;
    say "     dry run" if $dry_run;

    my $s = shift;
    my $a = Exim->new();
    my $b = $dry_run ? Exim->new($url)
                     : Exim->new($url, 'update');
    $b->not_all if $not_all;
    $b->local($local);
    my $map;
    my $map = $map_file ? Exim->new() : '';

    my $logger = Mojo::Log->new($log_file eq '-' ? () : (path => $log_file));
    $logger->level($log_level);
    $b->logger($logger);
    $b->logger_info("starting: ".$url);

    $a->load($input);
    if ($map) {
        $map->load($map_file);
        $map->set_up_map($a, $url);
    }
    $b->{report_uri} = $a->{report_uri};

#   main steps:
# 
#   1. import/map organizations/people
#   2. import/map journals/publications (except actual report)
#   3. import/map datasets
#   4. import/link report, chapters, figures, images, tables, arrrays, 
#                  findings, references, activities
#   5. import/link files
#   6. link contributors, parents

    import_resource($b, $a, $_) for qw(
        organizations
        people
        journals
        publications
        datasets
        );

    say " importing report";
    $b->import_report($a);
    say "";

    import_resource($b, $a, $_) for qw(
        chapters
        images
        figures
        arrays
        tables
        findings
        references
        activities
        );

    for (qw(
        reports
        chapters
        figures
        images
        tables
        arrays
        findings
        publications
        journals
        datasets
        )) {
        import_files($b, $a, $_);
        link_resource($b, $a, $_);
    }

    $b->logger_info("done");

    return;
}

sub import_resource {
    my ($b, $a, $types) = @_;
    
    my $type = $b->single_type($types);
    say " importing $types\n";

    my $sub = \&{"Exim::import_".$type};

    for (keys %{ $a->{$types} }) {
        $n++;
        last if $n > $max_import;
        my $obj = $a->{$types}->{$_};
        say " obj $n : $obj->{uri}";
        $b->$sub($obj);
        say "";
    }
    return;
}

sub import_files {
    my ($b, $a, $types) = @_;

    my $type = $b->single_type($types);
    say " importing files for $types\n";
    my $report_uri = $a->{report_uri};

    for (keys %{ $a->{$types} }) {
        $n++;
        last if $n > $max_import;
        my $obj = $a->{$types}->{$_};
        say " files for $n : $obj->{uri}";
        $b->import_files($type, $obj, $a);
        say "";
    }
    return;
}

sub link_resource {
    my ($b, $a, $types) = @_;

    my $type = $b->single_type($types);
    say " linking $types\n";
    my $report_uri = $a->{report_uri};

    for (keys %{ $a->{$types} }) {
        $n++;
        last if $n > $max_import;
        my $obj = $a->{$types}->{$_};
        say " link $n : $obj->{uri}";
        $b->link_contributors($type, $obj, $a->{contributors});
        $b->link_parents($type, $report_uri, $obj);
        say "";
    }
    return;
}

1;

=head1 NAME

import-report.pl -- import report from source to destination

=head1 DESCRIPTION

import-report.pl imports an entire report with all of the dependent 
information.  The report source is a yaml file (see export-report.pl).
The destination is a gcis instance.

If a mapping file is provided, the import is done after the mapping 
from source to destination is done.

Any new files associated with the report must already be downloaded 
in a local directory.

=head1 SYNOPSIS

./import-report.pl [OPTIONS]

=head1 OPTIONS

=over

=item B<--url>

GCIS url, e.g. http://data-stage.globalchange.gov

=item B<--log_file>

Log file (/tmp/gcis-import.log)

=item B<--log_level>

Log level (see Mojo::Log)

=item B<--input>

Input (source) report (yaml file, defaults to STDIN)

=item B<--map_File>

Input mapping file (yaml file, defaults to NULL)

=item B<--max_import>

Maximum number of items to import (defaults to 100)

=item B<--local>

Directory where the report files are located (defaults to ".", see get-files.pl)

=item B<--not_all>

Set to only export first set of items (opposite of "?all=1")

=item B<--dry_run or --n>

Set to perform dry run (no update)

=back

=head1 EXAMPLES

    # import a report
    ./import-report.pl --url=http://datas-dev-front.joss.ucar.edu
                       --input=report.yaml

=cut
