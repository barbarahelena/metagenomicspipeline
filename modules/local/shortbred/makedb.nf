process SHORTBRED_MAKEDB {
    label 'process_single'
    storeDir 'db'

    output:
    path "*.faa"                    , emit: db

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    wget https://github.com/biobakery/shortbred/releases/download/0.9.4/ShortBRED_CARD_2017_markers.faa.gz
    gunzip ShortBRED_CARD_2017_markers.faa.gz

    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    // TODO nf-core: A stub section should mimic the execution of the original module as best as possible
    //               Have a look at the following examples:
    //               Simple example: https://github.com/nf-core/modules/blob/818474a292b4860ae8ff88e149fbcda68814114d/modules/nf-core/bcftools/annotate/main.nf#L47-L63
    //               Complex example: https://github.com/nf-core/modules/blob/818474a292b4860ae8ff88e149fbcda68814114d/modules/nf-core/bedtools/split/main.nf#L38-L54
    """
    touch ${prefix}.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        shortbred: \$(samtools --version |& sed '1!d ; s/samtools //')
    END_VERSIONS
    """
}
