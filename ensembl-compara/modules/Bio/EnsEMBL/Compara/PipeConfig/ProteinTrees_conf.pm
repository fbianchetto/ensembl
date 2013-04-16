=heada LICENSE

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

  Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf

=head1 DESCRIPTION

    The PipeConfig file for ProteinTrees pipeline that should automate most of the pre-execution tasks.

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara CVS repositories before each new release

    #2. you may need to update 'schema_version' in meta table to the current release number in ensembl-hive/sql/tables.sql

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf -password <your_password> -mlss_id <your_current_PT_mlss_id>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output

=head2 rel.63 stats

    sequences to cluster:       1,198,678           [ SELECT count(*) from sequence; ]
    reused core dbs:            48                  [ SELECT count(*) FROM analysis JOIN job USING(analysis_id) WHERE logic_name='paf_table_reuse'; ]
    newly loaded core dbs:       5                  [ SELECT count(*) FROM analysis JOIN job USING(analysis_id) WHERE logic_name='load_fresh_members'; ]

    total running time:         8.7 days            [ SELECT (UNIX_TIMESTAMP(max(died))-UNIX_TIMESTAMP(min(born)))/3600/24 FROM worker;  ]  # NB: stable_id mapping phase not included
    blasting time:              1.9 days            [ SELECT (UNIX_TIMESTAMP(max(died))-UNIX_TIMESTAMP(min(born)))/3600/24 FROM worker JOIN analysis USING (analysis_id) WHERE logic_name='blastp_with_reuse'; ]

=head2 rel.62 stats

    sequences to cluster:       1,192,544           [ SELECT count(*) from sequence; ]
    reused core dbs:            46                  [ number of 'load_reuse_members' jobs ]
    newly loaded core dbs:       7                  [ number of 'load_fresh_members' jobs ]

    total running time:         6 days              [ SELECT (UNIX_TIMESTAMP(max(died))-UNIX_TIMESTAMP(min(born)))/3600/24 FROM hive;  ]
    blasting time:              2.7 days            [ SELECT (UNIX_TIMESTAMP(max(died))-UNIX_TIMESTAMP(min(born)))/3600/24 FROM hive JOIN analysis USING (analysis_id) WHERE logic_name='blastp_with_reuse'; ]

=head2 rel.61 stats

    sequences to cluster:       1,173,469           [ SELECT count(*) from sequence; ]
    reused core dbs:            46                  [ number of 'load_reuse_members' jobs ]
    newly loaded core dbs:       6                  [ number of 'load_fresh_members' jobs ]

    total running time:         6 days              [ SELECT (UNIX_TIMESTAMP(max(died))-UNIX_TIMESTAMP(min(born)))/3600/24 FROM hive;  ]
    blasting time:              1.4 days            [ SELECT (UNIX_TIMESTAMP(max(died))-UNIX_TIMESTAMP(min(born)))/3600/24 FROM hive JOIN analysis USING (analysis_id) WHERE logic_name like 'blast%' or logic_name like 'SubmitPep%'; ]

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=head1 MAINTAINER

$Author: mm14 $

=head VERSION

$Revision: 1.69 $

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

    # parameters that are likely to change from execution to another:
