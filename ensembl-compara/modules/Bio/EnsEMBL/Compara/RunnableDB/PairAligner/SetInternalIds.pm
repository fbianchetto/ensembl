#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::SetInternalIds

=head1 SYNOPSIS


=head1 DESCRIPTION

This module makes the internal ids unique by setting auto_increment to start at method_link_species_set_id * 10**10. This will do this on the following tables: genomic_align_block, genomic_align, genomic_align_group, genomic_align_tree

=head1 PARAMETERS

=head1 CONTACT

Post questions to the Ensembl development list: dev@ensembl.org


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::SetInternalIds;

use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for gerp from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

}

=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   Run gerp
    Returns :   none
    Args    :   none

=cut

sub run {
    my $self = shift;

    return if ($self->param('skip'));

    $self->setInternalIds();
    

}

=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   Write results to the database
    Returns :   1
    Args    :   none

=cut

sub write_output {
    my ($self) = @_;

    return 1;
}

#Makes the internal ids unique
sub setInternalIds {
    my $self = shift;
    
    my $dba = $self->compara_dba;
    my $mlss_id;

    if (defined $self->param('method_link_species_set_id')) {
	$mlss_id = $self->param('method_link_species_set_id');
    } elsif ($self->param('method_link_type') && $self->param('genome_db_ids')) {
	my $mlssa = $dba->get_MethodLinkSpeciesSetAdaptor;
	my $mlss = $mlssa->fetch_by_method_link_type_genome_db_ids($self->param('method_link_type'), eval($self->param('genome_db_ids')));
	if (!defined $mlss) {
	    print "Unable to find method_link_species_set object of " . $self->param('method_link_type') . " for genome_dbs " . $self->param('genome_db_ids') . ". Unable to set internal ids.\n";
	    return;
	}

	$mlss_id = $mlss->dbID;
    } else {
	throw ("Must define either method_link_species_set_id or method_link_type and genome_db_ids");
    }
    
    if (!defined $mlss_id) {
	throw ("Unable to find method_link_species_set_id");
    }

    my $table_names;
    if (defined $self->param('tables')) {
	$table_names = $self->param('tables');
    } else {
	#default values
	$table_names->[0] = "genomic_align_block";
	$table_names->[1] = "genomic_align";
	$table_names->[2] = "genomic_align_tree";
    }

    #Set AUTO_INCREMENT to start at the {mlss_id} * 10**10 + 1
    my $index = ($mlss_id * 10**10) + 1;

    foreach my $table (@$table_names) {
	my $sql = "ALTER TABLE $table AUTO_INCREMENT=$index";
	my $sth = $dba->dbc->prepare($sql);
	$sth->execute();
	$sth->finish;
    }
}

1;
