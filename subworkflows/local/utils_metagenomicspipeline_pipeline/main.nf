//
// Subworkflow with functionality specific to the metagenomicspipeline pipeline
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { UTILS_NFSCHEMA_PLUGIN     } from '../../nf-core/utils_nfschema_plugin'
include { paramsSummaryMap          } from 'plugin/nf-schema'
include { samplesheetToList         } from 'plugin/nf-schema'
include { UTILS_NEXTFLOW_PIPELINE   } from '../../nf-core/utils_nextflow_pipeline'
include { completionEmail           } from '../../nf-core/utils_nfcore_pipeline'
include { completionSummary         } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NFCORE_PIPELINE     } from '../../nf-core/utils_nfcore_pipeline'

/*
========================================================================================
    SUBWORKFLOW TO INITIALISE PIPELINE
========================================================================================
*/

workflow PIPELINE_INITIALISATION {

    take:
    version            // boolean: Display version and exit
    validate_params    // boolean: Validate parameters against the schema at runtime
    nextflow_cli_args  //   array: List of positional nextflow CLI args
    outdir             //  string: The output directory where the results will be saved
    input              //    path: Path to input samplesheet
    perform_runmerging // boolean: Samples may have one row per sequencing run
    help               //  string: Display help message (for one parameter) and exit
    help_full          // boolean: Show the full help message
    show_hidden        // boolean: Show hidden parameters in the help message

    main:

    //
    // Print version and exit if required and dump pipeline parameters to JSON file
    //
    UTILS_NEXTFLOW_PIPELINE (
        version,
        true,
        outdir,
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1
    )

    //
    // Validate parameters and generate parameter summary to stdout
    //
    def before_text = """
-\033[2m----------------------------------------------------\033[0m-
\033[0;34m  ${workflow.manifest.name} ${workflow.manifest.version}\033[0m
-\033[2m----------------------------------------------------\033[0m-
"""
    def after_text = """${workflow.manifest.doi ? "\n* The pipeline\n" : ""}${workflow.manifest.doi.tokenize(",").collect { doi -> "    https://doi.org/${doi.trim().replace('https://doi.org/', '')}" }.join("\n")}${workflow.manifest.doi ? "\n" : ""}
* The nf-core framework
    https://doi.org/10.1038/s41587-020-0439-x

* Software dependencies
    https://github.com/barbarahelena/metagenomicspipeline/blob/main/CITATIONS.md
"""
    def command = "nextflow run ${workflow.manifest.name} -profile <docker/singularity/.../institute> --input samplesheet.csv --genome GRCh38 --outdir <OUTDIR>"

    UTILS_NFSCHEMA_PLUGIN (
        workflow,
        validate_params,
        null,
        help,
        help_full,
        show_hidden,
        before_text,
        after_text,
        command,
        null
    )

    //
    // Check config provided to the pipeline
    //
    UTILS_NFCORE_PIPELINE (
        nextflow_cli_args
    )

    //
    // Create channel from input samplesheet: one Sample record per row
    //
    def rows = samplesheetToList(input, "${projectDir}/assets/schema_input.json")
    validateSamplesheet(rows, perform_runmerging)

    def ch_samples = channel
        .fromList(rows)
        .map { row ->
            def meta    = row[0]
            def fastq_1 = row[1]
            def fastq_2 = row[2]
            def fastq = [ fastq_1 ] + (fastq_2 ? [ fastq_2 ] : [])
            record(
                id: meta.id as String,
                single_end: !fastq_2,
                run_accession: meta.run_accession ? meta.run_accession as String : null,   // [] when the column is absent
                fastq: fastq.collect { f -> resolveSamplesheetPath(f as Path, input) }
            )
        }

    emit:
    samples = ch_samples
}

/*
========================================================================================
    SUBWORKFLOW FOR PIPELINE COMPLETION
========================================================================================
*/

workflow PIPELINE_COMPLETION {

    take:
    email           //  string: email address
    email_on_fail   //  string: email address sent on pipeline failure
    plaintext_email // boolean: Send plain-text email instead of HTML
    outdir          //    path: Path to output directory where results will be published
    monochrome_logs // boolean: Disable ANSI colour codes in log output

    main:

    def summary_params = paramsSummaryMap()

    workflow.onComplete {
        if (email || email_on_fail) {
            completionEmail(summary_params, email, email_on_fail, plaintext_email, outdir, monochrome_logs, null)
        }
        completionSummary(monochrome_logs)
    }

    workflow.onError {
        log.error "Pipeline failed. Please refer to troubleshooting docs: https://github.com/barbarahelena/metagenomicspipeline"
    }
}

/*
========================================================================================
    FUNCTIONS
========================================================================================
*/

