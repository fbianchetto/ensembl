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

Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor

=head1 DESCRIPTION

Base adaptor for objects inheriting from NestedSet

=head1 INHERITANCE TREE

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=head1 MAINTAINER

$Author: mm14 $

=head VERSION

$Revision: 1.58 $

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor;

use strict;

use Bio::EnsEMBL::DBSQL::DBConnection;
use Bio::EnsEMBL::Utils::Exception qw(throw warning deprecate);
use Bio::EnsEMBL::Utils::SqlHelper;

use Bio::EnsEMBL::Compara::NestedSet;

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor');


###########################
# FETCH methods
###########################

=head2 fetch_all

  Arg[1]     : -none-
  Example    : $all_trees = $proteintree_adaptor->fetch_all();

  Description: Fetches from the database all the nested sets.
  Returntype : arrayref of Bio::EnsEMBL::Compara::NestedSet
  Exceptions :
  Caller     :

=cut

sub fetch_all {
  my ($self) = @_;

  my $table = ($self->_tables)[0]->[1];
  my $constraint = "$table.node_id = $table.root_id";
  return $self->generic_fetch($constraint);
}

sub fetch_node_by_node_id {
  my ($self, $node_id) = @_;

  if (! defined $node_id) {
    throw("node_id is undefined")
  }

  my $table= ($self->_tables)[0]->[1];
  my $constraint = "$table.node_id = $node_id";
  my ($node) = @{$self->generic_fetch($constraint)};
  return $node;
}

=head2 fetch_parent_for_node

  Arg[1]     : NestedSet: $node
  Example    : $parent_node = $genetree_adaptor->fetch_parent_for_node($node);
  Description: Fetches from the database the parent node of a node, or returns
                the already-loaded instance if available
  Returntype : Bio::EnsEMBL::Compara::NestedSet

=cut

sub fetch_parent_for_node {
    my ($self, $node) = @_;

    unless($node->isa('Bio::EnsEMBL::Compara::NestedSet')) {
        throw("set arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a $node");
    }

    return $node->{'_parent_link'}->get_neighbor($node) if defined $node->{'_parent_link'};
    my $parent = undef;
    $parent = $self->fetch_node_by_node_id($node->_parent_id) if defined $node->_parent_id;
    $parent->add_child($node) if defined $parent;
    return $parent;
}


sub fetch_all_children_for_node {
  my ($self, $node) = @_;

  unless($node->isa('Bio::EnsEMBL::Compara::NestedSet')) {
    throw("set arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a $node");
  }

  my $constraint = "parent_id = " . $node->node_id;
  my $kids = $self->generic_fetch($constraint);
  foreach my $child (@{$kids}) { $node->add_child($child); }

  return $node;
}

sub fetch_all_leaves_indexed {
  my ($self, $node) = @_;

  unless($node->isa('Bio::EnsEMBL::Compara::NestedSet')) {
    throw("set arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a $node");
  }

  my $table= ($self->_tables)[0]->[1];
  my $left_index = $node->left_index;
  my $right_index = $node->right_index;
  my $root_id = $node->_root_id;
  my $constraint = "($table.root_id = $root_id) AND (($table.right_index - $table.left_index) = 1) AND ($table.left_index > $left_index) AND ($table.right_index < $right_index)";
  return $self->generic_fetch($constraint);
}

sub fetch_subtree_under_node {
  my $self = shift;
  my $node = shift;

  unless($node->isa('Bio::EnsEMBL::Compara::NestedSet')) {
    throw("set arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a $node");
  }

  unless ($node->left_index && $node->right_index) {
    warning("fetch_subtree_under_node subroutine assumes that left and right index has been built and store in the database.\n This does not seem to be the case for node_id=".$node->node_id.". Returning node.\n");
    return $node;
  }

  my $alias = ($self->_tables)[0]->[1];

  my $left_index = $node->left_index;
  my $right_index = $node->right_index;
  my $root_id = $node->_root_id;
  my $constraint = "($alias.root_id = $root_id) AND ($alias.left_index >= $left_index) AND ($alias.right_index <= $right_index)";
  my $all_nodes = $self->generic_fetch($constraint);
  push @{$all_nodes}, $node;
  $self->_build_tree_from_nodes($all_nodes);
  return $node;
}


