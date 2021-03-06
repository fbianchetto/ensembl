use strict;

=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/legal/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk.org>.

=cut

use warnings;

use POSIX;
use Getopt::Long;
use ImportUtils qw(dumpSQL load create_and_load debug);
use Bio::EnsEMBL::Utils::Exception qw(warning throw verbose);
use Bio::EnsEMBL::Utils::Sequence qw(reverse_comp);
use DBI qw(:sql_types);
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use FindBin qw( $Bin );
use Data::Dumper;

my ($TMP_DIR, $TMP_FILE);

my ($species,$registry_file);

GetOptions(
  'tmpdir=s'  => \$ImportUtils::TMP_DIR,
  'tmpfile=s' => \$ImportUtils::TMP_FILE,
	'species=s' => \$species,
  'registry_file=s' => \$registry_file,
);

usage('-species argument required') if(!$species);

warn("Make sure you have an updated ensembl.registry file!\n");

$registry_file ||= $Bin . "./ensembl.registry";

Bio::EnsEMBL::Registry->load_all( $registry_file );

my $cdba = Bio::EnsEMBL::Registry->get_DBAdaptor($species,'core')
    || usage( "Cannot find core db for $species in $registry_file" );
my $vdba = Bio::EnsEMBL::Registry->get_DBAdaptor($species,'variation')
    || usage( "Cannot find variation db for $species in $registry_file" );


my $dbVar = $vdba->dbc->db_handle;
my $dbCore = $cdba;


my $table = "flanking_sequence";

debug("Processing flanking_sequence reverse strand");


$dbVar->do(qq{CREATE TABLE flanking_sequence_before_re LIKE $table});
$dbVar->do(qq{INSERT INTO flanking_sequence_before_re SELECT * FROM $table});

my ($variation_id,$up_seq,$down_seq,$up_seq_start,$up_seq_end,$down_seq_start,$down_seq_end,$seq_region_id,$seq_region_strand);

my $sth=$dbVar->prepare(qq{
	 SELECT fl.* FROM $table fl, variation_to_reverse vtr
	 WHERE fl.variation_id = vtr.variation_id
});
$sth->execute();
$sth->bind_columns(\$variation_id,\$up_seq,\$down_seq,\$up_seq_start,\$up_seq_end,\$down_seq_start,\$down_seq_end,\$seq_region_id,\$seq_region_strand);

while($sth->fetch()) {
	#print "$variation_id,$up_seq,$down_seq,$up_seq_start,$up_seq_end,$down_seq_start,$down_seq_end,$seq_region_id,$seq_region_strand\n";
	
	if ($up_seq and $down_seq) {
		($up_seq, $down_seq) = ($down_seq, $up_seq);
		reverse_comp(\$up_seq);
		reverse_comp(\$down_seq);
		$up_seq_start = $up_seq_end = $down_seq_start = $down_seq_end = '\N';
	}
	elsif (! $up_seq and ! $down_seq) {
		my $tmp_seq_start = $up_seq_start;
		my $tmp_seq_end = $up_seq_end;
		($up_seq_start, $up_seq_end) = ($down_seq_start, $down_seq_end);
		($down_seq_start, $down_seq_end) = ($tmp_seq_start, $tmp_seq_end);
		$up_seq = $down_seq = '\N';
	}
	elsif ($up_seq and ! $down_seq) {
		$down_seq = $up_seq;
		reverse_comp(\$down_seq);
		$up_seq = '\N';
		($up_seq_start, $up_seq_end) = ($down_seq_start, $down_seq_end);
		$down_seq_start = '\N';
		$down_seq_end = '\N';
	}
	elsif (! $up_seq and $down_seq) {
		$up_seq = $down_seq;
		reverse_comp(\$up_seq);
		$down_seq = '\N';
		($down_seq_start, $down_seq_end) = ($up_seq_start, $up_seq_end);
		$up_seq_start = '\N';
		$up_seq_end = '\N';
	}
	$seq_region_strand = 1;
	  
	$dbVar->do(qq{UPDATE $table 
	                 SET up_seq = "$up_seq", down_seq = "$down_seq", up_seq_region_start = $up_seq_start, up_seq_region_end = $up_seq_end, down_seq_region_start=$down_seq_start, down_seq_region_end=$down_seq_end, seq_region_strand=$seq_region_strand 
							   WHERE variation_id = $variation_id and seq_region_id = $seq_region_id and seq_region_strand = -1});
}
	
$dbVar->do(qq{UPDATE $table SET up_seq = null   WHERE up_seq = 'N'});
$dbVar->do(qq{UPDATE $table SET down_seq = null WHERE down_seq = 'N'});
