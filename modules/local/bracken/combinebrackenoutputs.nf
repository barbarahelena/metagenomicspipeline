process BRACKEN_COMBINEBRACKENOUTPUTS {
    label 'process_single'

    input:
    path input

    output:
    path("*.txt")               , emit: txt
    path "versions.yml"         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "combined_brackenoutput"
    // WARN: Version information not provided by tool on CLI.
    // Please update version string below when bumping container versions.
    def VERSION = '2.9'
    """
    combine_bracken_outputs.py \\
        $args \\
        --files ${input} \\
        -o ${prefix}.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        combine_bracken_output: ${VERSION}
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    // WARN: Version information not provided by tool on CLI.
    // Please update version string below when bumping container versions.
    def VERSION = '2.9'
    """
    touch ${prefix}.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        combine_bracken_output: ${VERSION}
    END_VERSIONS
    """
}
