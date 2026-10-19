nextflow.enable.types = true

process SHORTBRED_MAKEDB {
    label 'process_single'
    storeDir 'db'

    output:
    file('*.faa')

    topic:
    tuple(task.process, 'shortbred_markers', 'CARD_2017') >> 'versions'

    script:
    """
    wget https://github.com/biobakery/shortbred/releases/download/0.9.4/ShortBRED_CARD_2017_markers.faa.gz
    gunzip ShortBRED_CARD_2017_markers.faa.gz
    """

    stub:
    """
    touch ShortBRED_CARD_2017_markers.faa
    """
}
