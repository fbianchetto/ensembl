use strict;
use warnings;

use Test::More;


use Bio::EnsEMBL::Test::TestUtils;
use Bio::EnsEMBL::Variation::Study;


my $name                = 'studyname';
my $description         = 'longer study description';
my $url                 = 'http://www.ensembl.org/';
my $external_reference  = 'pubmed/22566624';
my $type                = 'GWAS';
my $source              = 'EGA';



# test constructor
my $study = Bio::EnsEMBL::Variation::Study->new
  (-name               => $name,
   -description        => $description,
   -url                => $url,
   -external_reference => $external_reference, 
   -type               => $type,
   -source             => $source
);


ok($study->name() eq $name, "name");
ok($study->description() eq $description, "$description");
ok($study->url() eq $url, "url");
ok($study->external_reference() eq $external_reference, "reference");
ok($study->type() eq $type, "type");
ok($study->source() eq $source, "source");


# test getter/setters


ok(test_getter_setter($study, 'name', 'new name'), "get/set name");
ok(test_getter_setter($study, 'description', 'new description'), "get/set description");
ok(test_getter_setter($study, 'url', 'http://www.ebi.ac.uk/ega'), "get/set url");


done_testing();
