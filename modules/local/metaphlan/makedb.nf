nextflow.enable.types = true

process METAPHLAN_MAKEDB {
    label 'process_medium'
    label 'metaphlan'
    storeDir 'db'

    output:
    file('metaphlan_db')

    script:
    def args = task.ext.args ?: ''
    """
    metaphlan \\
        --install \\
        --nproc ${task.cpus} \\
        --db_dir metaphlan_db \\
        ${args}
    """

    stub:
    """
    mkdir metaphlan_db
    touch metaphlan_db/mpa_stub.rev.1.bt2l
    """
}
