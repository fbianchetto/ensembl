=head1 NAME

HMMProfileAdaptor

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONTACT

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded by a _.

=cut

package Bio::EnsEMBL::Compara::DBSQL::HMMProfileAdaptor;

use strict;
use Data::Dumper;

use Bio::EnsEMBL::Compara::HMMProfile;

use Bio::EnsEMBL::Utils::Exception qw(throw warning deprecate); ## All needed?
use DBI qw(:sql_types);
use base ('Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor');


=head2 fetch_all_by_type

  Arg [1]       : (string) The database type for a series of hmm_profiles
  Example       : $profiles = $hmmProfileAdaptor->fetch_all_by_type($type);
  Description   : Returns a HMMProfile object for the given name
  ReturnType    : Bio::EnsEMBL::Compara::HMMProfile
  Exceptions    : If $type is not defined
  Caller        : General

=cut

sub fetch_by_name {
    my ($self, $type) = @_;

    throw ("type is undefined") unless (defined $type);

    my $constraint = 'h.type = ?';
    $self->bind_param_generic_fetch($type, SQL_VARCHAR);
    return $self->generic_fetch($constraint);
}



=head2 fetch_by_model_id

  Arg [1]       : (string) The database model_id for a hmm_profile
  Example       : $profile = $hmmProfileAdaptor->fetch_by_model_id($model_id);
  Description   : Returns a HMMProfile object for the given model_id
  ReturnType    : Bio::EnsEMBL::Compara::HMMProfile
  Exceptions    : If $model_id is not defined
  Caller        : General

=cut

sub fetch_by_model_id {
    my ($self, $model_id) = @_;

    throw ("model_id is undefined") unless (defined $model_id);

    my $constraint = 'h.model_id = ?';
    $self->bind_param_generic_fetch($model_id, SQL_VARCHAR);
    return $self->generic_fetch_one($constraint);
}


=head2 fetch_by_name

  Arg [1]       : (string) The database name for a hmm_profile
  Example       : $profile = $hmmProfileAdaptor->fetch_by_name($name);
  Description   : Returns a HMMProfile object for the given name
  ReturnType    : Bio::EnsEMBL::Compara::HMMProfile
  Exceptions    : If $name is not defined
  Caller        : General

=cut

sub fetch_by_name {
    my ($self, $name) = @_;

    throw ("name is undefined") unless (defined $name);

    my $constraint = 'h.name = ?';
    $self->bind_param_generic_fetch($name, SQL_VARCHAR);
    return $self->generic_fetch_one($constraint);
}

=head2 fetch_all_model_ids

  Arg [1]     : (arrayref) Column names to retrieve
  Arg [2]     : (string) (optional) Optional type for the model_ids
  Example     : $model_ids = $hmmProfileAdaptor->fetch_all_model_ids($type)
  Description : Returns an array ref with all the model_ids present in the database
                (possibly pertaining to a defined $type)
  ReturnType  : hashref with the column names and values
  Exceptions  :
  Caller      : General

=cut

sub fetch_all_by_column_names {
    my ($self, $columns_ref, $type) = @_;

    throw ("columns is undefined") unless (defined $columns_ref);
    throw ("columns have to be passed as an array ref") unless (ref $columns_ref eq "ARRAY");

    my $columns = join ",", @$columns_ref;

    my $constraint = "";
    if (defined $type) {
        $constraint = " WHERE type = '$type'";
    }

    my $sth = $self->prepare("SELECT $columns FROM hmm_profile" . $constraint);
    $sth->execute();
    my @id_list = ();
    while (my $idref = $sth->fetchrow_hashref()) {
        push @id_list, $idref;
    }
    $sth->finish;

    return [@id_list];
}

###############################
#
# Subclass override methods
#
###############################

sub _tables {
    return (['hmm_profile', 'h']);
}

sub _columns {
    return ( 'h.model_id',
             'h.name',
             'type',
             'hc_profile',
             'consensus',
           );
}

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
    my ($self, $rowhash) = @_;

    my $obj = Bio::EnsEMBL::Compara::HMMProfile->new();
    $self->init_instance_from_rowhash($obj,$rowhash);

    return $obj;
}

sub init_instance_from_rowhash() {
    my ($self, $obj, $rowhash) = @_;

    $obj->model_id($rowhash->{model_id});
    $obj->name($rowhash->{name});
    $obj->type($rowhash->{type});
    $obj->profile($rowhash->{hc_profile});
    $obj->consensus($rowhash->{consensus});

    return $obj;
}

sub store {
    my ($self, $obj) = @_;

    unless(UNIVERSAL::isa($obj, 'Bio::EnsEMBL::Compara::HMMProfile')) {
        throw("set arg must be a [Bio::EnsEMBL::Compara::HMMProfile] not a $obj");
    }

    my $sth = $self->prepare("REPLACE INTO hmm_profile(model_id, name, type, hc_profile, consensus) VALUES (?,?,?,?,?)");
    $sth->execute($obj->model_id(), $obj->name(), $obj->type(), $obj->profile(), $obj->consensus());
    $sth->finish();

    return;
}


1;
