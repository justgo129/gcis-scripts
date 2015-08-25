#!/usr/bin/env perl
use utf8;
use v5.20;

use Gcis::Client;

my $url = 'http://localhost:3000';

my $c = Gcis::Client->connect(url => shift || $url);
my $context = 'agencyName';

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
Agricultural Research Service : /organization/agricultural-research-service
Bureau of Economic Analysis : /organization/bureau-economic-analysis
Bureau of Land Management : /organization/us-bureau-land-management
Bureau of Reclamation : /organization/us-bureau-reclamation
Congressional Budget Office : /organization/congressional-budget-office
Centers for Disease Control and Prevention : /organization/centers-disease-control-and-prevention
Corps of Engineers : /organization/us-army-corps-engineers
Department of Homeland Security : /organization/us-department-homeland-security
Department of Commerce : /organization/us-department-commerce
Department of Defense : /organization/us-department-defense
Department of Energy : /organization/us-department-energy
Department of the Interior : /organization/us-department-interior
Department of State : /organization/us-department-state
Department of Transportation : /organization/us-department-transportation
Bureau of Economic Analysis : /organization/bureau-economic-analysis
Economics and Statistics Administration : /organization/economics-statistics-administration
Department of Education : /organization/us-department-education
Energy Information Administration : /organization/us-energy-information-administration
Executive Office of the President : /organization/us-executive-office-president
Environmental Protection Agency : /organization/us-environmental-protection-agency
Economic Research Service : /organization/economic-research-service
Federal Aviation Administration : /organization/federal-aviation-administration
Food and Drug Administration : /organization/us-food-drug-administration
Federal Emergency Management Agency : /organization/federal-emergency-management-agency
Federal Energy Regulatory Commission : /organization/federal-energy-regulatory-commission
Federal Highway Administration : /organization/federal-highway-administration
Federal Motor Carrier Safety Administration : /organization/federal-motor-carrier-safety-administration
Food and Nutrition Service : /organization/food-nutrition-service
Forest Service : /organization/us-forest-service
Federal Transit Administration : /organization/federal-transit-administration
Fish and Wildlife Service : /organization/us-fish-wildlife-service
U.S. Government Accountability Office : /organization/us-government-accountability-office
Department of Health and Human Services : /organization/us-department-health-human-services
International Trade Administration : /organization/international-trade-administration
National Aeronautics and Space Administration : /organization/national-aeronautics-space-administration
National Agricultural Statistics Service : /organization/national-agricultural-statistics-service
National Oceanic and Atmospheric Administration : /organization/national-oceanic-atmospheric-administration
National Park Service : /organization/national-park-service
Natural Resources Conservation Service : /organization/natural-resources-conservation-service
National Science Foundation : /organization/national-science-foundation
Office of the Director of National Intelligence : /organization/us-office-director-national-intelligence
Office of Management and Budget : /organization/office-management-budget
Office of Science and Technology Policy : /organization/office-science-technology-policy
Research and Innovative Technology Administration : /organization/us-department-transportation-research-innovative-technology-administration
Risk Management Agency : /organization/united-states-department-agriculture-risk-management-agency
Army Department : /organization/us-army
Air Force Department : /organization/us-air-force
United States Agency for International Development : /organization/us-agency-international-development
Bureau of the Census : /organization/us-census-bureau
Coast Guard : /organization/us-coast-guard
Department of Agriculture : /organization/us-department-agriculture
U.S. Geological Service : /organization/us-geological-survey
Navy Department : /organization/us-navy
Western Area Power Administration : /organization/western-area-power-administration
