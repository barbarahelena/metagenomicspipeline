#!/usr/bin/env nextflow

nextflow.enable.types = true
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    metagenomicspipeline
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/barbarahelena/metagenomicspipeline
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { METAGENOMICSPIPELINE    } from './workflows/metagenomicspipeline'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_metagenomicspipeline_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_metagenomicspipeline_pipeline'
include { genomeAttribute         } from './subworkflows/local/utils_metagenomicspipeline_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PARAMETERS
    Typed: command-line values are converted to these types at launch, and a wrong type,
    a missing file or an undeclared (misspelled) parameter stops the run before it starts.
    Infrastructure params read by config files (outdir, multiqc_title, config_profile_*, ...)
    are defined in nextflow.config. Keep defaults in sync with nextflow_schema.json.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

params {
    // Input (required for a run; optional here so --help works without them)
    input: Path?                            = null
    adapterlist: Path?                      = null

    // References for host read removal: --fasta, --bowtie2_index, or --genome (iGenomes)
    genome: String?                         = null
    genomes: Map                            = [:]    // set by conf/igenomes.config
    fasta: Path?                            = null
    bowtie2_index: Path?                    = null   // directory with the Bowtie2 index (*.bt2)

    // Skip steps
    skip_preprocessing: Boolean             = false
    skip_qualityfilter: Boolean             = false
    skip_hostfilter: Boolean                = false
    skip_subsampling: Boolean               = false
    skip_metaphlan: Boolean                 = false
    skip_humann: Boolean                    = false
    skip_kraken: Boolean                    = true
    skip_shortbred: Boolean                 = true

    // Preprocessing
    save_trimmed_fail: Boolean              = false
    fastp_cutright: Boolean                 = true
    fastp_windowsize: Integer               = 4
    fastp_meanquality: Integer              = 15
    fastp_length: Integer                   = 70
    perform_runmerging: Boolean             = false
    subsamplelevel: Integer                 = 20000000

    // Profiling
    humann_db: String                       = 'uniref90_ec_filtered_diamond'
    kraken2_db: Path?                       = null   // downloaded (--kraken2_dbname) when not given
    kraken2_dbname: String                  = 'standard_16gb'
    kraken2_save_reads: Boolean             = false
    kraken2_save_readclassifications: Boolean = false
    bracken_build: Boolean                  = false
    bracken_readlength: Integer             = 150
    bracken_kmerlength: Integer             = 35
    bracken_threshold: Integer              = 10

    // MultiQC
    multiqc_config: Path?                   = null
    multiqc_logo: Path?                     = null
    multiqc_methods_description: Path?      = null

    // Output and notifications (outdir and monochrome_logs are also set in nextflow.config, which config files read; config wins)
    outdir: String?                         = null
    publish_dir_mode: String                = 'copy'
    publish_mergedreads: String             = 'symlink'   // publish mode for host-filtered and merged reads
    email: String?                          = null
    email_on_fail: String?                  = null
    monochrome_logs: Boolean                = false

    // Generic
    help: String?                           = null   // --help, or --help <parameter> for one parameter
    help_full: Boolean                      = false
    show_hidden: Boolean                    = false
    version: Boolean                        = false
    validate_params: Boolean                = true
    plaintext_email: Boolean                = false
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:

    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    def ch_samples = PIPELINE_INITIALISATION (
        params.version,
        params.validate_params,
        args,
        params.outdir,
        params.input,
        params.perform_runmerging,
        params.help,
        params.help_full,
        params.show_hidden
    )

    //
    // References for host read removal: given directly, or from iGenomes with --genome
    //
    def fasta         = params.fasta ?: genomeAttribute(params.genomes, params.genome, 'fasta')
    def bowtie2_index = params.bowtie2_index ?: genomeAttribute(params.genomes, params.genome, 'bowtie2')
    if (!params.skip_preprocessing && !params.skip_hostfilter && !fasta && !bowtie2_index) {
        error "[metagenomicspipeline] Host read removal needs a reference: use --fasta, --bowtie2_index or --genome, or skip it with --skip_hostfilter."
    }

    //
    // WORKFLOW: Run main workflow
    //
    // The options METAGENOMICSPIPELINE uses, as a typed record (see MetagenomicsOptions in subworkflows/local/types.nf)
    def opts = record(
        outdir                           : params.outdir,
        adapterlist                      : params.adapterlist,
        fasta                            : fasta,
        bowtie2_index                    : bowtie2_index,
        skip_preprocessing               : params.skip_preprocessing,
        skip_qualityfilter               : params.skip_qualityfilter,
        skip_hostfilter                  : params.skip_hostfilter,
        skip_subsampling                 : params.skip_subsampling,
        skip_metaphlan                   : params.skip_metaphlan,
        skip_humann                      : params.skip_humann,
        skip_kraken                      : params.skip_kraken,
        skip_shortbred                   : params.skip_shortbred,
        save_trimmed_fail                : params.save_trimmed_fail,
        fastp_cutright                   : params.fastp_cutright,
        fastp_windowsize                 : params.fastp_windowsize,
        fastp_meanquality                : params.fastp_meanquality,
        fastp_length                     : params.fastp_length,
        perform_runmerging               : params.perform_runmerging,
        subsamplelevel                   : params.subsamplelevel,
        humann_db                        : params.humann_db,
        kraken2_db                       : params.kraken2_db,
        kraken2_dbname                   : params.kraken2_dbname,
        kraken2_save_reads               : params.kraken2_save_reads,
        kraken2_save_readclassifications : params.kraken2_save_readclassifications,
        bracken_build                    : params.bracken_build,
        bracken_readlength               : params.bracken_readlength,
        bracken_kmerlength               : params.bracken_kmerlength,
        bracken_threshold                : params.bracken_threshold,
        multiqc_config                   : params.multiqc_config,
        multiqc_logo                     : params.multiqc_logo,
        multiqc_methods_description      : params.multiqc_methods_description
    )

    def pipeline = METAGENOMICSPIPELINE (
        ch_samples,
        opts
    )

    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs
    )

    publish:
    fastqc        = pipeline.fastqc
    fastp         = pipeline.fastp
    bowtie2       = pipeline.bowtie2
    merged        = pipeline.merged
    subsampling   = pipeline.subsampling
    metaphlan     = pipeline.metaphlan
    humann        = pipeline.humann
    kraken2       = pipeline.kraken2
    bracken       = pipeline.bracken
    shortbred     = pipeline.shortbred
    multiqc       = pipeline.multiqc
    pipeline_info = pipeline.pipeline_info
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    WORKFLOW OUTPUTS: where each published channel goes, relative to --outdir
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

output {
    fastqc: Channel<Path>        { path 'fastqc' }
    fastp: Channel<Path>         { path 'fastp' }
    // Host-filtered and merged reads are large: symlinked by default (--publish_mergedreads)
    bowtie2: Channel<Path> {
        path 'bowtie2'
        mode params.publish_mergedreads
    }
    merged: Channel<Path> {
        path 'merged'
        mode params.publish_mergedreads
    }
    subsampling: Channel<Path>   { path 'subsampling' }
    metaphlan: Channel<Path>     { path 'metaphlan' }
    humann: Channel<Path>        { path 'humann' }
    kraken2: Channel<Path>       { path 'kraken2' }
    bracken: Channel<Path>       { path 'bracken' }
    shortbred: Channel<Path>     { path 'shortbred' }
    multiqc: Channel<Path>       { path 'multiqc' }
    pipeline_info: Channel<Path> { path 'pipeline_info' }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
