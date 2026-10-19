nextflow.enable.types = true

//
// Kraken2 classification and Bracken abundance re-estimation
//
include { Reads; MetagenomicsOptions        } from './types'
include { KRAKEN2_DB                        } from '../../modules/local/kraken2/db'
include { KRAKEN2_KRAKEN2                   } from '../../modules/local/kraken2/kraken2'
include { BRACKEN_BUILD                     } from '../../modules/local/bracken/build'
include { BRACKEN_BRACKEN                   } from '../../modules/local/bracken/bracken'
include { BRACKEN_COMBINEBRACKENOUTPUTS     } from '../../modules/local/bracken/combinebrackenoutputs'
include { BRACKEN_COMBINEKRAKENOUTPUTS      } from '../../modules/local/bracken/combinekrakenoutputs'

workflow KRAKEN {

    take:
    reads: Channel<Reads>
    opts: MetagenomicsOptions

    main:
    //
    // Database: the one given with --kraken2_db, or download a prebuilt one (--kraken2_dbname)
    //
    def ch_dbkraken = opts.kraken2_db
        ? channel.value(opts.kraken2_db)
        : KRAKEN2_DB(opts.kraken2_dbname)

    // The prebuilt databases include Bracken files for common read lengths.
    // Build them only when asked (--bracken_build), e.g. for a custom database or another read length.
    def ch_dbbracken = opts.bracken_build
        ? BRACKEN_BUILD(ch_dbkraken, opts.bracken_readlength, opts.bracken_kmerlength)
        : ch_dbkraken

    //
    // MODULE: Kraken2 classification
    //
    def kraken = KRAKEN2_KRAKEN2(
        reads,
        ch_dbkraken,
        opts.kraken2_save_reads,
        opts.kraken2_save_readclassifications
    )

    //
    // MODULE: Bracken, and tables combining all samples
    //
    def bracken_results = BRACKEN_BRACKEN(   // not 'bracken': an emit name below
        kraken.map { r -> record(id: r.id, report: r.report) },
        ch_dbbracken,
        opts.bracken_readlength,
        opts.bracken_threshold
    )
    def combined_bracken = BRACKEN_COMBINEBRACKENOUTPUTS(
        bracken_results.map { r -> r.report }.collect().map { files -> files.toSorted { a, b -> a.name <=> b.name } }
    )
    def combined_kraken = BRACKEN_COMBINEKRAKENOUTPUTS(
        bracken_results.map { r -> r.txt }.collect().map { files -> files.toSorted { a, b -> a.name <=> b.name } }
    )

    emit:
    report: Channel<Path>  = kraken.map { r -> r.report }
    kraken2: Channel<Path> = channel.empty()
        .mix(kraken.map { r -> r.report })
        .mix(kraken.flatMap { r -> r.classified })
        .mix(kraken.flatMap { r -> r.unclassified })
        .mix(kraken.filter { r -> r.classifiedreads != null }.map { r -> r.classifiedreads })
    bracken: Channel<Path> = channel.empty()
        .mix(bracken_results.map { r -> r.report })
        .mix(bracken_results.map { r -> r.txt })
        .mix(combined_bracken)
        .mix(combined_kraken)
}