#       'mlss_id'               => 40077,   # it is very important to check that this value is current (commented out to make it obligatory to specify)
        'release'               => '67',
        'rel_suffix'            => '',    # an empty string by default, a letter otherwise
        'work_dir'              => '/lustre/scratch101/ensembl/'.$self->o('ENV', 'USER').'/protein_trees_'.$self->o('rel_with_suffix'),
        'do_not_reuse_list'     => [ ],     # names of species we don't want to reuse this time

    # dependent parameters:
        'rel_with_suffix'       => $self->o('release').$self->o('rel_suffix'),
        'pipeline_name'         => 'PT_'.$self->o('rel_with_suffix'),   # name the pipeline to differentiate the submitted processes
        'fasta_dir'             => $self->o('work_dir') . '/blast_db',  # affects 'dump_subset_create_blastdb' and 'blastp_with_reuse'
        'cluster_dir'           => $self->o('work_dir') . '/cluster',

    # blast parameters:
        'blast_options'             => '-filter none -span1 -postsw -V=20 -B=20 -sort_by_highscore -warnings -cpus 1',
        'blast_tmp_dir'             => '',  # if empty, will use Blast Analysis' default

        'protein_members_range'     => 100000000, # highest member_id for a protein member

    # clustering parameters:
        'outgroups'                     => [127],   # affects 'hcluster_dump_input_per_genome'
        'clustering_max_gene_halfcount' => 750,     # (half of the previously used 'clutering_max_gene_count=1500) affects 'hcluster_run'

    # tree building parameters:
        'tree_max_gene_count'       => 400,     # affects 'mcoffee' and 'mcoffee_himem'
        'use_exon_boundaries'       => 0,       # affects 'mcoffee' and 'mcoffee_himem'
        'use_genomedb_id'           => 0,       # affects 'njtree_phyml' and 'ortho_tree'
        'species_tree_input_file'   => '',      # you can define your own species_tree for 'njtree_phyml' and 'ortho_tree'

    # homology_dnds parameters:
        'codeml_parameters_file'    => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/protein_trees.codeml.ctl.hash',      # used by 'homology_dNdS'
        'taxlevels'                 => ['Theria', 'Sauria', 'Tetraodontiformes'],
        'filter_high_coverage'      => 1,   # affects 'group_genomes_under_taxa'

    # executable locations:
        'wublastp_exe'              => '/usr/local/ensembl/bin/wublastp',
        'hcluster_exe'              => '/software/ensembl/compara/hcluster/hcluster_sg',
        'mcoffee_exe'               => '/software/ensembl/compara/tcoffee-7.86b/t_coffee',
        'mafft_exe'                 => '/software/ensembl/compara/mafft-6.707/bin/mafft',
        'mafft_binaries'            => '/software/ensembl/compara/mafft-6.707/binaries',
        'sreformat_exe'             => '/usr/local/ensembl/bin/sreformat',
        'treebest_exe'              => '/software/ensembl/compara/treebest.doubletracking',
        'quicktree_exe'             => '/software/ensembl/compara/quicktree_1.1/bin/quicktree',
        'buildhmm_exe'              => '/software/ensembl/compara/hmmer3/hmmer-3.0/src/hmmbuild',
        'codeml_exe'                => '/usr/local/ensembl/bin/codeml',

    # hive_capacity values for some analyses:
        'reuse_capacity'            =>   4,
        'blast_factory_capacity'    =>  50,
        'store_sequences_capacity'  => 200,
        'blastp_capacity'           => 450,
        'mcoffee_capacity'          => 600,
        'njtree_phyml_capacity'     => 400,
        'ortho_tree_capacity'       => 100,
        'quick_tree_break_capacity' => 100,
        'build_hmm_capacity'        => 200,
        'merge_supertrees_capacity' => 100,
        'other_paralogs_capacity'   => 100,
        'homology_dNdS_capacity'    => 200,
        'qc_capacity'               =>   4,

    # connection parameters to various databases:

        'pipeline_db' => {                      # the production database itself (will be created)
            -host   => 'compara3',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),
            -dbname => $self->o('ENV', 'USER').'_compara_homology_'.$self->o('rel_with_suffix'),
        },

        'master_db' => {                        # the master database for synchronization of various ids
            -host   => 'compara1',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
            -dbname => 'sf5_ensembl_compara_master',
        },

        'staging_loc1' => {                     # general location of half of the current release core databases
            -host   => 'ens-staging',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
        },

        'staging_loc2' => {                     # general location of the other half of the current release core databases
            -host   => 'ens-staging2',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
        },

        'livemirror_loc' => {                   # general location of the previous release core databases (for checking their reusability)
            -host   => 'ens-livemirror',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
        },


        # "production mode"
        'reuse_core_sources_locs'   => [ $self->o('livemirror_loc') ],
        'curr_core_sources_locs'    => [ $self->o('staging_loc1'), $self->o('staging_loc2'), ],
        'prev_release'              => 0,   # 0 is the default and it means "take current release number and subtract 1"
        'reuse_db' => {   # usually previous release database on compara1
           -host   => 'compara3',
           -port   => 3306,
           -user   => 'ensro',
           -pass   => '',
           -dbname => 'mp12_ensembl_compara_66',
        },

        ## mode for testing the non-Blast part of the pipeline: reuse all Blasts
        #'reuse_core_sources_locs' => [ $self->o('staging_loc1'), $self->o('staging_loc2'), ],
        #'curr_core_sources_locs'  => [ $self->o('staging_loc1'), $self->o('staging_loc2'), ],
        #'prev_release'            => $self->o('release'),
        #'reuse_db' => {   # current release if we are testing after production
        #    -host   => 'compara1',
        #    -port   => 3306,
        #    -user   => 'ensro',
        #    -pass   => '',
        #    -dbname => 'sf5_ensembl_compara_61',
        #},

    };
}


