=pod 

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::CAFE_conf

=head1 SYNOPSIS

    #0. make sure that ncRNA pipeline (whose gene clusters you want to incorporate) is already past member the RFAMClassify analysis

    #1. update ensembl-hive, ensembl and ensembl-compara CVS repositories before each new release

    #2. you may need to update 'schema_version' in meta table to the current release number in ensembl-hive/sql/tables.sql

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::CAFE_conf -password <your_password> -pipeline_name <ncRNAtree_pipeline_name> -host <host_where_the_ncRNAtree_pipeline_is_running>> -analysis_topup

    #5. Run the "sync" and "loop" commands as suggested by init_pipeline.pl

    #6. Pray

=head1 DESCRIPTION  

    The PipeConfig file for CAFE pipeline that should automate most of the tasks

=head1 CONTACT

  Please contact ehive-users@ebi.ac.uk mailing list with questions/suggestions.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::CAFE_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
            %{$self->SUPER::default_options},

            # You need to specify -pipeline_name, -host, -work_dir and -password on command line (if they are not already set as an environmental variable)

            # Data needed for CAFE
            'species_tree_meta_key' => 'full_species_tree_string',
            'cafe_species'          =>  ['danio.rerio', 'taeniopygia.guttata', 'callithrix.jacchus', 'pan.troglodytes', 'homo.sapiens', 'mus.musculus'],
            'cafe_lambdas'          => '',  # For now, we don't supply lambdas
            'cafe_struct_tree_str'  => '',  # Not set by default
            'cafe_shell'            => '/software/ensembl/compara/cafe/cafe.2.2/cafe/bin/shell',
           };
}

## WARNING!!
## Currently init_pipeline.pl doesn't run this method when a pipeline is created with the -analysis_topup option
## So make sure that $self->o('work_dir') exists in the filesystem before running the pipeline
## This method remains here for documentation purposes (to support this warning) and in case the init_pipeline is modified to allow topup analysis create its own commands
sub pipeline_create_commands {
    my ($self) = @_;
    return [
        'mkdir -p '.$self->o('work_dir'),
    ];
}


sub resource_classes {
    my ($self) = @_;
    return {
            300 => { -desc => 'CAFE'   , 'LSF' => '-S 1024 -q long -M15000000 -R"select[mem>15000] rusage[mem=15000]"' },
           };
}

sub pipeline_analyses {
    my ($self) = @_;
    return [

            {
             -logic_name => 'make_full_species_tree',
             -module => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
             -input_ids => [{}],
             -parameters => {
#                             'species_tree_input_file' => $self->o('species_tree_input_file'),   # empty by default, but if nonempty this file will be used instead of tree generation from genome_db
#                             'species_tree_string' => '',
                            },
             -hive_capacity => -1,   # to allow for parallelization
             -wait_for => [$self->o('wait_for')],
             -flow_into  => {
                             3 => { 'mysql:////meta' => { 'meta_key' => $self->o('species_tree_meta_key'), 'meta_value' => '#species_tree_string#' } },
                             1 => ['CAFE_species_tree'],
                            },
            },

            {
             -logic_name => 'CAFE_species_tree',
             -module => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CAFESpeciesTree',
             -parameters => {
                             'cafe_species' => $self->o('cafe_species'),
                             'species_tree_meta_key' => $self->o('species_tree_meta_key'),
                            },
             -hive_capacity => -1, # to allow for parallelization
             -flow_into => {
                            1 => ['CAFE_table'],
                           },
            },

            {
             -logic_name => 'CAFE_table',
             -module => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CAFETable',
             -parameters => {
                             'work_dir'     => $self->o('work_dir'),
                             'cafe_species' => $self->o('cafe_species'),
                             'mlss_id'      => $self->o('mlss_id'),
                             'type'         => $self->o('type'),   # [nc|prot]
                             'perFamTable'  => $self->o('per_family_table'),
                            },
             -hive_capacity => -1,
             -flow_into => {
                            2 => ['CAFE_analysis'],
                           },
            },

            {
             -logic_name => 'CAFE_analysis',
             -module => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CAFEAnalysis',
             -parameters => {
                             'work_dir'             => $self->o('work_dir'),
                             'cafe_lambdas'         => $self->o('cafe_lambdas'),
#                             'cafe_struct_taxons'  => $self->o('cafe_'),
                             'cafe_struct_tree_str' => $self->o('cafe_struct_tree_str'),
                             'mlss_id'              => $self->o('mlss_id'),
                             'cafe_shell'           => $self->o('cafe_shell'),
                            },
             -rc_id => 300,
             -hive_capacity => -1,
             -flow_into => {
                            3 => {
                                  'mysql:////meta' => { 'meta_key' => 'cafe_lambda', 'meta_value' => '#cafe_lambda#' },
                                  'mysql:////meta' => { 'meta_key' => 'cafe_table_file', 'meta_value' => '#cafe_table_file#' },
                                  'mysql:////meta' => { 'meta_key' => 'CAFE_tree_string', 'meta_value' => '#cafe_tree_string#' },
                                 },
                           },
             -priority => 10,
            },
           ]
}

1;
