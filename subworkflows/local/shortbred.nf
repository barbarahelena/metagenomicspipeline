//
// ShortBRED
//

include { SHORTBRED_MAKEDB                  } from '../../modules/local/shortbred/makedb'
include { SHORTBRED_SHORTBRED               } from '../../modules/local/shortbred/shortbred'

workflow SHORTBRED {

    take:
    reads

    main:
    ch_versions = Channel.empty()

    //
    // MODULE: ShortBRED get database
    //
    SHORTBRED_MAKEDB ( )

    //
    // MODULE: ShortBRED
    //
    SHORTBRED_SHORTBRED (
        reads,
        SHORTBRED_MAKEDB.out.db
    )
    ch_versions = ch_versions.mix( SHORTBRED_SHORTBRED.out.versions.first() ) // only once since all use same container/conda

    emit:
    versions = ch_versions                   // channel: [ versions.yml ]
}