sub pipeline_create_commands {
    my ($self) = @_;
    return [
        @{$self->SUPER::pipeline_create_commands},  # here we inherit creation of database, hive tables and compara tables
        
        'mkdir -p '.$self->o('fasta_dir'),

            # perform "lfs setstripe" only if lfs is runnable and the directory is on lustre:
        'which lfs && lfs getstripe '.$self->o('fasta_dir').' >/dev/null 2>/dev/null && lfs setstripe '.$self->o('fasta_dir').' -c -1 || echo "Striping is not available on this system" ',

        'mkdir -p '.$self->o('cluster_dir'),
    ];
}


sub resource_classes {
    my ($self) = @_;
    return {
         0 => { -desc => 'default',          'LSF' => '' },
         1 => { -desc => '500Mb_job',        'LSF' => '-C0 -M500000   -R"select[mem>500]   rusage[mem=500]"' },
         2 => { -desc => '1Gb_job',          'LSF' => '-C0 -M1000000  -R"select[mem>1000]  rusage[mem=1000]"' },
         3 => { -desc => '2Gb_job',          'LSF' => '-C0 -M2000000  -R"select[mem>2000]  rusage[mem=2000]"' },
         5 => { -desc => '8Gb_job',          'LSF' => '-C0 -M8000000  -R"select[mem>8000]  rusage[mem=8000]"' },
         7 => { -desc => '24Gb_job',         'LSF' => '-C0 -M24000000 -R"select[mem>24000] rusage[mem=24000]" -q long' },
    };
}


sub pipeline_analyses {
    my ($self) = @_;
    return [

# ---------------------------------------------[copy tables from master and fix the offsets]---------------------------------------------

        {   -logic_name => 'copy_table_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'db_conn'      => $self->o('master_db'),
                'inputlist'    => [ 'ncbi_taxa_node', 'ncbi_taxa_name', 'method_link', 'species_set', 'method_link_species_set' ],
                'column_names' => [ 'table' ],
                'input_id'     => { 'src_db_conn' => '#db_conn#', 'table' => '#table#' },
                'fan_branch_code' => 2,
            },
		-input_ids  => [ { } ],
            -flow_into => {
                '2->A' => [ 'copy_table'  ],
                'A->1' => [ 'innodbise_table_factory' ],     # backbone
            },
        },

        {   -logic_name    => 'copy_table',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters    => {
                'mode'          => 'overwrite',
                'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
            },
            -hive_capacity => 1,    # linearize all copying to make sure we don't go against foreign keys
        },

# ---------------------------------------------[turn all tables except 'genome_db' to InnoDB]---------------------------------------------

        {   -logic_name => 'innodbise_table_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'inputquery'      => "SELECT table_name FROM information_schema.tables WHERE table_schema ='".$self->o('pipeline_db','-dbname')."' AND table_name!='meta' AND engine='MyISAM' ",
                'fan_branch_code' => 2,
            },
            -flow_into => {
                '2->A' => [ 'innodbise_table'  ],
                'A->1' => [ 'load_genomedb_factory' ],           # backbone
            },
        },

        {   -logic_name    => 'innodbise_table',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters    => {
                'sql'         => "ALTER TABLE #table_name# ENGINE=InnoDB",
            },
            -hive_capacity => 10,
        },

# ---------------------------------------------[load GenomeDB entries from master+cores]---------------------------------------------

        {   -logic_name => 'load_genomedb_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory',
            -parameters => {
                'compara_db'            => $self->o('master_db'),   # that's where genome_db_ids come from
                'mlss_id'               => $self->o('mlss_id'),

                'adaptor_name'          => 'MethodLinkSpeciesSetAdaptor',
                'adaptor_method'        => 'fetch_by_dbID',
                'method_param_list'     => [ '#mlss_id#' ],
                'object_method'         => 'species_set',

                'column_names2getters'  => { 'genome_db_id' => 'dbID', 'species_name' => 'name', 'assembly_name' => 'assembly', 'genebuild' => 'genebuild', 'locator' => 'locator' },

                'fan_branch_code'       => 2,
            },
            -flow_into => {
                2 => [ 'load_genomedb' ],           # fan
                1 => [ 'load_genomedb_funnel' ],    # backbone
            },
        },

        {   -logic_name => 'load_genomedb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
            -parameters => {
                'registry_dbs'  => $self->o('curr_core_sources_locs'),
            },
            -hive_capacity => 1,    # they are all short jobs, no point doing them in parallel
            -flow_into => {
                1 => [ 'check_reusability' ],   # each will flow into another one
            },
        },

        {   -logic_name => 'load_genomedb_funnel',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -wait_for => [ 'load_genomedb' ],
            -flow_into => {
                1 => [ 'make_species_tree', 'generate_reuse_ss' ],  # "backbone"
            },
        },


