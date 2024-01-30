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
include { CONCAT                            } from '../../modules/local/concat'

workflow PREPROCESSING {
    take:
    reads
    reference
    adapters
    savetrimmed
    skip_preprocessing
    skip_qualityfilter
    skip_humanfilter
    skip_subsampling
    skip_humann

    main:
    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    FASTQC_UNPROCESSED ( reads )
    ch_versions = ch_versions.mix(FASTQC_UNPROCESSED.out.versions.first())
    
    if(skip_preprocessing == false) {
        if(skip_humanfilter == false){
            // Quality filtering, adapter trimming
            FASTP (
                reads, 
                adapters,
                savetrimmed
            )
            ch_versions = ch_versions.mix( FASTP.out.versions.first() )
            ch_multiqc_files = ch_multiqc_files.mix( FASTP.out.json )
            ch_reads = FASTP.out.reads

            FASTQC_PROCESSED ( FASTP.out.reads )
            ch_proc_fastqc = FASTQC_PROCESSED.out.zip
            ch_versions = ch_versions.mix(FASTQC_PROCESSED.out.versions.first())
        } else {
            ch_proc_fastqc = Channel.empty()
            ch_reads = reads
        }

        if(skip_humanfilter == false){
            // Build index of reference genome
            BOWTIE2_BUILD ( reference )
            ch_bowtie2_index = BOWTIE2_BUILD.out.index
            ch_versions      = ch_versions.mix( BOWTIE2_BUILD.out.versions )

            // Map, generate BAM with all reads and unmapped reads in fastq.gz for downstream
            BOWTIE2_ALIGN ( 
                ch_reads, 
                BOWTIE2_BUILD.out.index
            )
            ch_versions      = ch_versions.mix( BOWTIE2_ALIGN.out.versions.first() )
            ch_multiqc_files = ch_multiqc_files.mix( BOWTIE2_ALIGN.out.log )
            ch_reads = BOWTIE2_ALIGN.out.fastq

            // Samtools index human reads and stats
            SAMTOOLS_INDEX ( BOWTIE2_ALIGN.out.aligned )
            ch_versions      = ch_versions.mix( SAMTOOLS_INDEX.out.versions.first() )
            bam_bai = BOWTIE2_ALIGN.out.aligned
                .join(SAMTOOLS_INDEX.out.bai, remainder: true)

            SAMTOOLS_STATS ( 
                bam_bai, 
                reference
            )
            ch_versions = ch_versions.mix(SAMTOOLS_STATS.out.versions.first())
            ch_multiqc_files = ch_multiqc_files.mix( SAMTOOLS_STATS.out.stats )
        }

        // Subsampling reads
        if(skip_subsampling == false){
            SUBSAMPLING (
                ch_reads,
                params.subsamplelevel
            )
            ch_versions = ch_versions.mix(SUBSAMPLING.out.versions.first())
            ch_multiqc_files = ch_multiqc_files.mix( SUBSAMPLING.out.log ) // seqkit stats
            ch_reads = SUBSAMPLING.out.reads
        }
    } else {
        ch_reads = reads
    }

    if(skip_humann == false) {
        CONCAT ( ch_reads )
        ch_concats = CONCAT.out.concats
    } else { ch_concats = Channel.empty() }
    
    emit:
    reads    = ch_reads                      // channel: [ val(meta), [ fastq.gz,fastq.gz ] ]
    concats  = ch_concats                    // channel: [ val(meta), [ fastq.gz ] ]
    fastqc1  = FASTQC_UNPROCESSED.out.zip    // channel: fastqc zips (unprocessed)
    fastqc2  = ch_proc_fastqc                // channel: fastqc zips (processed)
    versions = ch_versions                   // channel: [ versions.yml ]
    mqc      = ch_multiqc_files              // channel: multiqc files
}