//
// A sample may appear on several rows only when its runs are merged, and then each row needs its own run_accession
//
def validateSamplesheet(rows: List, perform_runmerging: Boolean) {
    def by_id = rows.groupBy { row -> row[0].id }
    by_id.each { id, sample_rows ->
        if (sample_rows.size() == 1) {
            return
        }
        if (!perform_runmerging) {
            error "[metagenomicspipeline] Sample '${id}' appears on ${sample_rows.size()} rows of the samplesheet. Use --perform_runmerging to merge the runs of a sample, or give each row its own sample name."
        }
        def runs = sample_rows.collect { row -> row[0].run_accession }
        if (runs.any { run -> !run } || runs.unique(false).size() != runs.size()) {
            error "[metagenomicspipeline] Sample '${id}' appears on several rows: each row needs a different value in the 'run_accession' column."
        }
        if (sample_rows.collect { row -> !row[2] }.unique(false).size() > 1) {
            error "[metagenomicspipeline] The runs of sample '${id}' mix single-end and paired-end reads; they cannot be merged."
        }
    }
}

//
// A relative path in the samplesheet is relative to the launch directory, as nf-schema reads it.
// When no file is there, try relative to the samplesheet's own folder, so a samplesheet can sit
// next to its data (as assets/testdata does). Remote files (s3://, https://) are used as they are.
//
def resolveSamplesheetPath(path: Path, samplesheet: Path) -> Path {
    if (path.scheme != 'file' || path.exists()) {
        return path
    }
    def launch = workflow.launchDir.toAbsolutePath().normalize()
    def abs    = path.toAbsolutePath().normalize()
    if (abs.startsWith(launch)) {
        def beside_sheet = samplesheet.toAbsolutePath().parent.resolve(launch.relativize(abs).toString()).normalize()
        if (beside_sheet.exists()) {
            return beside_sheet
        }
    }
    error "[metagenomicspipeline] FastQ file from the samplesheet does not exist: ${path}"
}

//
// Reference file for --genome from iGenomes (conf/igenomes.config), or null
//
def genomeAttribute(genomes: Map, genome: String?, attribute: String) -> Path? {
    if (!genome) {
        return null
    }
    if (!genomes.containsKey(genome)) {
        error "[metagenomicspipeline] Genome '${genome}' is not available in the iGenomes config. Currently available genomes: ${genomes.keySet().join(', ')}"
    }
    def value = (genomes[genome] as Map)[attribute]
    return value ? file(value as String, checkIfExists: true) : null
}

//
// Git commit of the pipeline code that is running.
// workflow.commitId is set when run from a repository (nextflow run barbarahelena/metagenomicspipeline -r ...);
// otherwise ask git, and return 'unknown' rather than crash when git is missing (e.g. some HPC login nodes).
//
def gitCommitHash() -> String {
    if (workflow.commitId) {
        return workflow.commitId
    }
    try {
        def proc = ['git', '-C', projectDir.toString(), 'rev-parse', 'HEAD'].execute()
        def out  = proc.text.trim()
        return proc.waitFor() == 0 && out ? out : 'unknown'
    } catch (Exception _e) {
        return 'unknown'
    }
}

