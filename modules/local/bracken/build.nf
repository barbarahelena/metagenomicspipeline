process BRACKEN_BUILD {
    memory '350 GB'
    cpus 16
    time '1h'
    queue "highmem"

    input:
    path kraken_db
    val readlength
    val kmerlength

    output:
    path("*.kmer_distrib")       , emit: bracken_db
    path "versions.yml"          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ""
    """
    bracken-build \\
        ${args} \\
        -d ${kraken_db} \\
        -t ${task.cpus} \\
        -k ${kmerlength} \\
        -l ${readlength}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bracken: \$(echo \$(bracken -v) | cut -f2 -d'v')
    END_VERSIONS
    """

    stub:
    """
    touch "bracken.kmer_distrib"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bracken: \$(echo \$(bracken -v) | cut -f2 -d'v')
    END_VERSIONS
    """
}
