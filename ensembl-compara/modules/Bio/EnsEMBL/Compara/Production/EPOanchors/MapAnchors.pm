#Ensembl module for Bio::EnsEMBL::Compara::Production::EPOanchors::MapAnchors
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
=head1 NAME

Bio::EnsEMBL::Compara::Production::EPOanchors::MapAnchors

=head1 SYNOPSIS

$exonate_anchors->fetch_input();
$exonate_anchors->run();
$exonate_anchors->write_output(); writes to database

=head1 DESCRIPTION

Given a database with anchor sequences and a target genome. This modules exonerates 
the anchors against the target genome. The required information (anchor batch size,
target genome file, exonerate parameters are provided by the analysis, analysis_job 
and analysis_data tables  

=head1 AUTHOR - Stephen Fitzgerald

This modules is part of the Ensembl project http://www.ensembl.org

Email compara@ebi.ac.uk

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
dev@ensembl.org


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut
#
package Bio::EnsEMBL::Compara::Production::EPOanchors::MapAnchors;

use strict;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub configure_defaults {
 	my $self = shift;
	$self->param('mapping_exe', "/usr/local/ensembl/bin/exonerate-1.0.0" ) unless $self->param('mapping_exe');
	$self->param('mapping_params', { bestn=>11, gappedextension=>"no", softmasktarget=>"no", percent=>75, showalignment=>"no", model=>"affine:local", })
		unless $self->param('mapping_params');
}

sub fetch_input {
	my ($self) = @_;
	$self->configure_defaults();
	my $anchor_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor( %{ $self->param('compara_anchor_db') } );
	$anchor_dba->dbc->disconnect_if_idle();
	my $genome_db_file = $self->param('genome_db_file');
	my $sth = $anchor_dba->dbc->prepare("SELECT anchor_id, sequence FROM anchor_sequence WHERE anchor_id BETWEEN  ? AND ?");
	my($min_anc_id,$max_anc_id) =  @{ eval( $self->param('anchor_ids') ) }[0,-1];
	$sth->execute( $min_anc_id, $max_anc_id );
	my $query_file = $self->worker_temp_directory  . "anchors." . join ("-", $min_anc_id, $max_anc_id );
	open F, ">$query_file" || throw("Couldn't open $query_file");
	foreach my $anc_seq( @{ $sth->fetchall_arrayref } ){
		print F ">", $anc_seq->[0], "\n", $anc_seq->[1], "\n";
	}
	$self->param('query_file', $query_file);
}

sub run {
	my ($self) = @_;
	my $program = $self->param('mapping_exe');
	my $query_file = $self->param('query_file');
	my $target_file = $self->param('genome_db_file');
	my $option_st;
	while( my ($opt, $opt_value) = each %{ $self->param('mapping_params') } ) {
		$option_st .= " --" . $opt . " " . $opt_value; 
	}
	my $command = join(" ", $program, $option_st, $query_file, $target_file); 
	print $command, "\n";
	my $out_fh;
	open( $out_fh, "$command |" ) or throw("Error opening exonerate command: $? $!"); #run mapping program
	$self->param('out_file', $out_fh);
}

sub write_output {
my ($self) = @_;
my $anchor_align_adaptor = $self->compara_dba()->get_adaptor("AnchorAlign");
my $exo_fh = $self->param('out_file');
my ($hits, $target2dnafrag);
while(my $mapping = <$exo_fh>){ 
	next unless $mapping =~/^vulgar:/;
	my($anchor_info, $targ_strand, $targ_info, $targ_from, $targ_to, $score) = (split(" ",$mapping))[1,8,5,6,7,9];
	($targ_from, $targ_to) = ($targ_to, $targ_from) if ($targ_from > $targ_to); #exonerate can switch these around
		$targ_strand = $targ_strand eq "+" ? "1" : "-1";
		$targ_from++; #modify the exonerate start position
		my($anchor_name, $anc_org) = split(":", $anchor_info);
		push(@{$hits->{$anchor_name}{$targ_info}}, [ $targ_from, $targ_to, $targ_strand, $score, $anc_org ]);
		$target2dnafrag->{$targ_info}++;
	}
	foreach my $target_info (sort keys %{$target2dnafrag}) {
		my($coord_sys, $dnafrag_name) = (split(":", $target_info))[0,2];
		$target2dnafrag->{$target_info} = $anchor_align_adaptor->fetch_dnafrag_id(
							$coord_sys, $dnafrag_name, $self->param('genome_db_id'));
		die "no dnafrag_id found\n" unless($target2dnafrag->{$target_info});
	}
	my $hit_numbers = $self->merge_overlapping_target_regions($hits);
	my $records = $self->process_exonerate_hits($hits, $target2dnafrag, $hit_numbers);	
	$anchor_align_adaptor->store_exonerate_hits($records);
}

sub process_exonerate_hits {
	my $self = shift;
	my($hits, $target2dnafrag, $hit_numbers) = @_;
	my($records_to_load);
	foreach my $anchor_id (sort keys %{$hits}) {
		foreach my $targ_dnafrag_info (sort keys %{$hits->{$anchor_id}}) {
			my $dnafrag_id = $target2dnafrag->{$targ_dnafrag_info};
			foreach my $hit_position (@{$hits->{$anchor_id}->{$targ_dnafrag_info}}) {
				my $index = join(":", $anchor_id, $targ_dnafrag_info, $hit_position->[0]);
				my $number_of_org_hits = keys %{$hit_numbers->{$index}->{anc_orgs}};
				my $number_of_seq_hits = $hit_numbers->{$index}->{seq_nums};
				push(@{$records_to_load}, join(":", $self->param('mapping_mlssid'), $anchor_id, $dnafrag_id, 
							@{$hit_position}[0..3], $number_of_org_hits, $number_of_seq_hits));
			}
		}
	}
	return $records_to_load;
}

sub merge_overlapping_target_regions { #merge overlapping target regions hit by different seqs in the same anchor
	my $self = shift;
	my $mapped_anchors = shift;
	my $HIT_NUMS;
	foreach my $anchor(sort {$a <=> $b} keys %{$mapped_anchors}) {
	        foreach my $targ_info(sort keys %{$mapped_anchors->{$anchor}}) {
	                @{$mapped_anchors->{$anchor}{$targ_info}} = sort {$a->[0] <=> $b->[0]} @{$mapped_anchors->{$anchor}{$targ_info}};
	                for(my$i=0;$i<@{$mapped_anchors->{$anchor}{$targ_info}};$i++) {
	                        my $anc_look_up_name = join(":", $anchor, $targ_info, $mapped_anchors->{$anchor}{$targ_info}->[$i]->[0]);
				if($i < @{$mapped_anchors->{$anchor}{$targ_info}} - 1) {
		                        if($mapped_anchors->{$anchor}{$targ_info}->[$i]->[1] >= $mapped_anchors->{$anchor}{$targ_info}->[$i+1]->[0]) {  
		                                unless($mapped_anchors->{$anchor}{$targ_info}->[$i]->[2] eq 
							$mapped_anchors->{$anchor}{$targ_info}->[$i+1]->[2]) {       
		                                        print STDERR "possible palindromic sequences: $anchor ", 
								"$mapped_anchors->{$anchor}{$targ_info}->[$i]->[2] ", 
								$mapped_anchors->{$anchor}{$targ_info}->[$i+1]->[2], "\n";
		                                        $mapped_anchors->{$anchor}{$targ_info}->[$i]->[2] = 0;
		                                }       
		                                if($mapped_anchors->{$anchor}{$targ_info}->[$i]->[1] < 
							$mapped_anchors->{$anchor}{$targ_info}->[$i+1]->[1]) {
		                                        $mapped_anchors->{$anchor}{$targ_info}->[$i]->[1] = 
								$mapped_anchors->{$anchor}{$targ_info}->[$i+1]->[1];
		                                }       
		                                $mapped_anchors->{$anchor}{$targ_info}->[$i]->[3] += $mapped_anchors->{$anchor}{$targ_info}->[$i+1]->[3];
		                                $mapped_anchors->{$anchor}{$targ_info}->[$i]->[3] /= 2; # simplistic scoring
						#count the organisms from which the anchor seqs were derived 
		                                $HIT_NUMS->{$anc_look_up_name}{anc_orgs}{$mapped_anchors->{$anchor}{$targ_info}->[$i+1]->[4]}++;
						#count number of anchor seqs that map
						$HIT_NUMS->{$anc_look_up_name}{seq_nums}++;
		                                splice(@{$mapped_anchors->{$anchor}{$targ_info}}, $i+1, 1);
		                                $i--;   
						next;
		                        }       
				}
				$HIT_NUMS->{$anc_look_up_name}{anc_orgs}{$mapped_anchors->{$anchor}{$targ_info}->[$i]->[4]}++;
				$HIT_NUMS->{$anc_look_up_name}{seq_nums}++;
	                }       
	        }       
	}
	return $HIT_NUMS;
}

1;