# ---------------------------------------------[generate an empty species_set for reuse (to be filled in at a later stage) ]---------

        {   -logic_name => 'generate_reuse_ss',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql' => [  "INSERT INTO species_set (genome_db_id) SELECT genome_db_id FROM genome_db LIMIT 1",   # inserts a dummy pair (auto_increment++, any_genome_db_id) into the table
                            "DELETE FROM species_set WHERE species_set_id=#_insert_id_0#", # will delete the row previously inserted, but keep the auto_increment
                ],
            },
            -flow_into => {
                1 => [ 'accumulate_reuse_ss' ],
                2 => { 'mysql:////meta' => { 'meta_key' => 'reuse_ss_id', 'meta_value' => '#_insert_id_0#' } },     # dynamically record it as a pipeline-wide parameter
            },
        },

# ---------------------------------------------[load species tree]-------------------------------------------------------------------

        {   -logic_name    => 'make_species_tree',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
            -parameters    => {
                'species_tree_input_file' => $self->o('species_tree_input_file'),   # empty by default, but if nonempty this file will be used instead of tree generation from genome_db
                'mlss_id'                 => $self->o('mlss_id'),
            },
            -hive_capacity => -1,   # to allow for parallelization
            -flow_into  => {
                3 => { 'mysql:////method_link_species_set_tag' => { 'method_link_species_set_id' => '#mlss_id#', 'tag' => 'species_tree', 'value' => '#species_tree_string#' } },
            },
        },

# ---------------------------------------------[filter genome_db entries into reusable and non-reusable ones]------------------------

        {   -logic_name => 'check_reusability',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::CheckGenomedbReusability',
            -parameters => {
                'reuse_db'          => $self->o('reuse_db'),
                'registry_dbs'      => $self->o('reuse_core_sources_locs'),
                'release'           => $self->o('release'),
                'prev_release'      => $self->o('prev_release'),
                'do_not_reuse_list' => $self->o('do_not_reuse_list'),
            },
            -wait_for => [ 'generate_reuse_ss' ],
            -hive_capacity => 10,    # allow for parallel execution
            -rc_id => 1,
            -flow_into => {
                2 => {
                    'sequence_table_reuse'              => undef,
                    'paf_table_reuse'                   => undef,
                    'mysql:////species_set'             => { 'genome_db_id' => '#genome_db_id#', 'species_set_id' => '#reuse_ss_id#' },
                },
                3 => [ 'load_fresh_members', 'paf_create_empty_table' ],
            },
        },

        {   -logic_name    => 'accumulate_reuse_ss',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',     # a non-standard use of JobFactory for iterative insertion
            -parameters => {
                'inputquery'      => 'SELECT "reuse_ss_csv" meta_key, GROUP_CONCAT(genome_db_id) meta_value FROM species_set WHERE species_set_id=#reuse_ss_id#',
                'fan_branch_code' => 2,
            },
            -wait_for => [ 'check_reusability' ],
            -hive_capacity => -1,   # to allow for parallelization
            -flow_into => {
                2 => [ 'mysql:////meta' ],
                '1->A' => {
                    'hcluster_merge_inputs' => [{'ext' => 'txt'}, {'ext' => 'cat'}],
                },
                'A->1' => [ 'hcluster_run' ],
            },
        },

