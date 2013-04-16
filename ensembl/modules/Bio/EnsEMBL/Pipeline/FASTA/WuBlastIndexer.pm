=pod

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

Bio::EnsEMBL::Pipeline::FASTA::WuBlastIndexer

=head1 DESCRIPTION

Creates WUBlast indexes of the given GZipped file. The resulting index
is created under the parameter location I<base_path> in blast and then in a
directory defined by the type of dump. The type of dump also changes the file
name generated. Genomic dumps have their release version replaced with the
last repeat masked date. 

Allowed parameters are:

=over 8

=item file - The file to index

=item program - The location of the xdformat program

=item molecule - The type of molecule to index. I<dna> and I<pep> are allowed

=item type - Type of index we are creating. I<genomic> and I<genes> are allowed

=item base_path - The base of the dumps

=back

=cut

package Bio::EnsEMBL::Pipeline::FASTA::WuBlastIndexer;

use strict;
use warnings;
use base qw/Bio::EnsEMBL::Pipeline::FASTA::Indexer/;

use Bio::EnsEMBL::Utils::Exception qw/throw/;
use File::Copy qw/copy/;
use File::Spec;

sub param_defaults {
  my ($self) = @_;
  return {
    program => 'xdformat',
#    molecule => 'pep', #pep or dna
#    type => 'genes'    #genes or genomic
  };
}

sub fetch_input {
  my ($self) = @_;
  my $mol = $self->param('molecule');
  if($mol ne 'dna' && $mol ne 'pep') {
    throw "param 'molecule' must be set to 'dna' or 'pep'";
  }
  my $type = $self->param('type');
  if($type ne 'genomic' && $type ne 'genes') {
    throw "param 'type' must be set to 'genomic' or 'genes'";
  }
}

sub write_output {
  my ($self) = @_;
  $self->dataflow_output_id({
    species     => $self->param('species'),
    type        => $self->param('type'),
    molecule    => $self->param('molecule'),
    index_base  => $self->param('index_base')
  }, 1);
  return;
}

sub index_file {
  my ($self, $file) = @_;
  my $molecule_arg = ($self->param('molecule') eq 'dna') ? '-n' : '-p' ;
  my $silence = ($self->debug()) ? 0 : 1;
  my $target_file = $self->target_file($file);
  
  my $cmd = sprintf(q{%s %s -q%d -I -o %s %s }, 
    $self->param('program'), $molecule_arg, $silence, $target_file, $file);
  
  $self->info('About to run "%s"', $cmd);
  system($cmd) and throw sprintf("Cannot run program '%s' with exit code %d", $cmd, ($? >> 8));
  unlink $file or throw "Cannot remove the file '$file' from the filesystem: $!";
  $self->param('index_base', $target_file);
  return;
}

sub target_file {
  my ($self, $file) = @_;
  my $target_dir = $self->target_dir();
  my $target_filename = $self->target_filename($file);
  return File::Spec->catfile($target_dir, $target_filename);
}

# Produce a dir like /nfs/path/to/blast/genes/XXX && /nfs/path/to/blast/dna/XXX
sub target_dir {
  my ($self) = @_;
  return $self->get_dir('blast', $self->param('type'));
}

#Filename like Homo_sapiens.GRCh37.20090401.dna.toplevel.fa
sub target_filename {
  my ($self, $source_file) = @_;
  my ($vol, $dir, $file) = File::Spec->splitpath($source_file);
  if($self->param('type') eq 'genomic') {
    my @split = split(/\./, $file);
    my $rm_date = $self->repeat_mask_date();
    $split[-4] = $rm_date;
    return join(q{.}, @split);
  }
  return $file;
}

1;
