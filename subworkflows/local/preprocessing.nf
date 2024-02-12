//
// Preprocessing reads: fastp quality filtering and filtering out human reads
//

include { FASTP                             } from '../../modules/local/fastp'
include { FASTQC                            } from '../../modules/nf-core/fastqc/main'
include { BOWTIE2_BUILD                     } from '../../modules/local/bowtie2/build'
include { BOWTIE2_FILTERHUMAN               } from '../../modules/local/bowtie2/filterhuman'
include { SUBSAMPLING                       } from '../../modules/local/subsampling'

workflow PREPROCESSING {
    take:
    reads
    reference
    bowtie2index
    adapters
    savetrimmed
    cutright
    windowsize
    meanquality
    length
    skip_preprocessing
    skip_qualityfilter
    skip_humanfilter
    skip_subsampling
    skip_humann

    main:
    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()
    ch_proc_fastqc = Channel.empty()

    FASTQC ( reads )
    ch_versions = ch_versions.mix(FASTQC.out.versions.first())
    
    if(skip_preprocessing == false) {
        if(skip_qualityfilter == false){
            // Quality filtering, adapter trimming
            FASTP (
                reads, 
                adapters,
                savetrimmed,
                cutright,
                windowsize, 
                meanquality, 
                length
            )
            ch_versions = ch_versions.mix( FASTP.out.versions.first() )
            ch_multiqc_files = ch_multiqc_files.mix( FASTP.out.json )
            ch_reads = FASTP.out.reads
        } else {
            ch_reads = reads
        }

        // Remove human reads
        if(skip_humanfilter == false){
            if (!bowtie2index) {
                // Build index of reference genome
                BOWTIE2_BUILD ( reference )
                ch_bowtie2_index = BOWTIE2_BUILD.out.index
                ch_versions      = ch_versions.mix( BOWTIE2_BUILD.out.versions )
            } else{
                ch_bowtie2_index = bowtie2index
            }
            // Map, generate BAM with all reads and unmapped reads in fastq.gz for downstream
            BOWTIE2_FILTERHUMAN ( 
                ch_reads, 
                ch_bowtie2_index
            )
            ch_versions      = ch_versions.mix( BOWTIE2_FILTERHUMAN.out.versions.first() )
            ch_multiqc_files = ch_multiqc_files.mix( BOWTIE2_FILTERHUMAN.out.log )
            ch_reads = BOWTIE2_FILTERHUMAN.out.reads
        }

        // Subsampling reads
        if(skip_subsampling == false){
            SUBSAMPLING (
                ch_reads,
                params.subsamplelevel
            )
            ch_versions = ch_versions.mix(SUBSAMPLING.out.versions.first())
            ch_reads = SUBSAMPLING.out.reads
        }
    } else {
        ch_reads = reads
    }
    
    emit:
    reads    = ch_reads                     // channel: [ val(meta), [ fastq.gz,fastq.gz ] ]
    fastqc1  = FASTQC.out.zip               // channel: fastqc zips (unprocessed)
    versions = ch_versions                  // channel: [ versions.yml ]
    mqc      = ch_multiqc_files             // channel: multiqc files
}