nextflow.enable.types = true

process METAPHLAN_MERGETABLES {
    label 'process_medium'
    label 'metaphlan'

    input:
    profiles: List<Path>

    output:
    file('combined_table.txt')

    topic:
    tuple(task.process, 'metaphlan', eval('metaphlan --version 2>&1 | awk \'{print $3}\'')) >> 'versions'

    script:
    def args = task.ext.args ?: ''
    """
    merge_metaphlan_tables.py \\
        ${args} \\
        -o combined_table.txt \\
        ${profiles.join(' ')}
    """

    stub:
    """
    touch combined_table.txt
    """
}
