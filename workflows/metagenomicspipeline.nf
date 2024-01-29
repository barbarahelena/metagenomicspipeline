/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PRINT PARAMS SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryLog; paramsSummaryMap } from 'plugin/nf-validation'

def logo = NfcoreTemplate.logo(workflow, params.monochrome_logs)
def citation = '\n' + WorkflowMain.citation(workflow) + '\n'
def summary_params = paramsSummaryMap(workflow)

// Print parameter summary log to screen
log.info logo + paramsSummaryLog(workflow) + citation

WorkflowMetagenomicspipeline.initialise(params, log)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { FASTP                             } from '../modules/local/fastp'
include { BOWTIE2_ALIGN                     } from '../modules/local/bowtie2/align'
include { BOWTIE2_BUILD                     } from '../modules/local/bowtie2/build'
include { SAMTOOLS_INDEX                    } from '../modules/local/samtools/index'
include { SAMTOOLS_STATS                    } from '../modules/local/samtools/stats'
include { SUBSAMPLING                       } from '../modules/local/subsampling'
include { METAPHLAN_DB                      } from '../modules/local/metaphlan/makedb'
include { METAPHLAN_METAPHLAN               } from '../modules/local/metaphlan/metaphlan'
include { METAPHLAN_MERGETABLES             } from '../modules/local/metaphlan/mergetables'
include { HUMANN_DB                         } from '../modules/local/humann/makedb'
include { HUMANN_HUMANN                     } from '../modules/local/humann/humann'
include { HUMANN_MERGETABLES_GENE           } from '../modules/local/humann/mergetables_gene'
include { HUMANN_MERGETABLES_PATH           } from '../modules/local/humann/mergetables_path'
//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK } from '../subworkflows/local/input_check'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { FASTQC as FASTQC_UNPROCESSED      } from '../modules/nf-core/fastqc/main'
include { FASTQC as FASTQC_PROCESSED        } from '../modules/nf-core/fastqc/main'
include { MULTIQC                           } from '../modules/nf-core/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS       } from '../modules/nf-core/custom/dumpsoftwareversions/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow METAGENOMICSPIPELINE {
    ch_adapterlist = params.shortread_qc_adapterlist ? file(params.shortread_qc_adapterlist) : []
    ch_reference = file(params.human_reference)
    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK (
        file(params.input)
    )
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    //
    // MODULE: Run FastQC
    //
    FASTQC_UNPROCESSED (
        INPUT_CHECK.out.reads
    )
    ch_versions = ch_versions.mix(FASTQC_UNPROCESSED.out.versions.first())

    //
    // MODULE: Fastp
    //
    FASTP (
        INPUT_CHECK.out.reads, 
        ch_adapterlist, 
        false
    )

    ch_versions = ch_versions.mix( FASTP.out.versions.first() )
    ch_multiqc_files = ch_multiqc_files.mix( FASTP.out.json )

    //
    // MODULE: Run FastQC
    //
    FASTQC_PROCESSED (
        FASTP.out.reads
    )
    ch_versions = ch_versions.mix(FASTQC_PROCESSED.out.versions.first())
    //
    // MODULE: Bowtie 2 build
    //
    BOWTIE2_BUILD (
        ch_reference
    )
    ch_bowtie2_index = BOWTIE2_BUILD.out.index
    ch_versions      = ch_versions.mix( BOWTIE2_BUILD.out.versions )

    //
    // MODULE: Bowtie 2 align
    //
    // Map, generate BAM with all reads and unmapped reads in FASTQ for downstream
    BOWTIE2_ALIGN ( 
        FASTP.out.reads, 
        ch_bowtie2_index, 
        true, 
        true
    )
    ch_versions      = ch_versions.mix( BOWTIE2_ALIGN.out.versions.first() )
    ch_multiqc_files = ch_multiqc_files.mix( BOWTIE2_ALIGN.out.log )

    //
    // MODULE: Index BAM with samtools
    //
    SAMTOOLS_INDEX ( 
        BOWTIE2_ALIGN.out.aligned 
    )
    ch_versions      = ch_versions.mix( SAMTOOLS_INDEX.out.versions.first() )

    bam_bai = BOWTIE2_ALIGN.out.aligned
        .join(SAMTOOLS_INDEX.out.bai, remainder: true)

    //
    // MODULE: Samtools stats
    //
    SAMTOOLS_STATS ( 
        bam_bai, 
        ch_reference
    )
    ch_versions = ch_versions.mix(SAMTOOLS_STATS.out.versions.first())
    ch_multiqc_files = ch_multiqc_files.mix( SAMTOOLS_STATS.out.stats )

    SUBSAMPLING (
        BOWTIE2_ALIGN.out.fastq,
        params.subsamplelevel
    )

    //
    // MODULE: Metaphlan database
    //
    METAPHLAN_DB ( )

    //
    // MODULE: Metaphlan profiling
    //
    METAPHLAN_METAPHLAN (
        SUBSAMPLING.out.reads,
        METAPHLAN_DB.out.db
    )

    ch_versions        = ch_versions.mix( METAPHLAN_METAPHLAN.out.versions.first() )

    //
    // MODULE: Metaphlan merge tables
    //
    ch_profiles_metaphlan = METAPHLAN_METAPHLAN.out.profile.collect {it[1]}

    METAPHLAN_MERGETABLES ( ch_profiles_metaphlan )
    ch_multiqc_files = ch_multiqc_files.mix( METAPHLAN_MERGETABLES.out.txt )
    ch_versions = ch_versions.mix( METAPHLAN_MERGETABLES.out.versions )

    //
    // MODULE: HUMANN get database
    //
    HUMANN_DB ( )

    //
    // MODULE: HUMANN
    //
    ch_humann_input = SUBSAMPLING.out.concats.join(METAPHLAN_METAPHLAN.out.profile).groupTuple()

    HUMANN_HUMANN(
        ch_humann_input,
        HUMANN_DB.out.db
    )

    //
    // MODULE: HUMANN tables
    //
    ch_pathways_humann = HUMANN_HUMANN.out.pathways.collect {it[1]}
    ch_genes_humann = HUMANN_HUMANN.out.genes.collect {it[1]}

    HUMANN_MERGETABLES_PATH(
        ch_pathways_humann
    )
    HUMANN_MERGETABLES_GENE(
        ch_genes_humann
    )

    //
    // Subworkflow: Collect software versions
    //    
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowMetagenomicspipeline.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    methods_description    = WorkflowMetagenomicspipeline.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description, params)
    ch_methods_description = Channel.value(methods_description)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC_UNPROCESSED.out.zip.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC_PROCESSED.out.zip.collect{it[1]}.ifEmpty([]))

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )
    multiqc_report = MULTIQC.out.report.toList()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.dump_parameters(workflow, params)
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/