package Bio::EnsEMBL::Compara::Family;

use strict;
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception;

use base ('Bio::EnsEMBL::Compara::AlignedMemberSet');

=head2 new

  Arg [1]    : 
  Example    : 
  Description: 
  Returntype : Bio::EnsEMBL::Compara::Family (but without members; caller has to fill using
               add_member)
  Exceptions : 
  Caller     : 

=cut

sub new {
  my($class,@args) = @_;
  
  my $self = $class->SUPER::new(@args);
  
  if (scalar @args) {
     #do this explicitly.
     my ($description_score) = rearrange([qw(DESCRIPTION_SCORE)], @args);
      
      $description_score && $self->description_score($description_score);
  }
  
  return $self;
}   

=head2 description_score

  Arg [1]    : 
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub description_score {
  my $self = shift;
  $self->{'_description_score'} = shift if(@_);
  return $self->{'_description_score'};
}


=head2 deep_copy

  Description: Returns a copy of $self. All the members are themselves copied
  Returntype : Bio::EnsEMBL::Compara::Family
  Caller     : general
  Status     : Stable

=cut

sub deep_copy {
    my $self = shift;
    my $copy = $self->SUPER::deep_copy();
    $copy->description_score($self->description_score);
    return $copy;
}

1;
