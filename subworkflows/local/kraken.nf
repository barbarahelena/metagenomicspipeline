//
// Kraken subworkflow: kraken and bracken
//

include { KRAKEN2_DB                        } from '../../modules/local/kraken2/db'
include { KRAKEN2_KRAKEN2                   } from '../../modules/local/kraken2/kraken2'
include { BRACKEN_BUILD                     } from '../../modules/local/bracken/build'
include { BRACKEN_BRACKEN                   } from '../../modules/local/bracken/bracken'
include { BRACKEN_COMBINEBRACKENOUTPUTS     } from '../../modules/local/bracken/combinebrackenoutputs'
include { BRACKEN_COMBINEKRAKENOUTPUTS      } from '../../modules/local/bracken/combinekrakenoutputs'

workflow KRAKEN {

    take:
    reads
    kraken2_db

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()
    if(! kraken2_db) {
        KRAKEN2_DB( params.kraken2_dbname )
        ch_dbkraken = KRAKEN2_DB.out.db
    } else {
        ch_dbkraken = kraken2_db
    }
    //
    // MODULE: Kraken profiling
    //
    KRAKEN2_KRAKEN2 (
        reads, 
        ch_dbkraken, 
        params.kraken2_save_reads, 
        params.kraken2_save_readclassifications
    )
    ch_versions        = ch_versions.mix( KRAKEN2_KRAKEN2.out.versions.first() )
    ch_multiqc_files   = ch_multiqc_files.mix( KRAKEN2_KRAKEN2.out.report )

    pathdb = file("${kraken2_db}/*${params.bracken_readlength}mers.kmer_distrib")
    kmer_distrib_exists = params.kraken2_db ? !pathdb.isEmpty() : false

    //
    // Module: Bracken build
    //
    if ((!kmer_distrib_exists) | params.bracken_build ) {
        BRACKEN_BUILD( 
            ch_dbkraken,
            params.bracken_readlength,
            params.bracken_kmerlength
        )
        ch_dbbracken = BRACKEN_BUILD.out.bracken_db
        ch_versions = ch_versions.mix(BRACKEN_BUILD.out.versions)
    }
    if (kmer_distrib_exists) {
        ch_dbbracken = ch_dbkraken
    }

    //
    // MODULE: Bracken
    //
    BRACKEN_BRACKEN(
        KRAKEN2_KRAKEN2.out.report, 
        ch_dbbracken,
        params.bracken_readlength,
        params.bracken_threshold
        )
    ch_versions     = ch_versions.mix(BRACKEN_BRACKEN.out.versions.first())

    ch_profiles_bracken = BRACKEN_BRACKEN.out.reports.collect {it[1]}
    BRACKEN_COMBINEBRACKENOUTPUTS( ch_profiles_bracken )
    ch_profiles_kraken = BRACKEN_BRACKEN.out.txt.collect { it[1] }
    BRACKEN_COMBINEKRAKENOUTPUTS( ch_profiles_kraken )

    emit:
    report = KRAKEN2_KRAKEN2.out.report                 // channel [ meta, Kraken report ]
    mqc      = ch_multiqc_files                         // channel: multiqc files
    versions = ch_versions                              // channel: [ versions.yml ]
}

