use strict;
use warnings;

BEGIN { $| = 1;
	use Test::More;
	plan tests => 12;
}


use Bio::EnsEMBL::Test::TestUtils;
use Bio::EnsEMBL::Variation::PopulationGenotype;
use Bio::EnsEMBL::Variation::Variation;
use Bio::EnsEMBL::Variation::Population;


# test constructor
my $pop = Bio::EnsEMBL::Variation::Population->new
  (-name => 'test population',
   -description => 'This is a test individual',
   -size => 10000);

my $var = Bio::EnsEMBL::Variation::Variation->new
  (-name => 'rs123',
   -synonyms => {'dbSNP' => ['ss12', 'ss144']},
   -source => 'dbSNP');


my $geno  = ['A','C'];
my $ambig = 'M';
my $ss = 1234;
my $dbID = 1;

my $freq = 0.76;

my $pop_gtype = Bio::EnsEMBL::Variation::PopulationGenotype->new
  (-dbID => $dbID,
   -genotype => $geno,
   -variation => $var,
   -population => $pop,
   -frequency => $freq,
   -subsnp => $ss);


ok($pop_gtype->population()->name() eq $pop->name(), "population name" );
ok($pop_gtype->variation()->name()  eq $var->name(), "variation name");
ok($pop_gtype->genotype() eq $geno, "genotype" );
ok($pop_gtype->subsnp() eq "ss$ss", "ssubsnp_id");

ok($pop_gtype->dbID() == $dbID, "dbSNP ID") ;

ok($pop_gtype->frequency() == $freq, "frequency");

ok($pop_gtype->allele(1) eq 'A', "allele 1");
ok($pop_gtype->allele(2) eq 'C', "allele 2");
ok($pop_gtype->ambiguity_code() eq $ambig, "ambiguity code");

my $pop2 = Bio::EnsEMBL::Variation::Population->new
  (-name => 'test population 2',
   -description => 'This is a second test population',
   -size => 1000000);

my $var2 = Bio::EnsEMBL::Variation::Variation->new
  (-name => 'rs332',
   -synonyms => {'dbSNP' => ['ss44', 'ss890']},
   -source => 'dbSNP');

ok(test_getter_setter($pop_gtype, 'population', $pop2));
ok(test_getter_setter($pop_gtype, 'variation', $var2));

ok(test_getter_setter($pop_gtype, 'frequency', $freq));


done_testing();
