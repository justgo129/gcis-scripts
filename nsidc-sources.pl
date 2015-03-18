#!/usr/bin/env perl
use utf8;
use v5.20;
#use open qw/:std :utf8/;
#binmode(DATA,':utf8');

use Gcis::Client;

my $lexicon = 'nsidc';

my $c = Gcis::Client->connect(url => shift || 'http://localhost:3000');

while (<DATA>) {
    chomp;
    my ($term,$gcid) = split /\s+:\s+/;
    say qq['$term' '$gcid' ];
    $c->post("/lexicon/$lexicon/term/new", {
            term => $term,
            gcid => $gcid,
            context => 'Source',
        }) or die $c->error;
}

__DATA__
ADEOS-II : /platform/advanced-earth-observing-satellite-ii
ADEOS-I : /platform/advanced-earth-observing-satellite
ALOS : /platform/advanced-land-observing-satellite
AQUA : /platform/aqua
DMSP 5D-2/F11 : /platform/defense-meteorological-satellite-program-f-11
DMSP 5D-2/F13 : /platform/defense-meteorological-satellite-program-f-13
DMSP 5D-2/F14 : /platform/defense-meteorological-satellite-program-f-14
DMSP 5D-2/F15 : /platform/defense-meteorological-satellite-program-f-15
DMSP 5D-2/F8 : /platform/defense-meteorological-satellite-program-f-8
DMSP 5D-3/F17 : /platform/defense-meteorological-satellite-program-f-17
ENVISAT : /platform/environmental-satellite
ERS-1 : /platform/european-remote-sensing-satellite-1
ERS-2 : /platform/european-remote-sensing-satellite-2
GOES-7 : /platform/geostationary-operational-environmental-satellite-7
ICESAT : /platform/ice-cloud-and-land-elevation-satellite
LANDSAT-5 : /platform/landsat-5
LANDSAT-7 : /platform/landsat-7
NIMBUS-3 : /platform/nimbus-3
NIMBUS-4 : /platform/nimbus-4
NIMBUS-5 : /platform/nimbus-5
NIMBUS-6 : /platform/nimbus-6
NIMBUS-7 : /platform/nimbus-7
NOAA-4 : /platform/national-oceanic-and-atmospheric-administration-4
NOAA-6 : /platform/national-oceanic-and-atmospheric-administration-6
NOAA-7 : /platform/national-oceanic-and-atmospheric-administration-7
NOAA-8 : /platform/national-oceanic-and-atmospheric-administration-8
NOAA-9 : /platform/national-oceanic-and-atmospheric-administration-9
NOAA-10 : /platform/national-oceanic-and-atmospheric-administration-10
NOAA-11 : /platform/national-oceanic-and-atmospheric-administration-11
NOAA-12 : /platform/national-oceanic-and-atmospheric-administration-12
NOAA-13 : /platform/national-oceanic-and-atmospheric-administration-13
NOAA-14 : /platform/national-oceanic-and-atmospheric-administration-14
NOAA-15 : /platform/national-oceanic-and-atmospheric-administration-15
NOAA-16 : /platform/national-oceanic-and-atmospheric-administration-16
NOAA-17 : /platform/national-oceanic-and-atmospheric-administration-17
RADARSAT-1 : /platform/radarsat-1
RAPIDEYE : /platform/rapideye
SPOT-1 : /platform/satellite-pour-lobservation-de-la-terre-1
SPOT-2 : /platform/satellite-pour-lobservation-de-la-terre-2
SPOT-3 : /platform/satellite-pour-lobservation-de-la-terre-3
SPOT-4 : /platform/satellite-pour-lobservation-de-la-terre-4
SPOT-5 : /platform/satellite-pour-lobservation-de-la-terre-5
TERRA : /platform/terra
TSX : /platform/terrasar-x
