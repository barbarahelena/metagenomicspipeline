nextflow.enable.types = true

//
// Preprocessing reads: FastQC, fastp quality filtering, host read removal, merging runs, subsampling
//
include { Sample; Reads; MetagenomicsOptions } from './types'
include { FASTP                             } from '../../modules/local/fastp'
include { FASTQC                            } from '../../modules/local/fastqc'
include { BOWTIE2_BUILD                     } from '../../modules/local/bowtie2/build'
include { BOWTIE2_FILTERHOST                } from '../../modules/local/bowtie2/filterhost'
include { CAT as MERGE_RUNS                 } from '../../modules/local/cat'
include { SUBSAMPLING                       } from '../../modules/local/subsampling'
include { CAT_READCOUNTS                    } from '../../modules/local/cat_readcounts'

workflow PREPROCESSING {
    take:
    ch_samples: Channel<Sample>
    opts: MetagenomicsOptions

    main:
    //
    // MODULE: FastQC on the raw reads, one report per run (local names must differ from the emit names below)
    //
    def fastqc_results = FASTQC(ch_samples.map { s ->
        record(id: s.run_accession ? "${s.id}_${s.run_accession}" : s.id, fastq: s.fastq)
    })

    def ch_reads = ch_samples.map { s -> record(id: s.id, single_end: s.single_end, run_accession: s.run_accession, fastq: s.fastq) }
    def ch_mqc          = channel.empty()
    def ch_out_fastp    = channel.empty()
    def ch_out_bowtie2  = channel.empty()
    def ch_out_merged   = channel.empty()
    def ch_out_subsampl = channel.empty()

    if (!opts.skip_preprocessing) {
        //
        // MODULE: fastp quality filtering, adapter trimming
        //
        if (!opts.skip_qualityfilter) {
            def fastp = FASTP(
                ch_reads,
                opts.adapterlist,
                opts.save_trimmed_fail,
                opts.fastp_cutright,
                opts.fastp_windowsize,
                opts.fastp_meanquality,
                opts.fastp_length
            )
            ch_reads     = fastp.map { r -> record(id: r.id, single_end: r.single_end, run_accession: r.run_accession, fastq: r.fastq) }
            ch_mqc       = ch_mqc.mix(fastp.map { r -> r.json })
            ch_out_fastp = ch_out_fastp.mix(fastp.map { r -> r.log })
        }

        //
        // MODULE: remove host reads (Bowtie2); build the index from the reference when none is given
        //
        if (!opts.skip_hostfilter) {
            def ch_index = opts.bowtie2_index
                ? channel.value([ opts.bowtie2_index ])
                : BOWTIE2_BUILD(opts.fasta)
            def filtered = BOWTIE2_FILTERHOST(ch_reads, ch_index)
            ch_reads       = filtered.map { r -> record(id: r.id, single_end: r.single_end, run_accession: r.run_accession, fastq: r.fastq) }
            ch_mqc         = ch_mqc.mix(filtered.map { r -> r.log })
            ch_out_bowtie2 = ch_out_bowtie2
                .mix(filtered.flatMap { r -> r.fastq })
                .mix(filtered.map { r -> r.log })
                .mix(filtered.map { r -> r.stats })
        }
    }

    //
    // MODULE: merge the runs of a sample (one samplesheet row per run, same sample id)
    //
    def ch_merged: Channel<Reads> = ch_reads.map { r -> record(id: r.id, single_end: r.single_end, fastq: r.fastq) }
    if (!opts.skip_preprocessing && opts.perform_runmerging) {
        // Sort the runs of a sample so the order of reads in the merged file does not depend on task order
        def ch_runs = ch_reads
            .map { r -> tuple(r.id, r) }
            .groupBy()
            .map { id, runs ->
                def sorted = runs.toSorted { a, b -> (a.run_accession ?: '') <=> (b.run_accession ?: '') }
                tuple(id, sorted[0].single_end, sorted.size(), sorted.collectMany { r -> r.fastq }.toList())
            }
        def merged = MERGE_RUNS(
            ch_runs
                .filter { _id, _se, n, _fastq -> n > 1 }
                .map { id, se, _n, fastq -> record(id: id, single_end: se, fastq: fastq) }
        )
        ch_merged = ch_runs
            .filter { _id, _se, n, _fastq -> n == 1 }
            .map { id, se, _n, fastq -> record(id: id, single_end: se, fastq: fastq) }
            .mix(merged)
        ch_out_merged = merged.flatMap { r -> r.fastq }
    }

    //
    // MODULE: subsample reads to an equal depth; table of read counts before subsampling
    //
    def ch_out_reads: Channel<Reads> = ch_merged
    if (!opts.skip_preprocessing && !opts.skip_subsampling) {
        def subsampled = SUBSAMPLING(ch_merged, opts.subsamplelevel)
        ch_out_reads = subsampled.map { r -> record(id: r.id, single_end: r.single_end, fastq: r.fastq) }
        def readcounts = CAT_READCOUNTS(
            subsampled.map { r -> r.readcount }.collect().map { files -> files.toSorted { a, b -> a.name <=> b.name } }
        )
        ch_out_subsampl = channel.empty()
            .mix(subsampled.map { r -> r.readcount })
            .mix(readcounts)
    }

    emit:
    reads: Channel<Reads>       = ch_out_reads
    fastqc_zip: Channel<Path>   = fastqc_results.flatMap { r -> r.zip }
    fastqc: Channel<Path>       = fastqc_results.flatMap { r -> r.html + r.zip }
    mqc: Channel<Path>          = ch_mqc
    fastp: Channel<Path>        = ch_out_fastp
    bowtie2: Channel<Path>      = ch_out_bowtie2
    merged: Channel<Path>       = ch_out_merged
    subsampling: Channel<Path>  = ch_out_subsampl
}
