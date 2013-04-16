package XrefParser::ZFINDescParser;

use strict;
use warnings;
use Carp;
use POSIX qw(strftime);
use File::Basename;
use File::Spec::Functions;

use base qw( XrefParser::BaseParser );


sub run {

  my ($self, $ref_arg) = @_;
  my $source_id    = $ref_arg->{source_id};
  my $species_id   = $ref_arg->{species_id};
  my $files        = $ref_arg->{files};
  my $verbose      = $ref_arg->{verbose};

  if((!defined $source_id) or (!defined $species_id) or (!defined $files) ){
    croak "Need to pass source_id, species_id and files as pairs";
  }
  $verbose |=0;

  my $file = @{$files}[0];

#e.g.
#ZDB-GENE-050102-6       WITHDRAWN:zgc:92147     WITHDRAWN:zgc:92147     0
#ZDB-GENE-060824-3       apobec1 complementation factor  a1cf    0
#ZDB-GENE-090212-1       alpha-2-macroglobulin-like      a2ml    15      ZDB-PUB-030703-1


  my $count =0;
  my $withdrawn = 0;
  open( my $FH, "<", $file) || croak "could not open file $file";
  while ( <$FH> ) {
    chomp;
    my ($zfin, $desc, $label) = split (/\t/,$_);

    if($label =~ /^WITHDRAWN/){
      $withdrawn++;
    }
    else{
      $self->add_xref({ acc        => $zfin,
			label      => $label,
			desc       => $desc,
			source_id  => $source_id,
			species_id => $species_id,
			info_type  => "MISC"} );
      $count++;
    }
  }
  close($FH);

  if($verbose){
    print "\t$count xrefs added, $withdrawn withdrawn entries ignored\n";
  }
  return 0;
}

1;
