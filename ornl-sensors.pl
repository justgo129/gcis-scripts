#!/usr/bin/env perl
use utf8;
use v5.20;

use Gcis::Client;

my $c = Gcis::Client->connect(url => shift || 'http://localhost:3000');

while (<DATA>) {
    chomp;
    my ($term,$gcid) = split /\s*:\s*/;
    say qq['$term' '$gcid' ];
    $c->post("/lexicon/ornl/term/new", {
            term => $term,
            gcid => $gcid,
            context => 'Sensor',
        }) or die $c->error;
}

__DATA__
ALI : /instrument/advanced-land-imager
AMI-SAR : /instrument/radar-altimeter-3
ASTER : /instrument/advanced-spaceborne-thermal-emission-and-reflection-radiometer
ATSR (ALONG TRACK SCANNING RADIOMETER AND MICROWAVE SOUNDER) : /instrument/along-track-scanning-radiometer-2
ATSR : /instrument/along-track-scanning-radiometer-2
AVHRR (ADVANCED VERY HIGH RESOLUTION RADIOMETER) : /instrument/advanced-very-high-resolution-radiometer-2
AVHRR : /instrument/advanced-very-high-resolution-radiometer-2
ETM+ (ENHANCED THEMATIC MAPPER PLUS) : /instrument/thematic-mapper
GLAS (GEOSCIENCE LASER ALTIMETER SYSTEM) : /instrument/geoscience-laser-altimeter-system
GOES-8 IMAGER : /instrument/imager
GOES-8 SOUNDER : /instrument/sounder
GOES I-M IMAGER : /instrument/imager
HRVIR : /instrument/high-resolution-visible-and-infra-red
HYPERION (HYPERSPECTRAL IMAGER) : /instrument/hyperspectral-imager-2
HYPERION  : /instrument/hyperspectral-imager-2
IMAGING RADIOMETERS : /instrument/vegetation
INFRARED RADIOMETER : /instrument/meteosat-visible-and-infra-red-imager
JERS-1 SAR : /instrument/l-band-synthetic-apature-radar
LANDSAT ETM+ : /instrument/enhanced-thematic-mapper-plus
LANDSAT MSS : /instrument/multispectral-scanner
LANDSAT TM (LANDSAT THEMATIC MAPPER) : /instrument/thematic-mapper
LANDSAT TM  : /instrument/thematic-mapper
MISR : /instrument/multi-angle-imaging-spectroradiometer
MODIS (MODERATE-RESOLUTION IMAGING SPECTRORADIOMETER) : /instrument/moderate-resolution-imaging-spectroradiometer
MODIS  : /instrument/moderate-resolution-imaging-spectroradiometer
MOPITT : /instrument/measurements-of-pollution-in-the-troposphere
MSS (MULTISPECTRAL SCANNER)  : /instrument/multispectral-scanner
PR : /instrument/precipitation-radar
SAR (SYNTHETIC APERTURE RADAR) : /instrument/l-band-synthetic-apature-radar
SPECTRORADIOMETER : /instrument/leisa-atmospheric-corrector
SPOT MULTISPECTRAL : /instrument/high-resolution-visible
SSM/I : /instrument/special-sensor-microwave-imager
TMI : /instrument/trmm-microwave-imager
TM : /instrument/thematic-mapper
TOMS : /instrument/total-ozone-mapping-spectrometer
TOMS (TOTAL OZONE MAPPING SPECTROMETER) : /instrument/total-ozone-mapping-spectrometer
TOVS-HIRS/2 : /instrument/high-resolution-infra-red-sounder-2
TOVS-MSU : /instrument/tiros-operational-vertical-sounder
TOVS-SSU : /instrument/tiros-operational-vertical-sounder
VAS : /instrument/vissr-atmospheric-sounder
VIRS : /instrument/visible-infra-red-scanner
VISSR : /instrument/vissr-atmospheric-sounder