sub fetch_tree_at_node_id {
  my $self = shift;
  my $node_id = shift;

  if (! defined $node_id) {
    throw ("node_id is undefined");
  }

  my $node = $self->fetch_node_by_node_id($node_id);

  return $self->fetch_subtree_under_node($node);
}



=head2 fetch_tree_by_root_id

  Arg[1]     : root_id: integer
  Example    : $root_node = $proteintree_adaptor->fetch_tree_by_root_id(3);
  Description: Fetches from the database all the nodes linked to this root_id
                and links them in a tree structure. Returns the root node
  Returntype : Bio::EnsEMBL::Compara::NestedSet
  Caller     : general

=cut

sub fetch_tree_by_root_id {
  my ($self, $root_id) = @_;

  my $table = ($self->_tables)[0]->[1];
  my $constraint = "$table.root_id = $root_id";
  return $self->_build_tree_from_nodes($self->generic_fetch($constraint));
}



sub fetch_subroot_by_left_right_index {
  deprecate('fetch_subroot_by_left_right_index() should not be used and will be removed in release 70.
  If you are using it, please contact the dev mailing-list dev@ensembl.org');
  my ($self,$node) = @_;

  unless ($node->left_index && $node->right_index) {
    warning("fetch_subroot_by_left_right_index subroutine assumes that left and right index has been built and store in the database.\n This does not seem to be the case.\n");
  }
  my $left_index = $node->left_index;
  my $right_index = $node->right_index;
  my $root_id = $node->_root_id;

  my $constraint = "parent_id = $root_id AND left_index<=$left_index AND right_index>=$right_index";
  return $self->generic_fetch($constraint)->[0];
}


=head2 fetch_root_by_node

  Arg [1]    : Bio::EnsEMBL::Compara::NestedSet $node
  Example    : $root = $nested_set_adaptor->fetch_root_by_node($node);
  Description: Returns the root of the tree for this node
               with links to all the intermediate nodes. Sister nodes
               are not included in the result. Use fetch_node_by_node_id()
               method to get the whole tree (loaded on demand)
  Returntype : Bio::EnsEMBL::Compara::NestedSet
  Exceptions : thrown if $node is not defined
  Status     : At-risk
  Caller     : $nested_set->root

=cut
sub fetch_root_by_node {
  my ($self, $node) = @_;

  unless(UNIVERSAL::isa($node, 'Bio::EnsEMBL::Compara::NestedSet')) {
    throw("set arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a $node");
  }

  my $alias = ($self->_tables)[0]->[1];

  my $left_index = $node->left_index;
  my $right_index = $node->right_index;
  my $root_id = $node->_root_id;

  my $constraint = "($alias.root_id = $root_id) AND ($alias.left_index <= $left_index) AND ($alias.right_index >= $right_index)";
  my $nodes = $self->generic_fetch($constraint);
  my $root = $self->_build_tree_from_nodes($nodes);

  return $root;
}


=head2 fetch_first_shared_ancestor_indexed

  Arg [1]    : Bio::EnsEMBL::Compara::NestedSet $node1
  Arg [2]    : Bio::EnsEMBL::Compara::NestedSet $node2
  Arg [n]    : Bio::EnsEMBL::Compara::NestedSet $node_n
  Example    : $lca = $nested_set_adaptor->fetch_first_shared_ancestor_indexed($node1, $node2);
  Description: Returns the first node of the tree that is an ancestor of all the nodes passed
               as arguments. There must be at least one argument, and all the nodes must share
               the same root
  Returntype : Bio::EnsEMBL::Compara::NestedSet
  Exceptions : thrown if the nodes don't share the same root_id

=cut
sub fetch_first_shared_ancestor_indexed {
  my $self = shift;
  
  my $node1 = shift;
  my $root_id = $node1->_root_id;
  my $min_left = $node1->left_index;
  my $max_right = $node1->right_index;

  while (my $node2 = shift) {
    if ($node2->_root_id != $root_id) {
      throw("Nodes must have the same root in fetch_first_shared_ancestor_indexed ($root_id != ".($node2->_root_id).")\n");
    }
    $min_left = $node2->left_index if $node2->left_index < $min_left;
    $max_right = $node2->right_index if $node2->right_index > $max_right;
  }

  my $alias = ($self->_tables)[0]->[1];
  my $constraint = "$alias.root_id=$root_id AND $alias.left_index <= $min_left AND $alias.right_index >= $max_right";
  my $final = " ORDER BY ($alias.right_index-$alias.left_index) LIMIT 1";
  
  my $ancestor = $self->generic_fetch($constraint, '', $final)->[0];
  return $ancestor;
}



###########################
# STORE methods
###########################

sub update {
  my ($self, $node) = @_;

  unless(UNIVERSAL::isa($node, 'Bio::EnsEMBL::Compara::NestedSet')) {
    throw("set arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a $node");
  }

  my $parent_id = 0;
  if($node->parent) {
    $parent_id = $node->parent->node_id ;
  }
  my $root_id = $node->root->node_id;

 my $table= ($self->_tables)[0]->[0];
  my $sql = "UPDATE $table SET ".
               "parent_id=$parent_id".
               ",root_id=$root_id".
               ",left_index=" . $node->left_index .
               ",right_index=" . $node->right_index .
               ",distance_to_parent=" . $node->distance_to_parent .
             " WHERE $table.node_id=". $node->node_id;

  $self->dbc->do($sql);
}


sub update_subtree {
  my $self = shift;
  my $node = shift;

  $self->update($node);

  foreach my $child (@{$node->children}) {
    $self->update_subtree($child);
  }
}

=head2 sync_tree_leftright_index

  Arg [1]    : Bio::EnsEMBL::Compara::NestedSet $root
  Arg [2]    : Boolean; indicates if you wish to use a fresh database 
               connection to perform any locking. If you are within an existing
               transaction this is a good idea to avoid locking the LR table
               for the duration of your transaction
  Example    : $nsa->sync_tree_leftright_index($root);
  Description: For the given root this method looks for left right index
               offset recorded in lr_index_offset for the configured
               table. The program locks on this table to reserve a batch
               of identifiers which are then used to left_right index
               the tree.

               The left right indexing is called by this method on your given
               tree root
  Returntype : Nothing
  Exceptions : Only raised from DBI problems
  Caller     : Public

=cut

sub sync_tree_leftright_index {
  my ($self, $tree_root, $use_fresh_connection) = @_;
  my $starting_lr_index = $self->_get_starting_lr_index($tree_root, $use_fresh_connection);
  $tree_root->build_leftright_indexing($starting_lr_index);
  return;
}

##
## Offset is pre-calculated by taking the number of nodes in the tree
## and multiplying by 2. This is then stored & passed back to
## sync_tree_leftright_index()
##
sub _get_starting_lr_index {
  my ($self, $tree_root, $use_fresh_connection) = @_;

  my $table = $self->_lr_table_name();
  my $node_count = scalar(@{$tree_root->get_all_nodes()});
  my $lr_ids_needed = $node_count*2;
  
  my $select_sql = 'SELECT lr_index_offset_id, lr_index FROM lr_index_offset WHERE table_name =? FOR UPDATE';
  my $update_sql = 'UPDATE lr_index_offset SET lr_index =? WHERE lr_index_offset_id =?';

  my $conn = ($use_fresh_connection) ?
    Bio::EnsEMBL::DBSQL::DBConnection->new(-DBCONN => $self->dbc()) :
    $self->dbc();
  my $h = Bio::EnsEMBL::Utils::SqlHelper->new(-DB_CONNECTION => $conn);

  my $starting_lr_index;
  #Retry because this *cannot* fail due to NJTREE -> QuickTreeBreak flow
  $h->transaction(
    -RETRY => 3,
    -CONDITION => sub {
      my ($error) = @_;
      return ( $error =~ /deadlock/i ) ? 1 : 0;
    },
    -CALLBACK => sub {
      my $rows = $h->execute(-SQL => $select_sql, -PARAMS => [$table]);
      if(!@{$rows}) {
        throw("The table '${table}' does not have an entry in lr_index_offset");
      }
      my ($id, $max) = @{$rows->[0]};
      $starting_lr_index = $max+1;
      my $new_max = $max+$lr_ids_needed;
      $h->execute_update(-SQL => $update_sql, -PARAMS => [$new_max, $id]);
      return;
    }
  );
  
  $conn->disconnect_if_idle() if($use_fresh_connection);

  return $starting_lr_index;
}

sub _lr_table_name {
  my ($self) = @_;
  return ($self->_tables)[0]->[0];
}

##################################
#
# Database related methods, sublcass overrides/inherits
#
##################################


sub _objs_from_sth {
    my ($self, $sth) = @_;
    my $node_list = [];

    while (my $rowhash = $sth->fetchrow_hashref) {
        my $node = $self->create_instance_from_rowhash($rowhash);
        push @$node_list, $node;
    }
    return $node_list;
}


sub create_instance_from_rowhash {
  my $self = shift;
  my $rowhash = shift;

  #my $node = $self->cache_fetch_by_id($rowhash->{'node_id'});
  #return $node if($node);

  my $node = new Bio::EnsEMBL::Compara::NestedSet;
  $self->init_instance_from_rowhash($node, $rowhash);

  #$self->cache_add_object($node);

  return $node;
}


sub init_instance_from_rowhash {
  my $self = shift;
  my $node = shift;
  my $rowhash = shift;

  $node->adaptor($self);
  $node->node_id               ($rowhash->{'node_id'});
  $node->_parent_id            ($rowhash->{'parent_id'});
  $node->_root_id              ($rowhash->{'root_id'});
  $node->left_index            ($rowhash->{'left_index'});
  $node->right_index           ($rowhash->{'right_index'});
  $node->distance_to_parent    ($rowhash->{'distance_to_parent'});

  return $node;
}


##################################
#
# INTERNAL METHODS
#
##################################

sub new {
  my $class = shift;

  my $self = $class->SUPER::new(@_);

  $self->{'_node_cache'} = [];
  return $self;
}

sub DESTROY {
  my $self = shift;
  $self->clear_cache;
  $self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
}

sub cache_fetch_by_id {
  my $self = shift;
  my $node_id = shift;

  for(my $index=0; $index<scalar(@{$self->{'_node_cache'}}); $index++) {
    my $node = $self->{'_node_cache'}->[$index];
    if($node->node_id == $node_id) {
      splice(@{$self->{'_node_cache'}}, $index, 1); #removes from list
      unshift @{$self->{'_node_cache'}}, $node; #put at front of list
      return $node;
    }
  }
  return undef;
}


sub cache_add_object
{
  my $self = shift;
  my $node = shift;

  unshift @{$self->{'_node_cache'}}, $node; #put at front of list
  while(scalar(@{$self->{'_node_cache'}}) > 3000) {
    my $old = pop @{$self->{'_node_cache'}};
    #print("shrinking cache : "); $old->print_node;
  }
  return undef;
}

sub clear_cache {
  my $self = shift;

  $self->{'_node_cache'} = [];
  return undef;
}

sub _build_tree_from_nodes {
  my $self = shift;
  my $node_list = shift;

  #first hash all the nodes by id for fast access
  my %node_hash;
  foreach my $node (@{$node_list}) {
    $node->no_autoload_children;
    $node_hash{$node->node_id} = $node;
  }

  #next add children to their parents
  my $root = undef;
  foreach my $node (@{$node_list}) {
    my $parent = $node_hash{$node->_parent_id};
    if($parent) { $parent->add_child($node); }
    else { $root = $node; }
  }
  return $root;
}


1;
