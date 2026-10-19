nextflow.enable.types = true

//
// MetaPhlAn: database download (stored process), profiling and merged abundance table
//
include { Reads                             } from './types'
include { METAPHLAN_MAKEDB                  } from '../../modules/local/metaphlan/makedb'
include { METAPHLAN_METAPHLAN               } from '../../modules/local/metaphlan/metaphlan'
include { METAPHLAN_MERGETABLES             } from '../../modules/local/metaphlan/mergetables'

workflow METAPHLAN {

    take:
    reads: Channel<Reads>

    main:
    def db       = METAPHLAN_MAKEDB()
    def metaphlan = METAPHLAN_METAPHLAN(reads, db)   // not 'profiles': an emit name below

    // Sorted by file name, so the column order of the merged table is reproducible
    def merged = METAPHLAN_MERGETABLES(
        metaphlan.map { r -> r.profile }.collect().map { files -> files.toSorted { a, b -> a.name <=> b.name } }
    )

    emit:
    profiles: Channel<Path> = metaphlan.map { r -> r.profile }
    results: Channel<Path>  = channel.empty()
        .mix(metaphlan.map { r -> r.profile })
        .mix(metaphlan.map { r -> r.sambz })
        .mix(metaphlan.filter { r -> r.mapout != null }.map { r -> r.mapout })
        .mix(merged)
}
