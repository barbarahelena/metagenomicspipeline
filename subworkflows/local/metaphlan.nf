//
// Metaphlan: database download (stored process), metaphlan and merge metaphlan tables
//

include { METAPHLAN_MAKEDB                  } from '../../modules/local/metaphlan/makedb'
include { METAPHLAN_METAPHLAN               } from '../../modules/local/metaphlan/metaphlan'
include { METAPHLAN_MERGETABLES             } from '../../modules/local/metaphlan/mergetables'

workflow METAPHLAN {

    take:
    reads

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    //
    // MODULE: Metaphlan database
    //
    METAPHLAN_MAKEDB ( )

    //
    // MODULE: Metaphlan profiling
    //
    METAPHLAN_METAPHLAN (
        reads,
        METAPHLAN_MAKEDB.out.db
    )
    ch_versions        = ch_versions.mix( METAPHLAN_METAPHLAN.out.versions.first() )

    //
    // MODULE: Metaphlan merge tables
    //
    ch_profiles_metaphlan = METAPHLAN_METAPHLAN.out.profile.collect {it[1]}

    METAPHLAN_MERGETABLES ( ch_profiles_metaphlan )
    ch_multiqc_files = ch_multiqc_files.mix( METAPHLAN_MERGETABLES.out.txt )
    ch_versions = ch_versions.mix( METAPHLAN_MERGETABLES.out.versions )

    emit:
    profiles = METAPHLAN_METAPHLAN.out.profile // channel [ meta, Metaphlan profile ]
    multiqc_metaphlan = ch_multiqc_files       // channel: multiqc files
    versions = ch_versions                     // channel: [ versions.yml ]
}

