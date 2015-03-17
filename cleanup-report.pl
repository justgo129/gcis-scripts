#!/usr/bin/env perl


use Gcis::Client;
use Gcis::Exim;
use YAML;
use Data::Dumper;

use strict;
use v5.14;

my $url = 'http://192.168.0.73:3000';

{
    my $a = Exim->new($url, 'update');

    say " cleaning up (deleting) uris";
    while (<>) {
       chomp;
       if ($_ =~ /^# /) {
           say " skipping uri : $_";
           next;
       }
       say " uri : $_";
       if (!$a->{gcis}->get($_)) {
           say "       > does not exist";
           next;
       }
       $a->{gcis}->delete($_) or say "    ** delete error **";
    }
    say " done";
}

1;
