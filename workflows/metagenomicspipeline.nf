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
include { METAPHLAN                         } from '../subworkflows/local/metaphlan'
include { KRAKEN                            } from '../subworkflows/local/kraken'
include { HUMANN                            } from '../subworkflows/local/humann'
include { SHORTBRED                         } from '../subworkflows/local/shortbred'
include { CUSTOM_DUMPSOFTWAREVERSIONS       } from '../modules/local/dumpsoftwareversions/main'
//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK                       } from '../subworkflows/local/input_check'
include { PREPROCESSING                     } from '../subworkflows/local/preprocessing'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { MULTIQC                           } from '../modules/nf-core/multiqc/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

def getGenomeAttribute(attribute) {
    if (params.genomes && params.genome && params.genomes.containsKey(params.genome)) {
        if (params.genomes[params.genome].containsKey(attribute)) {
            return params.genomes[params.genome][attribute]
        }
    }
    return null
}

workflow METAGEN {
    ch_adapterlist = params.adapterlist ? file(params.adapterlist) : []
    ch_reference = params.fasta ? file(params.fasta) :
                    params.genome ? getGenomeAttribute('fasta') : []
    ch_kraken_db = params.kraken2_db ? file(params.kraken2_db) : []
    ch_humann_db = params.humann_db ? params.humann_db : []
    ch_bowtie2_index = params.bowtie2_index ? file(params.bowtie2_index) : 
                    params.genome ? getGenomeAttribute('bowtie2') : []
    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK ( file(params.input) )
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)
    //
    // SUBWORKFLOW: preprocessing of reads (quality filter, host read filtering, subsampling)
    //
    PREPROCESSING (
        INPUT_CHECK.out.reads,
        ch_reference,
        ch_bowtie2_index,
        ch_adapterlist
    )
    ch_versions = ch_versions.mix(PREPROCESSING.out.versions)
    
    //
    // SUBWORKFLOW: Metaphlan
    //    
    if( params.skip_metaphlan == false ) {
        METAPHLAN ( PREPROCESSING.out.reads )
        ch_versions = ch_versions.mix(METAPHLAN.out.versions)
        if( PREPROCESSING.out.reads.map{ it[0].single_end }) {
            ch_humann_input = PREPROCESSING.out.reads
                .join( METAPHLAN.out.profiles )
        } else {
            ch_humann_input = PREPROCESSING.out.reads
                .join(METAPHLAN.out.profiles)
                .groupTuple()
                .map { id, paths, profile ->  [id, paths.flatten(), profile[0]] }
        }
    } else {
        if( PREPROCESSING.out.reads.map{ it[0].single_end }) {
            ch_humann_input = PREPROCESSING.out.reads
        } else {
            ch_humann_input = PREPROCESSING.out.reads
                .map{ id, paths ->  [ id, paths.flatten() ] }
        }
    }

    //
    // SUBWORKFLOW: HUMAnN
    if( params.skip_humann == false ) {
        HUMANN ( ch_humann_input, ch_humann_db )
        ch_versions = ch_versions.mix(HUMANN.out.versions)
    }

    //
    // SUBWORKFLOW: KRAKEN 
    //
    if( params.skip_kraken == false ) {
        KRAKEN ( PREPROCESSING.out.reads, ch_kraken_db )
        ch_versions = ch_versions.mix(KRAKEN.out.versions)
    }

    //
    // SUBWORKFLOW: ShortBRED
    //
    if( params.skip_shortbred == false ) {
        SHORTBRED ( ch_humann_input )
        ch_versions = ch_versions.mix(SHORTBRED.out.versions)
    }

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
    ch_multiqc_files = ch_multiqc_files.mix(PREPROCESSING.out.fastqc1.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(PREPROCESSING.out.mqc.collect{it[1]}.ifEmpty([]))
    if(params.skip_metaphlan == false){
        ch_multiqc_files = ch_multiqc_files.mix(METAPHLAN.out.profiles.collect{it[1]}.ifEmpty([]))
        ch_multiqc_files = ch_multiqc_files.mix(METAPHLAN.out.mqc.collect{it[1]}.ifEmpty([]))
    }
    if(params.skip_kraken == false){
        ch_multiqc_files = ch_multiqc_files.mix(KRAKEN.out.report.collect{it[1]}.ifEmpty([]))
        ch_multiqc_files = ch_multiqc_files.mix(KRAKEN.out.mqc.collect{it[1]}.ifEmpty([]))
    }

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.ifEmpty([]),
        [],
        []
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
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, 
        //multiqc_report
        [] )
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