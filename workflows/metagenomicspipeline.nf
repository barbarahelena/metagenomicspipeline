nextflow.enable.types = true

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryMap          } from 'plugin/nf-schema'
include { paramsSummaryMultiqc      } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { workflowVersionToYAML     } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText    } from '../subworkflows/local/utils_metagenomicspipeline_pipeline'
include { gitCommitHash             } from '../subworkflows/local/utils_metagenomicspipeline_pipeline'
include { Sample; MetagenomicsOptions } from '../subworkflows/local/types'

//
// SUBWORKFLOW: local subworkflows
//
include { PREPROCESSING                     } from '../subworkflows/local/preprocessing'
include { METAPHLAN                         } from '../subworkflows/local/metaphlan'
include { HUMANN                            } from '../subworkflows/local/humann'
include { KRAKEN                            } from '../subworkflows/local/kraken'
include { SHORTBRED                         } from '../subworkflows/local/shortbred'

//
// MODULE: nf-core modules
//
include { MULTIQC                           } from '../modules/nf-core/multiqc/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow METAGENOMICSPIPELINE {

    take:
    ch_samples: Channel<Sample>
    opts: MetagenomicsOptions

    main:
    //
    // SUBWORKFLOW: preprocessing of reads (quality filter, host read filtering, run merging, subsampling)
    //
    def prep     = PREPROCESSING(ch_samples, opts)
    def ch_reads = prep.reads
    def ch_mqc   = channel.empty().mix(prep.fastqc_zip).mix(prep.mqc)

    //
    // SUBWORKFLOW: MetaPhlAn
    //
    def ch_out_metaphlan = channel.empty()
    if (!opts.skip_metaphlan) {
        def metaphlan_out = METAPHLAN(ch_reads)   // not 'metaphlan': an emit name below
        ch_out_metaphlan = metaphlan_out.results
        ch_mqc           = ch_mqc.mix(metaphlan_out.profiles)
    }

    //
    // SUBWORKFLOW: HUMAnN
    //
    def ch_out_humann = channel.empty()
    if (!opts.skip_humann) {
        ch_out_humann = HUMANN(ch_reads, opts.humann_db)
    }

    //
    // SUBWORKFLOW: Kraken2 + Bracken
    //
    def ch_out_kraken2 = channel.empty()
    def ch_out_bracken = channel.empty()
    if (!opts.skip_kraken) {
        def kraken = KRAKEN(ch_reads, opts)
        ch_out_kraken2 = kraken.kraken2
        ch_out_bracken = kraken.bracken
        ch_mqc         = ch_mqc.mix(kraken.report)
    }

    //
    // SUBWORKFLOW: ShortBRED
    //
    def ch_out_shortbred = channel.empty()
    if (!opts.skip_shortbred) {
        ch_out_shortbred = SHORTBRED(ch_reads)
    }

    //
    // Record the pipeline git commit. Written by Nextflow itself: no task or container needed.
    //
    def ch_commit_hash = channel.of("""
        You can obtain the exact version of the metagenomicspipeline used for this run
        by cloning the repo and running the Git command:

        git checkout ${gitCommitHash()}
        """.stripIndent())
        .collectFile(name: 'git_commit_hash.txt')

    //
    // Collect software versions from the 'versions' topic channel.
    // Each entry is [ process, tool, version ].
    //
    def ch_versions_topic: Channel<Tuple> = channel.topic('versions')
    def ch_versions = ch_versions_topic
        .map { process, tool, version ->
            def v = (version instanceof Path) ? version.text.trim() : version.toString().trim()
            tuple(process.tokenize(':')[-1], tool, v)   // tuple(), not a list: the type checker then knows its 3 parts
        }
        .unique()

    // Plain table (always written, independent of MultiQC)
    def ch_versions_tsv = ch_versions
        .map { process, tool, version -> "${process}\t${tool}\t${version}" }
        .collectFile(
            name: 'software_versions.tsv',
            seed: "process\tsoftware\tversion",
            sort: true,
            newLine: true
        )

    // YAML grouped per process, as MultiQC's software versions section expects.
    // Map to strings *before* collectFile: given tuples, collectFile uses the first element as a file name.
    def ch_versions_yaml = ch_versions
        .map { process, tool, version -> tuple(process, "    ${tool}: ${version}") }
        .groupBy()
        .map { process, lines -> "${process}:\n${lines.toSorted().join('\n')}" }
        .mix(channel.of(workflowVersionToYAML()))
        .collectFile(
            name: 'metagenomicspipeline_software_mqc_versions.yml',
            sort: true,
            newLine: true
        )

    //
    // MODULE: MultiQC
    //
    def methods_description_template = opts.multiqc_methods_description
        ?: file("${projectDir}/assets/methods_description_template.yml", checkIfExists: true)

    def ch_workflow_summary = channel.of(paramsSummaryMultiqc(paramsSummaryMap()))
        .collectFile(name: 'workflow_summary_mqc.yaml')
    def ch_methods_description = channel.of(methodsDescriptionText(methods_description_template, opts))
        .collectFile(name: 'methods_description_mqc.yaml')

    def multiqc_default = file("${projectDir}/assets/multiqc_config.yml", checkIfExists: true)
    def multiqc_configs = opts.multiqc_config ? [ multiqc_default, opts.multiqc_config ] : [ multiqc_default ]
    def multiqc_logo    = opts.multiqc_logo ? [ opts.multiqc_logo ] : []

    def ch_multiqc_input = channel.empty()
        .mix(ch_workflow_summary)
        .mix(ch_methods_description)
        .mix(ch_versions_yaml)
        .mix(ch_mqc)
        .collect()
        .map { files -> tuple([id: 'multiqc'], files.toList(), multiqc_configs, multiqc_logo, [], []) }

    def multiqc_results = MULTIQC(ch_multiqc_input)

    emit:
    // One channel of files per results folder; the output block in main.nf decides where each goes
    fastqc: Channel<Path>        = prep.fastqc
    fastp: Channel<Path>         = prep.fastp
    bowtie2: Channel<Path>       = prep.bowtie2
    merged: Channel<Path>        = prep.merged
    subsampling: Channel<Path>   = prep.subsampling
    metaphlan: Channel<Path>     = ch_out_metaphlan
    humann: Channel<Path>        = ch_out_humann
    kraken2: Channel<Path>       = ch_out_kraken2
    bracken: Channel<Path>       = ch_out_bracken
    shortbred: Channel<Path>     = ch_out_shortbred
    multiqc: Channel<Path>       = multiqc_results.report.mix(multiqc_results.data).mix(multiqc_results.plots).map { _meta, f -> f }
    pipeline_info: Channel<Path> = channel.empty().mix(ch_commit_hash).mix(ch_versions_tsv).mix(ch_versions_yaml)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
