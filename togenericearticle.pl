#!/usr/bin/env perl

# This creates a generic publication for the references having reftypes which do not exist in our data model.
# The generic publication is subequently associated with the reference.

use v5.14;
use Gcis::Client;
use Data::Dumper;
use Getopt::Long;
use Pod::Usage;
use strict;
binmode(STDOUT, ":utf8");

my %types = (
    marticle => 'Magazine Article',
    narticle => 'Newspaper Article',
    earticle => 'Electronic Article',
    cpaper   => 'Conference Paper',
    cproc    => 'Conference Proceedings',
    thesis   => 'Thesis',
    film     => 'Film or Broadcast',
);

$| = 1;
my $type = "cproc";
my $url   = "https://data-stage.globalchange.gov";
my $max_update = 100;
my $dry_run = 0;
my $help = 0;
 my $result = GetOptions ("type=s" => \$type, 
                    "url=s" => \$url,
                    "max_update=i"   => \$max_update,
                    "dry_run"  => \$dry_run,
                    'help|?' => \$help);

pod2usage(-verbose => 2) if $help;
 if (!grep $type eq $_, keys %types) {
     say "invalid type : $type";
     pod2usage(-verbose => 2);
 }

say " type : $type, $types{$type}";
print " url $url\n";
say " max update : $max_update";
say " dry run" if $dry_run;

my $all = "?all=1";
# my $all;
my $ref_search = "/reference.json$all";

my $search = $url.$ref_search;
say " search : $search";
my $g = $dry_run ? Gcis::Client->new(    url => $url)
                 : Gcis::Client->connect(url => $url);
my $refs = $g->get($ref_search);
my $n = @$refs;
say " n refs : $n";
my $n_update = 0;
my $i=0;
for (@$refs) {
    next if $_->{attrs}->{reftype} ne $types{$type};
    next if $_->{child_publication_id};
    $n_update++;
    last if $n_update > $max_update;

     my $generic_pub = {};
     my $sub = \&{$type."_copy"};
     $sub->($_, $generic_pub);

     say "updating title : $_->{attrs}->{Title}, uri : $_->{uri}";
    
    if ($dry_run) {
        say "would have updated this reference";
        next;
    }

    my $new_pub = $g->post("/generic", $generic_pub) or error $g->error;
    my $ref_form = $g->get("/reference/form/update/$_->{identifier}");
    $ref_form->{child_publication_uri} = $new_pub->{uri};
    $ref_form->{publication_uri} = $g->get($ref_form->{publication_uri})->{uri};
    delete $ref_form->{sub_publication_uris};

    $g->post("/reference/$_->{identifier}", $ref_form) or die $g->error;  
  
}

# sub marticle_copy {
 #    my ($ref, $pub) = @_;
  #   for (qw(reftype Magazine ISSN Author Date Title Pages Volume Publisher Year URL)) {
   #      $pub->{attrs}->{$_} = $ref->{attrs}->{$_};
    # }

     # $pub->{attrs}->{Issue} = $ref->{attrs}->{'Issue Number'};
     # $pub->{attrs}->{'Place Published'} = $ref->{attrs}->{'Place Published'};
     # return;
 # }

 # sub narticle_copy {
   #  my ($ref, $pub) = @_;
    # for (qw(reftype Newspaper Title Pages Year URL)) {
     #    $pub->{attrs}->{$_} = $ref->{attrs}->{$_};
     # }

     # $pub->{attrs}->{Date} = $ref->{attrs}->{'Issue Date'};
     # $pub->{attrs}->{Author} = $ref->{attrs}->{'Reporter'};
     # $pub->{attrs}->{'Place Published'} = $ref->{attrs}->{'Place Published'};
     # return;
 # }

 sub earticle_copy {
     my ($ref, $pub) = @_;
     for (qw(reftype Author Year Title Publisher Issue URL)) {
         $pub->{attrs}->{$_} = $ref->{attrs}->{$_};
     }

     $pub->{attrs}->{'Periodical Title'} = $ref->{attrs}->{'Periodical Title'}; 
     $pub->{attrs}->{'Place Published'} = $ref->{attrs}->{'Place Published'}; 
     $pub->{attrs}->{'E-Pub Date'} = $ref->{attrs}->{'E-Pub Date'};
     return;
  }

 # sub cpaper_copy {
   #  my ($ref, $pub) = @_;
   #  for (qw(reftype Author Date Year Title DOI URL)) {
    #     $pub->{attrs}->{$_} = $ref->{attrs}->{$_};
    # }

    # $pub->{attrs}->{'Conference Name'} = $ref->{attrs}->{'Conference Name'};
    # $pub->{attrs}->{'Conference Location'} = $ref->{attrs}->{'Conference Location'};
    # return;
  # }

 # sub cproc_copy {
   #  my ($ref, $pub) = @_;
    # for (qw(reftype Author Title Date DOI URL)) {
     #    $pub->{attrs}->{$_} = $ref->{attrs}->{$_};
     # }

     # $pub->{attrs}->{'Year of Conference'} = $ref->{attrs}->{'Year of Conference'};
     # $pub->{attrs}->{'Conference Name'} = $ref->{attrs}->{'Conference Name'};
     # $pub->{attrs}->{'Conference Location'} = $ref->{attrs}->{'Conference Location'};
     # return;
  # }

 # sub thesis_copy {
  #   my ($ref, $pub) = @_;
   #  for (qw(reftype Author Date University Year Title DOI URL)) {
    #     $pub->{attrs}->{$_} = $ref->{attrs}->{$_};
    # }

    # $pub->{attrs}->{'Academic Department'} = $ref->{attrs}->{'Academic Department'};
    # $pub->{attrs}->{'Number of Pages'} = $ref->{attrs}->{'Number of Pages'};
    # return;
  # }

#  sub film_copy {
 #    my ($ref, $pub) = @_;
  #   for (qw(reftype Director Year Title Producer URL)) {
   #      $pub->{attrs}->{$_} = $ref->{attrs}->{$_};
   #  }

   #  $pub->{attrs}->{'Series Title'} = $ref->{attrs}->{'Series Title'};
   #  $pub->{attrs}->{'Date Released'} = $ref->{attrs}->{'Date Released'};
   #  return;
 # }

say "done";

__END__

=head1 NAME

to-generic - creates child pubs of class "generic" for non-standard reference types, associates them with reference

=head1 SYNOPSIS

togeneric [options]

  Options:
    -type refers to the type of reference to be updated.
    -url refers to the URL of the GCIS instance.
    -max_update is the maximum number of entries to update. 
    -dry_run is a flag that indicates a dry run.
    -help provides a brief help message.

=head1 OPTIONS

=over 8

=item B<-type>

the type of reference to be updated (default is cproc)

the allowed values are:

    marticle : Magazine Article
    narticle : Newspaper Article
    earticle : Electronic Article
    cpaper   : Conference Paper
    cproc    : Conference Proceedings
    thesis   : Thesis
    film     : Film or Broadcast

=item B<-url>

the URL of the GCIS instance (default is the dev instance)

=item B<-max_update>

the maximum number of entries to update (default is 1 entry)

=item B<-dry_run>

a flag that indicates a dry run (default is to update the instance)

=item B<-help>

prints a help message and exits

=back

=head1 DESCRIPTION

B<togeneric.pl> creates child publications of class 'generic' for reference types of
nonstandard reference type classes.  The child pubs are subsequently associcated with these
references.  The program is designed to allow users to select how many new child pubs to
create, and displays the title and UUID pertaining to each new child pub entry generated.

=cut