# ---------------------------------------------[reuse members and pafs]--------------------------------------------------------------

        {   -logic_name => 'sequence_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                            'db_conn'    => $self->o('reuse_db'),
                            'inputquery' => 'SELECT s.* FROM sequence s JOIN member USING (sequence_id) WHERE sequence_id<='.$self->o('protein_members_range').' AND genome_db_id = #genome_db_id#',
                            'fan_branch_code' => 2,
            },
            -can_be_empty  => 1,
            -hive_capacity => $self->o('reuse_capacity'),
            -rc_id => 1,
            -flow_into => {
                2 => [ 'mysql:////sequence' ],
                1 => [ 'member_table_reuse' ],
            },
        },

        {   -logic_name => 'member_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => $self->o('reuse_db'),
                'table'         => 'member',
                'where'         => 'member_id<='.$self->o('protein_members_range').' AND genome_db_id = #genome_db_id#',
                'mode'          => 'insertignore',
		    },
            -can_be_empty  => 1,
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => {
                1 => [ 'subset_table_reuse', 'sequence_cds_table_reuse', 'sequence_exon_bounded_table_reuse' ],   # n_reused_species
            },
        },

        {   -logic_name => 'subset_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => $self->o('reuse_db'),
                'table'         => 'subset',
                'mode'          => 'insertignore',
                'where'         => 'description LIKE "gdb:#genome_db_id# %"',
            },
            -can_be_empty  => 1,
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => {
                1 => [ 'subset_member_table_reuse' ],    # n_reused_species
            },
        },

        {   -logic_name => 'subset_member_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                            'db_conn'    => $self->o('reuse_db'),
                            'inputquery' => "SELECT sm.* FROM subset_member sm JOIN subset USING (subset_id) WHERE member_id<=".$self->o('protein_members_range')." AND description LIKE 'gdb:#genome_db_id# %'",
                            'fan_branch_code' => 2,
            },
            -can_be_empty  => 1,
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => {
                2 => [ 'mysql:////subset_member' ],
                1 => [ 'dump_subset_create_blastdb' ],
            },
        },

        {   -logic_name => 'sequence_cds_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                            'db_conn'    => $self->o('reuse_db'),
                            'inputquery' => 'SELECT s.* FROM sequence_cds s JOIN member USING (member_id) WHERE genome_db_id = #genome_db_id#',
                            'fan_branch_code' => 2,
            },
            -can_be_empty  => 1,
            -hive_capacity => $self->o('reuse_capacity'),
            -rc_id => 1,
            -priority => -20,
            -flow_into => {
                2 => [ 'mysql:////sequence_cds' ],
            },
        },

        {   -logic_name => 'sequence_exon_bounded_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                            'db_conn'    => $self->o('reuse_db'),
                            'inputquery' => 'SELECT s.* FROM sequence_exon_bounded s JOIN member USING (member_id) WHERE genome_db_id = #genome_db_id#',
                            'fan_branch_code' => 2,
            },
            -can_be_empty  => 1,
            -hive_capacity => $self->o('reuse_capacity'),
            -rc_id => 1,
            -priority => -20,
            -flow_into => {
                2 => [ 'mysql:////sequence_exon_bounded' ],
            },
        },

        {   -logic_name => 'paf_table_reuse',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::MySQLTransfer',
            -parameters => {
                'src_db_conn'   => $self->o('reuse_db'),
                'table'         => 'peptide_align_feature_#per_genome_suffix#',
                'filter_cmd'    => 'sed "s/ENGINE=MyISAM/ENGINE=InnoDB/"',
                'where'         => 'hgenome_db_id IN (#reuse_ss_csv#)',
            },
            -wait_for   => [ 'accumulate_reuse_ss' ],     # have to wait until reuse_ss_csv is computed
            -hive_capacity => $self->o('reuse_capacity'),
            -can_be_empty  => 1,
            -priority => -10,
        },

# ---------------------------------------------[load the rest of members]------------------------------------------------------------

        {   -logic_name => 'load_fresh_members',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadMembers',
            -parameters => { },
            -wait_for => [ 'check_reusability', 'subset_table_reuse', 'subset_member_table_reuse', 'member_table_reuse', 'sequence_table_reuse' ],
            -hive_capacity => -1,
            -can_be_empty  => 1,
            -rc_id => 2,
            -flow_into => [ 'store_sequences_factory', 'dump_subset_create_blastdb' ],
        },

        {   -logic_name => 'store_sequences_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::PeptideMemberGroupingFactory',
            -parameters => { },
            -hive_capacity => -1,
            -rc_id => 1,
            -priority => -20,
            -flow_into => {
                2 => [ 'store_sequences' ],
            },
        },

        {   -logic_name => 'store_sequences',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::FlowMemberSeq',
            -parameters => { },
            -hive_capacity => $self->o('store_sequences_capacity'),
            -rc_id => 2,
            -priority => -20,
            -flow_into => {
                2 => [ 'mysql:////sequence_cds' ],
                3 => [ 'mysql:////sequence_exon_bounded' ],
            },
        },


        {   -logic_name => 'paf_create_empty_table',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SqlCmd',
            -parameters => {
                'sql' => [  'CREATE TABLE IF NOT EXISTS peptide_align_feature_#per_genome_suffix# LIKE peptide_align_feature',
                            'ALTER TABLE peptide_align_feature_#per_genome_suffix# DISABLE KEYS',
                ],
            },
            -batch_size    =>  100,  # they can be really, really short
            -can_be_empty  => 1,
            -hive_capacity => -1,
            -priority => -10,
        },


