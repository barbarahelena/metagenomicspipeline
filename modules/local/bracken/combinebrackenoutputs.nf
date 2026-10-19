nextflow.enable.types = true

process BRACKEN_COMBINEBRACKENOUTPUTS {
    label 'process_single'

    input:
    reports: List<Path>   // Bracken reports, one per sample

    output:
    file('*.txt')

    topic:
    // combine_bracken_outputs.py ships with Bracken and has no version option of its own
    tuple(task.process, 'bracken', eval('bracken -v | cut -f2 -d"v"')) >> 'versions'

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "combined_brackenoutput"
    """
    combine_bracken_outputs.py \\
        ${args} \\
        --files ${reports.join(' ')} \\
        -o ${prefix}.txt
    """

    stub:
    def prefix = task.ext.prefix ?: "combined_brackenoutput"
    """
    touch ${prefix}.txt
    """
}
