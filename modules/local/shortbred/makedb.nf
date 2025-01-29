process SHORTBRED_MAKEDB {
    label 'process_single'
    storeDir 'db'

    output:
    path "*.faa"                    , emit: db

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    wget https://github.com/biobakery/shortbred/releases/download/0.9.4/ShortBRED_CARD_2017_markers.faa.gz
    gunzip ShortBRED_CARD_2017_markers.faa.gz

    """

    stub:
    """
    touch "shortbred_db.faa"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        shortbred: \$(samtools --version |& sed '1!d ; s/samtools //')
    END_VERSIONS
    """
}