# ---------------------------------------------[create and populate blast analyses]--------------------------------------------------

        {   -logic_name => 'dump_subset_create_blastdb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::DumpSubsetCreateBlastDB',
            -parameters => {
                'fasta_dir'                 => $self->o('fasta_dir'),
            },
            -batch_size    =>  20,  # they can be really, really short
            -hive_capacity => -1,
            -flow_into => {
                1 => [ 'blast_factory' ],   # n_species
            },
        },

        {   -logic_name => 'blast_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ObjectFactory',
            -parameters => {
                'adaptor_name'          => 'SubsetAdaptor',
                'adaptor_method'        => 'fetch_by_description_pattern',
                'method_param_list'     => [ 'gdb:#genome_db_id# % translations' ],
                'object_method'         => 'member_id_list',
                'column_names'          => [ 'member_id' ],
                'fan_branch_code'       => 2,
            },
            -hive_capacity => $self->o('blast_factory_capacity'),
            -flow_into => {
                '2->A' => [ 'blastp_with_reuse' ],  # fan n_members
                'A->1' => [ 'hcluster_dump_input_per_genome' ],   # n_species
            },
        },

        {   -logic_name         => 'blastp_with_reuse',
            -module             => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BlastpWithReuse',
            -parameters         => {
                'mlss_id'                   => $self->o('mlss_id'),
                'reuse_db'                  => $self->o('reuse_db'),
                'blast_options'             => $self->o('blast_options'),
                'blast_tmp_dir'             => $self->o('blast_tmp_dir'),
                'fasta_dir'                 => $self->o('fasta_dir'),
                'wublastp_exe'              => $self->o('wublastp_exe'),
            },
            -wait_for => [ 'load_fresh_members', 'dump_subset_create_blastdb', 'paf_table_reuse', 'paf_create_empty_table' ],
            -batch_size    =>  40,
            -rc_id         => 1,
            -hive_capacity => $self->o('blastp_capacity'),
        },

# ---------------------------------------------[clustering step]---------------------------------------------------------------------

        {   -logic_name => 'hcluster_dump_input_per_genome',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HclusterPrepare',
            -parameters => {
                'mlss_id'       => $self->o('mlss_id'),
                'outgroups'     => $self->o('outgroups'),
                'cluster_dir'   => $self->o('cluster_dir'),
            },
            -hive_capacity => $self->o('reuse_capacity'),
            -flow_into => {
                1 => [ 'per_genome_clusterset_qc' ],  # n_species
            },
        },

        {   -logic_name    => 'hcluster_merge_inputs',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'cluster_dir'   => $self->o('cluster_dir'),
                'cmd'           => 'cat #cluster_dir#/*.hcluster.#ext# > #cluster_dir#/hcluster.#ext#',
            },
            -wait_for => [ 'hcluster_dump_input_per_genome' ],
            -hive_capacity => -1,   # to allow for parallelization
        },

        {   -logic_name    => 'hcluster_run',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -parameters    => {
                'clustering_max_gene_halfcount' => $self->o('clustering_max_gene_halfcount'),
                'cluster_dir'                   => $self->o('cluster_dir'),
                'hcluster_exe'                  => $self->o('hcluster_exe'),
                'cmd'                           => '#hcluster_exe# -m #clustering_max_gene_halfcount# -w 0 -s 0.34 -O -C #cluster_dir#/hcluster.cat -o #cluster_dir#/hcluster.out #cluster_dir#/hcluster.txt',
            },
            -hive_capacity => -1,   # to allow for parallelization
            -flow_into => {
                1 => [ 'hcluster_parse_output' ],   # backbone
            },
            -rc_id => 7,
        },


        {   -logic_name => 'hcluster_parse_output',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HclusterParseOutput',
            -parameters => {
                'mlss_id'                   => $self->o('mlss_id'),
                'cluster_dir'               => $self->o('cluster_dir'),
            },
            -hive_capacity => -1,
            -rc_id => 3,
            -flow_into => {
                '1->A' => [ 'overall_clusterset_qc' ], 
                '2->A' => [ 'mcoffee' ],                 # fan n_clusters
                'A->1' => [ 'dummy_wait_alltrees' ],    # backbone
            },
        },

