nextflow.enable.types = true

//
// HUMAnN: database download (stored process), functional profiling, merged pathway tables
//
include { Reads                             } from './types'
include { HUMANN_MAKEDB                     } from '../../modules/local/humann/makedb'
include { HUMANN_HUMANN                     } from '../../modules/local/humann/humann'
include { HUMANN_MERGETABLESPATH            } from '../../modules/local/humann/mergetablespath'

workflow HUMANN {

    take:
    reads: Channel<Reads>
    database: String        // UniRef database name

    main:
    def db     = HUMANN_MAKEDB(database)
    def humann = HUMANN_HUMANN(reads, db)

    def merged = HUMANN_MERGETABLESPATH(
        humann.map { r -> r.pathways }.collect().map { files -> files.toSorted { a, b -> a.name <=> b.name } }
    )

    emit:
    results: Channel<Path> = channel.empty()
        .mix(humann.map { r -> r.pathways })
        .mix(humann.map { r -> r.reactions })
        .mix(humann.map { r -> r.genes })
        .mix(humann.map { r -> r.log })
        .mix(merged.path)
        .mix(merged.pathcpm)
        .mix(merged.pathstrata)
        .mix(merged.pathnostrata)
}
