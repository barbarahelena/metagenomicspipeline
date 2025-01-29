process BRACKEN_BRACKEN {
    tag "$meta.id"
    label 'process_low'

    input:
    tuple val(meta), path(kraken_report)
    path database
    val readlength
    val threshold

    output:
    tuple val(meta), path(bracken_report)               , emit: reports
    tuple val(meta), path(bracken_kraken_style_report)  , emit: txt
    path "versions.yml"                                 , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ""
    def prefix = task.ext.prefix ?: "${meta.id}"
    bracken_report = "${prefix}.tsv"
    bracken_kraken_style_report = "${prefix}.kraken2.report_bracken.txt"
    """
    bracken \\
        ${args} \\
        -t ${threshold} \\
        -r '${readlength}' \\
        -d '${database}' \\
        -i '${kraken_report}' \\
        -o '${bracken_report}' \\
        -w '${bracken_kraken_style_report}'

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bracken: \$(echo \$(bracken -v) | cut -f2 -d'v')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    bracken_report = "${prefix}.tsv"
    bracken_kraken_style_report = "${prefix}.kraken2.report_bracken.txt"
    """
    touch ${prefix}.tsv
    touch ${bracken_kraken_style_report}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bracken: \$(echo \$(bracken -v) | cut -f2 -d'v')
    END_VERSIONS
    """
}
