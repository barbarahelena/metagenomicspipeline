//
// Humann: database download (stored processes), humann, merge gene tables and pathway tables
//

include { HUMANN_MAKEDB                     } from '../../modules/local/humann/makedb'
include { HUMANN_HUMANN                     } from '../../modules/local/humann/humann'
include { HUMANN_MERGETABLESGENE            } from '../../modules/local/humann/mergetablesgene'
include { HUMANN_MERGETABLESPATH            } from '../../modules/local/humann/mergetablespath'

workflow HUMANN {

    take:
    reads

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    //
    // MODULE: HUMANN get database
    //
    HUMANN_MAKEDB ( )
    //
    // MODULE: HUMANN
    //
    HUMANN_HUMANN(
        reads,
        HUMANN_MAKEDB.out.db
    )
    //
    // MODULE: HUMANN tables
    //
    ch_pathways_humann = HUMANN_HUMANN.out.pathways.collect {it[1]}
    ch_genes_humann = HUMANN_HUMANN.out.genes.collect {it[1]}
    HUMANN_MERGETABLESPATH(
        ch_pathways_humann
    )
    HUMANN_MERGETABLESGENE(
        ch_genes_humann
    )

    ch_versions = ch_versions.mix( HUMANN_HUMANN.out.versions.first() )

    emit:
    versions = ch_versions                     // channel: [ versions.yml ]
}

