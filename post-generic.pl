#!/usr/bin/perl

use Gcis::Client;

my $c = Gcis::Client->connect(url => 'http://localhost:3000');

$c->post('/generic', {
        identifier => 'test',
        attrs => {
            foo => 'bar',
            baz => 'bub'
        }
    }
);
