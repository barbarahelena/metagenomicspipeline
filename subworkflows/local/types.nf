nextflow.enable.types = true

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RECORD TYPES shared by the workflows of this pipeline
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// One samplesheet row. A sample sequenced in several runs has one row per run,
// with the same id and a different run_accession (see --perform_runmerging).
record Sample {
    id: String
    single_end: Boolean
    run_accession: String?
    fastq: List<Path>       // [ fastq_1 ] or [ fastq_1, fastq_2 ]
}

// Reads of one sample after preprocessing: what the profilers take
record Reads {
    id: String
    single_end: Boolean
    fastq: List<Path>
}

// The parameters the workflows use. main.nf builds it from params; each field must have the declared type.
record MetagenomicsOptions {
    outdir: String
    adapterlist: Path?
    fasta: Path?
    bowtie2_index: Path?

    skip_preprocessing: Boolean
    skip_qualityfilter: Boolean
    skip_hostfilter: Boolean
    skip_subsampling: Boolean
    skip_metaphlan: Boolean
    skip_humann: Boolean
    skip_kraken: Boolean
    skip_shortbred: Boolean

    save_trimmed_fail: Boolean
    fastp_cutright: Boolean
    fastp_windowsize: Integer
    fastp_meanquality: Integer
    fastp_length: Integer
    perform_runmerging: Boolean
    subsamplelevel: Integer

    humann_db: String
    kraken2_db: Path?
    kraken2_dbname: String
    kraken2_save_reads: Boolean
    kraken2_save_readclassifications: Boolean
    bracken_build: Boolean
    bracken_readlength: Integer
    bracken_kmerlength: Integer
    bracken_threshold: Integer

    multiqc_config: Path?
    multiqc_logo: Path?
    multiqc_methods_description: Path?
}
