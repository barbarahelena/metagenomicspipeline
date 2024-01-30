//
// Preprocessing reads: fastp quality filtering and filtering out human reads
//

include { FASTP                             } from '../../modules/local/fastp'
include { FASTQC as FASTQC_UNPROCESSED      } from '../../modules/nf-core/fastqc/main'
include { FASTQC as FASTQC_PROCESSED        } from '../../modules/nf-core/fastqc/main'
include { BOWTIE2_BUILD                     } from '../../modules/local/bowtie2/build'
include { BOWTIE2_ALIGN                     } from '../../modules/local/bowtie2/align'
include { SAMTOOLS_INDEX                    } from '../../modules/local/samtools/index'
include { SAMTOOLS_STATS                    } from '../../modules/local/samtools/stats'
include { SUBSAMPLING                       } from '../../modules/local/subsampling'

workflow PREPROCESSING {
    take:
    reads
    reference
    adapters
    savetrimmed
    saveunaligned
    sortbam

    main:
    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()
    //
    // MODULE: Run FastQC
    //
    FASTQC_UNPROCESSED (
        reads
    )
    ch_versions = ch_versions.mix(FASTQC_UNPROCESSED.out.versions.first())
    //
    // MODULE: Fastp
    //
    FASTP (
        reads, 
        adapters,
        savetrimmed
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
    // MODULE: Bowtie 2 build index of reference genome
    //
    BOWTIE2_BUILD (
        reference
    )
    ch_bowtie2_index = BOWTIE2_BUILD.out.index
    ch_versions      = ch_versions.mix( BOWTIE2_BUILD.out.versions )
    //
    // MODULE: Bowtie 2 align
    //
    // Map, generate BAM with all reads and unmapped reads in FASTQ for downstream
    BOWTIE2_ALIGN ( 
        FASTP.out.reads, 
        BOWTIE2_BUILD.out.index, 
        saveunaligned, 
        sortbam
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
        reference
    )
    ch_versions = ch_versions.mix(SAMTOOLS_STATS.out.versions.first())
    ch_multiqc_files = ch_multiqc_files.mix( SAMTOOLS_STATS.out.stats )

    SUBSAMPLING (
        BOWTIE2_ALIGN.out.fastq,
        params.subsamplelevel
    )
    ch_versions = ch_versions.mix(SUBSAMPLING.out.versions.first())
    //ch_multiqc_files = ch_multiqc_files.mix( SUBSAMPLING.out.stats )

    emit:
    reads    = SUBSAMPLING.out.reads         // channel: [ val(meta), [ fastq.gz,fastq.gz ] ]
    concats  = SUBSAMPLING.out.concats       // channel: [ val(meta), [ fastq.gz ] ]
    fastqc1 = FASTQC_UNPROCESSED.out.zip     // channel: fastqc zips (unprocessed)
    fastqc2 = FASTQC_PROCESSED.out.zip       // channel: fastqc zips (processed)
    versions = ch_versions                   // channel: [ versions.yml ]
}