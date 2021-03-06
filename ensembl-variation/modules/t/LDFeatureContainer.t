use lib 't';

use strict;
use warnings;

BEGIN { $| = 1;
	use Test;
	plan tests => 12;
}

use Bio::EnsEMBL::Test::TestUtils;
use Data::Dumper;

use Bio::EnsEMBL::Variation::LDFeatureContainer;
use Bio::EnsEMBL::Variation::VariationFeature;
use Bio::EnsEMBL::Variation::Variation;

our $verbose = 0;

#test constructor
my $v1 = Bio::EnsEMBL::Variation::Variation->new(-name => 'rs193',
                                                -source => 'dbSNP');
my $v2 = Bio::EnsEMBL::Variation::Variation->new(-name => 'rs203',
                                                -source => 'dbSNP');
my $v3 = Bio::EnsEMBL::Variation::Variation->new(-name => 'rs848',
                                                -source => 'dbSNP');
my $v4 = Bio::EnsEMBL::Variation::Variation->new(-name => 'rs847',
                                                -source => 'dbSNP');


my $vf1 = Bio::EnsEMBL::Variation::VariationFeature->new(-dbID => 153,
							 -start => 27686081,
							 -end => 27686081,
							 -strand => 1,
							 -variation_name => 'rs193',
							 -map_weight => 1,
							 -allele_string => 'C/T',
							 -variation => $v1
							 );

my $vf2 = Bio::EnsEMBL::Variation::VariationFeature->new(-dbID => 163,
							 -start => 27689871,
							 -end => 27689871,
							 -strand => 1,
							 -variation_name => 'rs203',
							 -map_weight => 1,
							 -allele_string => 'T/C',
							 -variation => $v2
							 );

my $vf3 = Bio::EnsEMBL::Variation::VariationFeature->new(-dbID => 749,
							 -start => 132072716,
							 -end => 132072716,
							 -strand => -1,
							 -variation_name => 'rs848',
							 -map_weight => 1,
							 -allele_string => 'T/G',
							 -variation => $v3
							 );

my $vf4 = Bio::EnsEMBL::Variation::VariationFeature->new(-dbID => 748,
							 -start => 132072885,
							 -end => 132072885,
							 -strand => -1,
							 -variation_name => 'rs847',
							 -map_weight => 1,
							 -allele_string => 'A/G',
							 -variation => $v4
							 );

my $ldContainer = Bio::EnsEMBL::Variation::LDFeatureContainer->new('-name' => 'container_1',
								   '-ldContainer' =>{ 
								       '153-163' =>{ 
									   51 =>
									   { 'd_prime'             => 0.533013,
									     'r2'                 => 0.258275,
									     'snp_distance_count' => 1,
									     'sample_count'       => 42
									     },
									     140 =>
									 { 'd_prime'             => 0.999887,
									   'r2'                 => 0.642712,
									   'snp_distance_count' => 1,
									   'sample_count'       => 10
									   }
								       },
								       '749-748' => { 140 =>
										      { 'd_prime'             => 0.999924,
											'r2'                 => 0.312452,
											'snp_distance_count' => 1,
											'sample_count'       => 22
											}
										  }
								   },
								   '-variationFeatures' =>{ 153 => $vf1,
											    163 => $vf2,
											    749 => $vf3,
											    748 => $vf4
											    }
							    );

ok($ldContainer->name()  eq 'container_1');

print_container($ldContainer);

# test getter_setter

ok(test_getter_setter($ldContainer,'name','container_new_name'));


#test methods
my $variations = $ldContainer->get_variations();
ok(@{$variations} == 4);

#to check how to get the r_square value for 2 variation_features with a known and an unknown population
my $r_square;
$r_square = $ldContainer->get_r_square($vf1,$vf2,51);
ok($r_square == 0.258275);

$r_square = $ldContainer->get_r_square($vf1,$vf2);
ok($r_square == 0.642712);


#to check how to get the d_prime value for 2 variation_features with a known and an unknown population
my $d_prime;
$d_prime = $ldContainer->get_d_prime($vf3,$vf4,140);
ok($d_prime == 0.999924);

$d_prime = $ldContainer->get_d_prime($vf1,$vf2);
ok($d_prime == 0.999887);

#check method to get ALL ld values in container (d_prime, r2, snp_distance_count and sample_count
my $ld_values;
$ld_values = $ldContainer->get_all_ld_values();
ok(@{$ld_values} == 2);
my $r_squares = $ldContainer->get_all_r_square_values();
ok(@{$r_squares} == 2);
my $d_primes = $ldContainer->get_all_d_prime_values();
ok(@{$d_primes} == 2);

#check method to retrieve populations in a container
my $populations = $ldContainer->get_all_populations();
ok(@{$populations} == 2);
$populations = $ldContainer->get_all_populations($vf3,$vf4);
ok($populations->[0] == 140);

sub print_container {
  my $container = shift;
  return if(!$verbose);
 
  print STDERR "\nContainer name: ", $container->{'name'},"\n";
  foreach my $key (keys %{$container->{'ldContainer'}}) {
      my ($key1,$key2) = split /-/,$key;
      print STDERR "LD values for ", $container->{'variationFeatures'}->{$key1}->variation_name, " and ",$container->{'variationFeatures'}->{$key2}->variation_name;
      foreach my $population (keys %{$container->{'ldContainer'}->{$key}}){
	  print STDERR " in population $population:\n d_prime - ",$container->{'ldContainer'}->{$key}->{$population}->{'d_prime'}, "\n r2: ", $container->{'ldContainer'}->{$key}->{$population}->{'r2'}, "\n snp_distance: ",$container->{'ldContainer'}->{$key}->{$population}->{'snp_distance_count'}, " \nsample count ",$container->{'ldContainer'}->{$key}->{$population}->{'sample_count'},"\n";
      }
  }

}
