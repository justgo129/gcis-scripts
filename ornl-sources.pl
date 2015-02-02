#!/usr/bin/env perl
use utf8;
use v5.20;
#use open qw/:std :utf8/;
#binmode(DATA,':utf8');

use Gcis::Client;

my $c = Gcis::Client->connect(url => shift || 'http://localhost:3000');

while (<DATA>) {
    chomp;
    my ($term,$gcid) = split /\s+:\s+/;
    say qq['$term' '$gcid' ];
    $c->post("/lexicon/ornl/term/new", {
            term => $term,
            gcid => $gcid,
            context => 'Source',
        }) or die $c->error;
}

__DATA__
AQUA : /platform/aqua
AQUA (AFTERNOON EQUATORIAL CROSSING TIME SATELLITE) : /platform/aqua
ÂTERRA (MORNING EQUATORIAL CROSSING TIME SATELLITE) : /platform/terra
DMSP-F10 : /platform/defense-meteorological-satellite-program-f-10
DMSP-F11 : /platform/defense-meteorological-satellite-program-f-11
DMSP-F13 : /platform/defense-meteorological-satellite-program-f-13
DMSP-F14 : /platform/defense-meteorological-satellite-program-f-14
EO-1 (EARTH OBSERVING 1) : /platform/new-millenium-program-earth-observing-1
EP-TOMS : /platform/total-ozone-mapping-spectometer-earth-probe
ERS-1 : /platform/european-remote-sensing-satellite-1
ERS-2 : /platform/european-remote-sensing-satellite-2
ERS-2 (EUROPEAN REMOTE SENSING SATELLITE-2) : /platform/european-remote-sensing-satellite-2
GOES-12 (AQUA/TERRA) : /platform/geostationary-operational-environmental-satellite-12
GOES-12 (GEOSTATIONARY OPERATIONAL ENVIRONMENTAL SATELLITE-12) : /platform/geostationary-operational-environmental-satellite-12
GOES-7 : /platform/geostationary-operational-environmental-satellite-7
GOES-8 : /platform/geostationary-operational-environmental-satellite-8
GOES-8 (GEOSTATIONARY OPERATIONAL ENVIRONMENTAL SATELLITE-8) : /platform/geostationary-operational-environmental-satellite-8
ICESAT : /platform/ice-cloud-and-land-elevation-satellite
JERS-1 : /platform/japanese-earth-resource-satellite
JERS-1 (JAPANESE EARTH RESOURCES SATELLITE-1) : /platform/japanese-earth-resource-satellite
LANDSAT-1 : /platform/landsat-1
LANDSAT-2 : /platform/landsat-2
LANDSAT-2 (LAND REMOTE-SENSING SATELLITE-2) : /platform/landsat-2
LANDSAT-3 : /platform/landsat-3
LANDSAT-4 : /platform/landsat-4
LANDSAT-4 (LAND REMOTE-SENSING SATELLITE-4) : /platform/landsat-4
LANDSAT-5 : /platform/landsat-5
LANDSAT-5 (LAND REMOTE-SENSING SATELLITE-5) : /platform/landsat-5
LANDSAT-7 : /platform/landsat-7
LANDSAT-7 (LAND REMOTE-SENSING SATELLITE-7) : /platform/landsat-7
METEOSAT-4 : /platform/meteosat-4
METEOSAT-5 : /platform/meteosat-5
METEOSAT-6 : /platform/meteosat-6
METEOSAT-7 : /platform/meteosat-7
NIMBUS-7 : /platform/nimbus-7
NMP/EO-1 : /platform/new-millenium-program-earth-observing-1
NOAA-10 : /platform/national-oceanic-and-atmospheric-administration-10
NOAA-10 (NATIONAL OCEANIC &amp; ATMOSPHERIC ADMINISTRATION-10) : /platform/national-oceanic-and-atmospheric-administration-10
NOAA-11 : /platform/national-oceanic-and-atmospheric-administration-11
NOAA-12 : /platform/national-oceanic-and-atmospheric-administration-12
NOAA-12 (NATIONAL OCEANIC &amp; ATMOSPHERIC ADMINISTRATION-12) : /platform/national-oceanic-and-atmospheric-administration-12
NOAA-14 : /platform/national-oceanic-and-atmospheric-administration-14
NOAA-14 (NATIONAL OCEANIC &amp; ATMOSPHERIC ADMINISTRATION-14) : /platform/national-oceanic-and-atmospheric-administration-14
NOAA-7 : /platform/national-oceanic-and-atmospheric-administration-7
NOAA-9 : /platform/national-oceanic-and-atmospheric-administration-9
RADARSAT-1 : /platform/radarsat-1
SPOT-1 : /platform/satellite-pour-lobservation-de-la-terre-1
SPOT-4 : /platform/satellite-pour-lobservation-de-la-terre-4
SPOT-4 (SYSTEME PROBATOIRE POUR L'OBSERVATION DE LA TERRE-4) : /platform/satellite-pour-lobservation-de-la-terre-4
TERRA : /platform/terra
TERRA (MORNING EQUATORIAL CROSSING TIME SATELLITE) : /platform/terra
TRMM : /platform/tropical-rainfall-measuring-mission
