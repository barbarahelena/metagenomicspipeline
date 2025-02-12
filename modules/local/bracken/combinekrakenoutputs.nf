process BRACKEN_COMBINEKRAKENOUTPUTS {
    label 'process_single'

    conda "conda-forge::pandas=1.4.3"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:1.4.3' :
        'biocontainers/pandas:1.4.3' }"

    input:
    path input

    output:
    path("*.txt")               , emit: txt
    path "versions.yml"         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "combined_krakenoutput"
    """
    combine_kraken_outputs.py \\
        $args \\
        ${input} \\
        -o ${prefix}.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "\$(python --version | awk '{print \$2}')"
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "combined_krakenoutput"
    """
    touch ${prefix}.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "\$(python --version | awk '{print \$2}')"
    END_VERSIONS
    """
}
