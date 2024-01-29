process METAPHLAN_DB {
    label 'process_medium'
    label 'metaphlan'
    storeDir 'db'

    output:
    path "metaphlan_db"         , emit: db
    path "versions.yml"         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    """
    metaphlan \\
        --install \\
        --nproc $task.cpus \\
        --bowtie2db metaphlan_db \\
        $args
    """
}