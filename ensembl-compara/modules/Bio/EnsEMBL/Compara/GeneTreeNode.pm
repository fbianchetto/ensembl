=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

   http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::GeneTreeNode

=head1 DESCRIPTION

Specific subclass of NestedSet to add functionality when the nodes of this tree
are GeneTreeMember objects and the tree is a representation of a gene derived
Phylogenetic tree

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::GeneTreeNode
  `- Bio::EnsEMBL::Compara::NestedSet

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=head1 MAINTAINER

$Author: mm14 $

=head VERSION

$Revision: 1.11 $

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::GeneTreeNode;

use strict;

use IO::File;

use Bio::SimpleAlign;

use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception;

use Bio::EnsEMBL::Compara::BaseRelation;
use Bio::EnsEMBL::Compara::SitewiseOmega;

use base ('Bio::EnsEMBL::Compara::NestedSet');


sub tree {
  my $self = shift;
  $self->{'_tree'} = shift if(@_);
  return $self->{'_tree'};
}

# tweaked to take into account the GeneTree object
sub root {
    my $self = shift;
    if (defined $self->tree) {
        return $self->tree->root;
    } else {
        return $self->SUPER::root;
    }
}


=head2 release_tree

  Overview   : Removes the to/from GeneTree reference to
               allow freeing memory 
  Example    : $self->release_tree;
  Returntype : undef
  Exceptions : none
  Caller     : general

=cut

sub release_tree {
    my $self = shift;

    if (defined $self->tree) {
        delete $self->{'_tree'}->{'_root'};
        delete $self->{'_tree'};
    }
    return $self->SUPER::release_tree;
}


#use Data::Dumper;

#sub string_node {
#    my $self = shift;
#    my $str = $self->SUPER::string_node;
#    if (defined $self->{'_tree'}) {
#        my $t = $self->{'_tree'};
#        $str = chop($str)." $t/root_id=".($self->{'_tree'}->root_id)."/".join("/", map { "$_ => ${$t}{$_}" } keys %$t)."\n";
#    }
#    return $str;
#}

sub get_leaf_by_Member {
  my $self = shift;
  my $member = shift;

  if($member->isa('Bio::EnsEMBL::Compara::GeneTreeNode')) {
    return $self->find_leaf_by_node_id($member->node_id);
  } elsif ($member->isa('Bio::EnsEMBL::Compara::Member')) {
    return $self->find_leaf_by_name($member->get_canonical_Member->stable_id);
  } else {
    die "Need a Member object!";
  }
}

sub get_SimpleAlign {
  my ($self, @args) = @_;

  my $id_type = 'STABLE';
  my $unique_seqs = 0;
  my $cdna = 0;
  my $stop2x = 0;
  my $append_taxon_id = 0;
  my $append_sp_short_name = 0;
  my $append_genomedb_id = 0;
  my $exon_cased = 0;
  if (scalar @args) {
    ($unique_seqs, $cdna, $id_type, $stop2x, $append_taxon_id, $append_sp_short_name, $append_genomedb_id, $exon_cased) =
       rearrange([qw(UNIQ_SEQ CDNA ID_TYPE STOP2X APPEND_TAXON_ID APPEND_SP_SHORT_NAME APPEND_GENOMEDB_ID EXON_CASED)], @args);
  }
  $id_type = 'STABLE' unless(defined($id_type));

  my $sa = Bio::SimpleAlign->new();

  #Hack to try to work with both bioperl 0.7 and 1.2:
  #Check to see if the method is called 'addSeq' or 'add_seq'
  my $bio07 = 0;
  $bio07=1 if(!$sa->can('add_seq'));

  my $seq_id_hash = {};
  foreach my $member (@{$self->get_all_leaves}) {
    next unless($member->isa('Bio::EnsEMBL::Compara::GeneTreeMember'));
    next if($unique_seqs and $seq_id_hash->{$member->sequence_id});
    $seq_id_hash->{$member->sequence_id} = 1;

    my $seqstr;
    if ($cdna) {
      $seqstr = $member->cdna_alignment_string;
      $seqstr =~ s/\s+//g;
    } else {
      $seqstr = $member->alignment_string($exon_cased);
    }
    next if(!$seqstr);

    my $seqID = $member->stable_id;
    $seqID = $member->sequence_id if($id_type eq "SEQ");
    $seqID = $member->member_id if($id_type eq "MEMBER");
    $seqID .= "_" . $member->taxon_id if($append_taxon_id);
    $seqID .= "_" . $member->genome_db_id if ($append_genomedb_id);

    ## Append $seqID with Speciae short name, if required
    if ($append_sp_short_name) {
      my $species = $member->genome_db->short_name;
      $species =~ s/\s/_/g;
      $seqID .= "_" . $species . "_";
    }

#    $seqID .= "_" . $member->genome_db->taxon_id if($append_taxon_id); # this may be needed if you have subspecies or things like that
    $seqstr =~ s/\*/X/g if ($stop2x);
    my $seq = Bio::LocatableSeq->new(-SEQ    => $seqstr,
                                     -START  => 1,
                                     -END    => length($seqstr),
                                     -ID     => $seqID,
                                     -STRAND => 0);

    if($bio07) {
      $sa->addSeq($seq);
    } else {
      $sa->add_seq($seq);
    }
  }

  return $sa;
}

# Takes a protein tree and creates a consensus cigar line from the
# constituent leaf nodes.
sub consensus_cigar_line {

   my $self = shift;
   my @cigars;

   # First get an 'expanded' cigar string for each leaf of the subtree
   my @all_leaves = @{$self->get_all_leaves};
   my $num_leaves = scalar(@all_leaves);
   foreach my $leaf (@all_leaves) {
     next unless( UNIVERSAL::can( $leaf, 'cigar_line' ) );
     my $cigar = $leaf->cigar_line;
     my $newcigar = "";
#     $cigar =~ s/(\d*)([A-Z])/$2 x ($1||1)/ge; #Expand
      while ($cigar =~ /(\d*)([A-Z])/g) {
          $newcigar .= $2 x ($1 || 1);
      }
     $cigar = $newcigar;
     push @cigars, $cigar;
   }

   # Itterate through each character of the expanded cigars.
   # If there is a 'D' at a given location in any cigar,
   # set the consensus to 'D', otherwise assume an 'M'.
   # TODO: Fix assumption that cigar strings are always the same length,
   # and start at the same point.
   my $cigar_len = length( $cigars[0] );
   my $cons_cigar;
   for( my $i=0; $i<$cigar_len; $i++ ){
     my $char = 'M';
     my $num_deletions = 0;
     foreach my $cigar( @cigars ){
       if ( substr($cigar,$i,1) eq 'D'){
         $num_deletions++;
       }
     }
     if ($num_deletions * 3 > 2 * $num_leaves) {
       $char = "D";
     } elsif ($num_deletions * 3 > $num_leaves) {
       $char = "m";
     }
     $cons_cigar .= $char;
   }

   # Collapse the consensus cigar, e.g. 'DDDD' = 4D
#   $cons_cigar =~ s/(\w)(\1*)/($2?length($2)+1:"").$1/ge;
   my $collapsed_cigar = "";
   while ($cons_cigar =~ /(D+|M+|I+|m+)/g) {
     $collapsed_cigar .= (length($1) == 1 ? "" : length($1)) . substr($1,0,1)
 }
   $cons_cigar = $collapsed_cigar;
   # Return the consensus
   return $cons_cigar;
}



=head2 remove_nodes_by_taxon_ids

  Arg [1]     : arrayref of taxon_ids
  Example     : my $ret_tree = $tree->remove_nodes_by_taxon_ids($taxon_ids);
  Description : Returns the tree with removed nodes in taxon_id list.
  Returntype  : Bio::EnsEMBL::Compara::GeneTreeNode object
  Exceptions  :
  Caller      : general
  Status      : At risk (behaviour on exceptions could change)

=cut

sub remove_nodes_by_taxon_ids {
  my $self = shift;
  my $species_arrayref = shift;

  my @tax_ids = @{$species_arrayref};
  # Turn the arrayref into a hash.
  my %tax_hash;
  map {$tax_hash{$_}=1} @tax_ids;

  my @to_delete;
  foreach my $leaf (@{$self->get_all_leaves}) {
    if (exists $tax_hash{$leaf->taxon_id}) {
      push @to_delete, $leaf;
    }
  }
  return $self->remove_nodes(\@to_delete);

}


=head2 keep_nodes_by_taxon_ids

  Arg [1]     : arrayref of taxon_ids
  Example     : my $ret_tree = $tree->keep_nodes_by_taxon_ids($taxon_ids);
  Description : Returns the tree with kept nodes in taxon_id list.
  Returntype  : Bio::EnsEMBL::Compara::GeneTreeNode object
  Exceptions  :
  Caller      : general
  Status      : At risk (behaviour on exceptions could change)

=cut


sub keep_nodes_by_taxon_ids {
  my $self = shift;
  my $species_arrayref = shift;

  my @tax_ids = @{$species_arrayref};
  # Turn the arrayref into a hash.
  my %tax_hash;
  map {$tax_hash{$_}=1} @tax_ids;

  my @to_delete;
  foreach my $leaf (@{$self->get_all_leaves}) {
    unless (exists $tax_hash{$leaf->taxon_id}) {
      push @to_delete, $leaf;
    }
  }
  return $self->remove_nodes(\@to_delete);

}

1;

