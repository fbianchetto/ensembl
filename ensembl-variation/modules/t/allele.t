use strict;
use warnings;

BEGIN { $| = 1;
	use Test;
	plan tests => 12;
}

use FindBin qw($Bin);

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Test::TestUtils;
use Bio::EnsEMBL::Variation::Allele;
use Bio::EnsEMBL::Variation::Population;
use Bio::EnsEMBL::Variation::DBSQL::DBAdaptor;

## adaptor needed as availablity checked in Allele.pm
my $reg = 'Bio::EnsEMBL::Registry';
$reg->no_version_check(1); ## version not relevant for test db
$reg->load_all("$Bin/test.ensembl.registry");
my $allele_adaptor    = $reg->get_adaptor('mus_musculus', 'variation', 'allele');


# test constructor

my $dbID = 1;
my $allele = 'A';
my $frequency = 0.86;
my $p = Bio::EnsEMBL::Variation::Population->new();
my $subsnp = 12345;
my $count = 20;

my $al = Bio::EnsEMBL::Variation::Allele->new
  (-dbID       => $dbID,
   -allele     => $allele,
   -frequency  => $frequency,
   -population => $p,
   -subsnp     => $subsnp,
   -count      => $count,
   -adaptor    => $allele_adaptor);

ok($al->dbID() == $dbID);
ok($al->frequency() == $frequency);
ok($al->population() == $p);
ok($al->allele() eq $allele);
ok($al->subsnp() eq "ss$subsnp");
ok($al->count() eq $count);

# test getter/setters

my $p2 = Bio::EnsEMBL::Variation::Population->new();

ok(test_getter_setter($al, 'dbID', 123));
ok(test_getter_setter($al, 'allele', 'T'));
ok(test_getter_setter($al, 'frequency', 0.86));
ok(test_getter_setter($al, 'population', $p2));
ok(test_getter_setter($al, 'subsnp_handle','TSC'));


$al->frequency_subsnp_handle($p, 'HapMap');
ok($al->frequency_subsnp_handle($p) eq 'HapMap');