# ---------------------------------------------[a QC step before main loop]----------------------------------------------------------

        {   -logic_name => 'overall_clusterset_qc',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::OverallGroupsetQC',
            -parameters => {
                'reuse_db'                  => $self->o('reuse_db'),
                'cluster_dir'               => $self->o('cluster_dir'),
                'groupset_tag'              => 'ClustersetQC',
            },
            -hive_capacity  => $self->o('qc_capacity'),
            -rc_id          => 1,
        },

        {   -logic_name => 'per_genome_clusterset_qc',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::PerGenomeGroupsetQC',
            -parameters => {
                'reuse_db'                  => $self->o('reuse_db'),
                'groupset_tag'              => 'Clusterset',
            },
            -wait_for => [ 'hcluster_parse_output' ],
            -hive_capacity => $self->o('qc_capacity'),
            -flow_into => {
                1 => [ 'per_genome_genetreeset_qc' ],   # n_species
            },
        },

# ---------------------------------------------[main tree creation loop]-------------------------------------------------------------

        {   -logic_name => 'mcoffee',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MCoffee',
            -parameters => {
                'method'                    => 'cmcoffee',      # presumably, at the moment it refers to the 'initial' method
                'use_exon_boundaries'       => $self->o('use_exon_boundaries'),
                'max_gene_count'            => $self->o('tree_max_gene_count'),
                'mcoffee_exe'               => $self->o('mcoffee_exe'),
                'mafft_exe'                 => $self->o('mafft_exe'),
                'mafft_binaries'            => $self->o('mafft_binaries'),
            },
            -wait_for => [ 'store_sequences', 'sequence_cds_table_reuse', 'sequence_exon_bounded_table_reuse', 'overall_clusterset_qc', 'per_genome_clusterset_qc' ],    # funnel
            -hive_capacity        => $self->o('mcoffee_capacity'),
            -rc_id => 3,
            -priority => 30,
            -flow_into => {
               -1 => [ 'mcoffee_himem' ],  # MEMLIMIT
                1 => [ 'njtree_phyml' ],
                3 => [ 'quick_tree_break' ],
            },
        },

        {   -logic_name => 'mcoffee_himem',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MCoffee',
            -parameters => {
                'method'                    => 'cmcoffee',      # presumably, at the moment it refers to the 'initial' method
                'use_exon_boundaries'       => $self->o('use_exon_boundaries'),
                'max_gene_count'            => $self->o('tree_max_gene_count'),
                'mcoffee_exe'               => $self->o('mcoffee_exe'),
                'mafft_exe'                 => $self->o('mafft_exe'),
                'mafft_binaries'            => $self->o('mafft_binaries'),
            },
            -hive_capacity        => $self->o('mcoffee_capacity'),
            -priority => 35,
            -flow_into => {
                1 => [ 'njtree_phyml' ],
                3 => [ 'quick_tree_break' ],
            },
            -rc_id => 5,
        },

        {   -logic_name => 'njtree_phyml',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::NJTREE_PHYML',
            -parameters => {
                'cdna'                      => 1,
                'bootstrap'                 => 1,
                'use_genomedb_id'           => $self->o('use_genomedb_id'),
                'treebest_exe'              => $self->o('treebest_exe'),
                'mlss_id'                   => $self->o('mlss_id'),
            },
            -hive_capacity        => $self->o('njtree_phyml_capacity'),
            -rc_id => 3,
            -priority => 20,
            -flow_into => {
                1 => [ 'ortho_tree', 'build_HMM_aa', 'build_HMM_cds' ],
                2 => [ 'njtree_phyml' ],
            },
        },

        {   -logic_name => 'ortho_tree',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OrthoTree',
            -parameters => {
                'use_genomedb_id'   => $self->o('use_genomedb_id'),
                'tree_id_str'       => 'protein_tree_id',
                'tag_split_genes'   => 1,
                'mlss_id'                   => $self->o('mlss_id'),
            },
            -hive_capacity        => $self->o('ortho_tree_capacity'),
            -rc_id => 1,
            -priority => 10,
        },

        {   -logic_name => 'build_HMM_aa',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BuildHMM',
            -parameters => {
                'buildhmm_exe'      => $self->o('buildhmm_exe'),
                'sreformat_exe'     => $self->o('sreformat_exe'),
            },
            -hive_capacity        => $self->o('build_hmm_capacity'),
            -rc_id => 1,
        },

        {   -logic_name => 'build_HMM_cds',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BuildHMM',
            -parameters => {
                'cdna'              => 1,
                'buildhmm_exe'      => $self->o('buildhmm_exe'),
                'sreformat_exe'     => $self->o('sreformat_exe'),
            },
            -hive_capacity        => $self->o('build_hmm_capacity'),
            -rc_id => 1,
        },

        {   -logic_name => 'quick_tree_break',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::QuickTreeBreak',
            -parameters => {
                'mlss_id'           => $self->o('mlss_id'),
                'quicktree_exe'     => $self->o('quicktree_exe'),
                'sreformat_exe'     => $self->o('sreformat_exe'),
            },
            -hive_capacity        => $self->o('quick_tree_break_capacity'),
            -rc_id     => 1,
            -priority  => 50,
            -flow_into => [ 'other_paralogs' ],
        },

        {   -logic_name     => 'merge_supertrees',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SuperTreeMerge',
            -parameters     => {
                'tree_id_str'       => 'protein_tree_id',
            },
            -hive_capacity  => $self->o('merge_supertrees_capacity'),
            -rc_id          => 1,
            -priority       => 10,
        },
 
        {   -logic_name     => 'other_paralogs',
            -module         => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OtherParalogs',
            -parameters     => {
                'use_genomedb_id'   => $self->o('use_genomedb_id'),
                'dataflow_subclusters' => 1,
                'tree_id_str'       => 'protein_tree_id',
                'mlss_id'           => $self->o('mlss_id'),
            },
            -hive_capacity  => $self->o('other_paralogs_capacity'),
            -rc_id          => 1,
            -priority       => 10,
            -flow_into => {
                '2->A' => [ 'mcoffee' ],
                'A->1' => [ 'merge_supertrees' ],
            },
        },

        {   -logic_name     => 'dummy_wait_alltrees',
            -module         => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -parameters     => {},
            -flow_into      => [ 'overall_genetreeset_qc' ],  # backbone
        },