//
// Tools used in this run, for the MultiQC methods description: [ name, short citation, reference ]
//
def toolsUsed(opts) {
    def preprocessing = !opts.skip_preprocessing
    def tools = [
        [ true,
          'FastQC', 'Andrews 2010',
          'Andrews S. (2010). FastQC: A Quality Control Tool for High Throughput Sequence Data. <a href="https://www.bioinformatics.babraham.ac.uk/projects/fastqc/">https://www.bioinformatics.babraham.ac.uk/projects/fastqc/</a>' ],
        [ preprocessing && !opts.skip_qualityfilter,
          'fastp', 'Chen et al. 2018',
          'Chen S, Zhou Y, Chen Y, Gu J. (2018). fastp: an ultra-fast all-in-one FASTQ preprocessor. Bioinformatics, 34(17), i884–i890. doi: <a href="https://doi.org/10.1093/bioinformatics/bty560">10.1093/bioinformatics/bty560</a>' ],
        [ preprocessing && !opts.skip_hostfilter,
          'Bowtie2', 'Langmead &amp; Salzberg 2012',
          'Langmead B, Salzberg SL. (2012). Fast gapped-read alignment with Bowtie 2. Nature Methods, 9(4), 357–359. doi: <a href="https://doi.org/10.1038/nmeth.1923">10.1038/nmeth.1923</a>' ],
        [ preprocessing && !opts.skip_hostfilter,
          'SAMtools', 'Danecek et al. 2021',
          'Danecek P, Bonfield JK, Liddle J, Marshall J, Ohan V, Pollard MO, Whitwham A, Keane T, McCarthy SA, Davies RM, Li H. (2021). Twelve years of SAMtools and BCFtools. GigaScience, 10(2), giab008. doi: <a href="https://doi.org/10.1093/gigascience/giab008">10.1093/gigascience/giab008</a>' ],
        [ preprocessing && !opts.skip_subsampling,
          'SeqKit', 'Shen et al. 2024',
          'Shen W, Sipos B, Zhao L. (2024). SeqKit2: A Swiss army knife for sequence and alignment processing. iMeta, 3(3), e191. doi: <a href="https://doi.org/10.1002/imt2.191">10.1002/imt2.191</a>' ],
        [ !opts.skip_metaphlan,
          'MetaPhlAn', 'Blanco-Míguez et al. 2023',
          'Blanco-Míguez A, Beghini F, Cumbo F, McIver LJ, Thompson KN, Zolfo M, Manghi P, Dubois L, Huang KD, Thomas AM, Nickols WA, Piccinno G, Piperni E, Punčochář M, Valles-Colomer M, Tett A, Giordano F, Davies R, Wolf J, Berry SE, Spector TD, Franzosa EA, Pasolli E, Asnicar F, Huttenhower C, Segata N. (2023). Extending and improving metagenomic taxonomic profiling with uncharacterized species using MetaPhlAn 4. Nature Biotechnology, 41(11), 1633–1644. doi: <a href="https://doi.org/10.1038/s41587-023-01688-w">10.1038/s41587-023-01688-w</a>' ],
        [ !opts.skip_humann,
          'HUMAnN', 'Beghini et al. 2021',
          'Beghini F, McIver LJ, Blanco-Míguez A, Dubois L, Asnicar F, Maharjan S, Mailyan A, Manghi P, Scholz M, Thomas AM, Valles-Colomer M, Weingart G, Zhang Y, Zolfo M, Huttenhower C, Franzosa EA, Segata N. (2021). Integrating taxonomic, functional, and strain-level profiling of diverse microbial communities with bioBakery 3. eLife, 10, e65088. doi: <a href="https://doi.org/10.7554/eLife.65088">10.7554/eLife.65088</a>' ],
        [ !opts.skip_kraken,
          'Kraken2', 'Wood et al. 2019',
          'Wood DE, Lu J, Langmead B. (2019). Improved metagenomic analysis with Kraken 2. Genome Biology, 20(1), 257. doi: <a href="https://doi.org/10.1186/s13059-019-1891-0">10.1186/s13059-019-1891-0</a>' ],
        [ !opts.skip_kraken,
          'Bracken', 'Lu et al. 2017',
          'Lu J, Breitwieser FP, Thielen P, Salzberg SL. (2017). Bracken: estimating species abundance in metagenomics data. PeerJ Computer Science, 3, e104. doi: <a href="https://doi.org/10.7717/peerj-cs.104">10.7717/peerj-cs.104</a>' ],
        [ !opts.skip_shortbred,
          'ShortBRED', 'Kaminski et al. 2015',
          'Kaminski J, Gibson MK, Franzosa EA, Segata N, Dantas G, Huttenhower C. (2015). High-specificity targeted functional profiling in microbial communities with ShortBRED. PLoS Computational Biology, 11(12), e1004557. doi: <a href="https://doi.org/10.1371/journal.pcbi.1004557">10.1371/journal.pcbi.1004557</a>' ],
        [ true,
          'MultiQC', 'Ewels et al. 2016',
          'Ewels P, Magnusson M, Lundin S, Käller M. (2016). MultiQC: summarize analysis results for multiple tools and samples in a single report. Bioinformatics, 32(19), 3047–3048. doi: <a href="https://doi.org/10.1093/bioinformatics/btw354">10.1093/bioinformatics/btw354</a>' ],
    ]
    return tools.findAll { tool -> tool[0] }.collect { tool -> tool.drop(1) }
}

//
// Generate methods description for MultiQC
//
def methodsDescriptionText(mqc_methods_yaml, opts) {
    def meta          = [:]
    meta.workflow     = workflow.toMap()
    meta.manifest_map = workflow.manifest.toMap()

    if (meta.manifest_map.doi) {
        meta["doi_text"] = meta.manifest_map.doi.tokenize(",")
            .collect { doi_ref -> doi_ref.replace('https://doi.org/', '').replace(' ', '') }
            .collect { clean -> "(doi: <a href='https://doi.org/${clean}'>${clean}</a>)" }
            .join(", ")
    } else {
        meta["doi_text"] = ""
    }
    meta["nodoi_text"] = meta.manifest_map.doi ? "" : "<li>If available, make sure to update the text to include the Zenodo DOI of version of the pipeline used. </li>"

    // Cite only the tools that ran
    def tools = toolsUsed(opts)
    meta["tool_citations"]    = "Tools used in the workflow included: " + tools.collect { name, short_citation, _reference -> "${name} (${short_citation})" }.join(', ') + "."
    meta["tool_bibliography"] = tools.collect { _name, _short_citation, reference -> "<li>${reference}</li>" }.join('\n    ')

    def engine = new groovy.text.SimpleTemplateEngine()
    return engine.createTemplate(mqc_methods_yaml.text).make(meta).toString()
}
