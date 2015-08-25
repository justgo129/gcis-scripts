#!/usr/bin/env perl
use utf8;
use v5.20;

use Gcis::Client;
use Data::Dumper;

my $url = 'http://localhost:3000';

my $c = Gcis::Client->connect(url => shift || $url);
my $context = 'Agency';

while (<DATA>) {
    chomp;
    my ($term,$gcid) = split /\s*:\s*/;
    say qq['$term' '$gcid' ];
    if (my $e = $c->get("/lexicon/govman/$context/$term")) {
        if ($e->{uri} eq $gcid) {
            say "   already exists";
        } else {
            say "   new uri different - new : '$gcid'  existing : '$e->{uri}'";
        }
        next;
    }
    $c->post("/lexicon/govman/term/new", {
            term => $term,
            gcid => $gcid,
            context => $context,
        }) or die $c->error;
}

__DATA__
ARS : /organization/agricultural-research-service
BEA : /organization/bureau-economic-analysis
BLM : /organization/us-bureau-land-management
BOR : /organization/us-bureau-reclamation
CBO : /organization/congressional-budget-office
CDC : /organization/centers-disease-control-and-prevention
COE : /organization/us-army-corps-engineers
DHS : /organization/us-department-homeland-security
DOC : /organization/us-department-commerce
DOD : /organization/us-department-defense
DOE : /organization/us-department-energy
DOI : /organization/us-department-interior
DOS : /organization/us-department-state
DOT : /organization/us-department-transportation
EAB : /organization/bureau-economic-analysis
ECSA : /organization/economics-statistics-administration
ED : /organization/us-department-education
EIA : /organization/us-energy-information-administration
EOP : /organization/us-executive-office-president
EPA : /organization/us-environmental-protection-agency
ERS : /organization/economic-research-service
FAA : /organization/federal-aviation-administration
FDA : /organization/us-food-drug-administration
FEMA : /organization/federal-emergency-management-agency
FERC : /organization/federal-energy-regulatory-commission
FHWA : /organization/federal-highway-administration
FMCSA : /organization/federal-motor-carrier-safety-administration
FNS : /organization/food-nutrition-service
FS : /organization/us-forest-service
FTA : /organization/federal-transit-administration
FWS : /organization/us-fish-wildlife-service
GAO : /organization/us-government-accountability-office
HHS : /organization/us-department-health-human-services
ITA : /organization/international-trade-administration
NASA : /organization/national-aeronautics-space-administration
NASS : /organization/national-agricultural-statistics-service
NOAA : /organization/national-oceanic-atmospheric-administration
NPS : /organization/national-park-service
NRCS : /organization/natural-resources-conservation-service
NSF : /organization/national-science-foundation
ODNI : /organization/us-office-director-national-intelligence
OMB : /organization/office-management-budget
OSTP : /organization/office-science-technology-policy
RITA : /organization/us-department-transportation-research-innovative-technology-administration
RMA : /organization/united-states-department-agriculture-risk-management-agency
USA : /organization/us-army
USAF : /organization/us-air-force
USAID : /organization/us-agency-international-development
USBC : /organization/us-census-bureau
USCG : /organization/us-coast-guard
USDA : /organization/us-department-agriculture
USGS : /organization/us-geological-survey
USN : /organization/us-navy
WAPA : /organization/western-area-power-administration