# ---------------------------------------------[a QC step after main loop]----------------------------------------------------------

        {   -logic_name => 'overall_genetreeset_qc',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::OverallGroupsetQC',
            -parameters => {
                'reuse_db'                  => $self->o('reuse_db'),
                'cluster_dir'               => $self->o('cluster_dir'),
                'groupset_tag'              => 'GeneTreesetQC',
            },
            -hive_capacity => $self->o('qc_capacity'),
            -rc_id          => 1,
            -flow_into => {
                1 => [ 'group_genomes_under_taxa' ],    # backbone
            },
        },

        {   -logic_name => 'per_genome_genetreeset_qc',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::PerGenomeGroupsetQC',
            -parameters => {
                'reuse_db'                  => $self->o('reuse_db'),
                'groupset_tag'              => 'GeneTreeset',
            },
            -wait_for => [ 'dummy_wait_alltrees' ],
            -hive_capacity => $self->o('qc_capacity'),
        },

# ---------------------------------------------[homology step]-----------------------------------------------------------------------

        {   -logic_name => 'group_genomes_under_taxa',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::GroupGenomesUnderTaxa',
            -parameters => {
                'mlss_id'               => $self->o('mlss_id'),
                'taxlevels'             => $self->o('taxlevels'),
                'filter_high_coverage'  => $self->o('filter_high_coverage'),
            },
            -wait_for => [ 'per_genome_genetreeset_qc' ],   # funnel
            -hive_capacity => -1,
            -flow_into => {
                2 => [ 'homology_mlss_factory' ],
            },
        },

        {   -logic_name => 'homology_mlss_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MLSSIDFactory',
            -parameters => {
		    'method_link_types'  => ['ENSEMBL_ORTHOLOGUES', 'ENSEMBL_PARALOGUES'],
		},
            -hive_capacity => -1,
            -flow_into => {
                2 => [ 'homology_dNdS_factory' ],
            },
        },

        {   -logic_name => 'homology_dNdS_factory',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyGroupingFactory',
            -hive_capacity => $self->o('homology_dNdS_capacity'),
            -flow_into => {
                'A->1' => [ 'threshold_on_dS' ],
                '2->A' => [ 'homology_dNdS' ],
            },
        },

        {   -logic_name => 'homology_dNdS',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Homology_dNdS',
            -parameters => {
                'codeml_parameters_file'    => $self->o('codeml_parameters_file'),
                'codeml_exe'                => $self->o('codeml_exe'),
            },
            -hive_capacity        => $self->o('homology_dNdS_capacity'),
            -failed_job_tolerance => 2,
            -rc_id => 1,
        },

        {   -logic_name => 'threshold_on_dS',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Threshold_on_dS',
            -hive_capacity => $self->o('homology_dNdS_capacity'),
        },

    ];
}

1;

