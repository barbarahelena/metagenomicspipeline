nextflow.enable.types = true

//
// ShortBRED: marker database download (stored process) and quantification
//
include { Reads                             } from './types'
include { SHORTBRED_MAKEDB                  } from '../../modules/local/shortbred/makedb'
include { SHORTBRED_SHORTBRED               } from '../../modules/local/shortbred/shortbred'

workflow SHORTBRED {

    take:
    reads: Channel<Reads>

    main:
    def db        = SHORTBRED_MAKEDB()
    def shortbred = SHORTBRED_SHORTBRED(reads, db)

    emit:
    shortbred.map { r -> r.shortbred }
}
