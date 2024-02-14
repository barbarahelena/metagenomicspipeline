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
    database

    main:
    ch_versions = Channel.empty()

    //
    // MODULE: HUMANN get database
    //
    HUMANN_MAKEDB ( database )

    //
    // MODULE: HUMANN
    //
    HUMANN_HUMANN(
        reads,
        HUMANN_MAKEDB.out.db,
        database
    )
    ch_versions = ch_versions.mix( HUMANN_HUMANN.out.versions.first() ) // only once since all use same container/conda

    //
    // MODULE: HUMANN fix tables: pathways
    //
    ch_pathways_humann = HUMANN_HUMANN.out.pathways.collect {it[1]}
    HUMANN_MERGETABLESPATH(
        ch_pathways_humann
    )
    //
    // MODULE: HUMANN fix tables: genes
    //
    ch_genes_humann = HUMANN_HUMANN.out.genes.collect {it[1]}
    HUMANN_MERGETABLESGENE(
        ch_genes_humann
    )

    emit:
    versions = ch_versions                   // channel: [ versions.yml ]
}

