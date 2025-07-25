//
// Preprocessing reads: fastp quality filtering and filtering out host reads
//
include { FASTP                             } from '../../modules/local/fastp'
include { FASTQC                            } from '../../modules/nf-core/fastqc/main'
include { BOWTIE2_BUILD                     } from '../../modules/local/bowtie2/build'
include { BOWTIE2_FILTERHOST                } from '../../modules/local/bowtie2/filterhost'
include { CAT as MERGE_RUNS                 } from '../../modules/local/cat'
include { SUBSAMPLING                       } from '../../modules/local/subsampling'
include { CAT_READCOUNTS                    } from '../../modules/local/cat_readcounts'

workflow PREPROCESSING {
    take:
    reads
    reference
    bowtie2index
    adapters

    main:
    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    FASTQC ( reads )
    ch_versions = ch_versions.mix(FASTQC.out.versions.first())
    
    if(params.skip_preprocessing == false) {
        if(params.skip_qualityfilter == false){
            // Quality filtering, adapter trimming
            FASTP (
                reads, 
                adapters,
                params.save_trimmed_fail,
                params.fastp_cutright,
                params.fastp_windowsize, 
                params.fastp_meanquality, 
                params.fastp_length
            )
            ch_versions = ch_versions.mix( FASTP.out.versions.first() )
            ch_multiqc_files = ch_multiqc_files.mix( FASTP.out.json )
            ch_reads = FASTP.out.reads
        } else {
            ch_reads = reads
        }

        // Remove human reads
        if(params.skip_hostfilter == false){
            if (!bowtie2index) {
                // Build index of reference genome
                BOWTIE2_BUILD ( reference )
                ch_bowtie2_index = BOWTIE2_BUILD.out.index
                ch_versions      = ch_versions.mix( BOWTIE2_BUILD.out.versions )
            } else{
                ch_bowtie2_index = bowtie2index
            }
            // Map, generate BAM with all reads and unmapped reads in fastq.gz for downstream
            BOWTIE2_FILTERHOST ( 
                ch_reads, 
                ch_bowtie2_index
            )
            ch_versions      = ch_versions.mix( BOWTIE2_FILTERHOST.out.versions.first() )
            ch_multiqc_files = ch_multiqc_files.mix( BOWTIE2_FILTERHOST.out.log )
            ch_reads = BOWTIE2_FILTERHOST.out.reads
        }

        //
    // MODULE: merge reads
    //
    if ( params.perform_runmerging ) {
        ch_reads_for_cat_branch = ch_reads
            .map {
                meta, fastqs ->
                    def meta_new = meta - meta.subMap('run_accession')
                    [ meta_new, fastqs ]
            }
            .groupTuple()
            .map {
                meta, fastqs ->
                    [ meta, fastqs.flatten() ]
            }
            .branch {
                fastqs ->
                cat: ( fastqs.size() > 2 )
                skip: true
            }

        ch_reads_runmerged = MERGE_RUNS ( ch_reads_for_cat_branch.cat ).reads
            .mix( ch_reads_for_cat_branch.skip )
            .map {
                meta, fastqs ->
                [ meta, [ fastqs ].flatten() ]
            }
        ch_versions = ch_versions.mix(MERGE_RUNS.out.versions)
    } else {
        ch_reads_runmerged = ch_reads
    }


        // Subsampling reads
        if(params.skip_subsampling == false){
            SUBSAMPLING (
                ch_reads_runmerged,
                params.subsamplelevel
            )
            ch_versions = ch_versions.mix(SUBSAMPLING.out.versions.first())
            ch_reads = SUBSAMPLING.out.reads
            ch_logs = SUBSAMPLING.out.log.map{it[2]}.collect()
            CAT_READCOUNTS (
                ch_logs
            )
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