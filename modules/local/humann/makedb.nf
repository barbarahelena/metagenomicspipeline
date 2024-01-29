process HUMANN_MAKEDB {
    label 'process_medium'
    label 'humann'
    storeDir 'db'

    output:
    path "humann_db"            , emit: db

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    """
    humann_databases \\
        --download chocophlan full humann_db \\
        --update-config no
        
    humann_databases \\
        --download uniref uniref90_diamond humann_db \\
        --update-config no
    """
}
