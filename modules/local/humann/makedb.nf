process HUMANN_MAKEDB {
    label 'process_medium'
    label 'humann'
    storeDir 'db'

    input:
    val database

    output:
    path "humann_db"            , emit: db

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def unirefdatabase = database ? database : "uniref90_ec_filtered_diamond"
    def folder = unirefdatabase == "uniref90_ec_filtered_diamond" ? "uniref_filt" : unirefdatabase == "uniref90_diamond" ? "uniref" : "otherdb" 
    """
    mkdir humann_db

    humann_databases \\
        $args \\
        --download chocophlan full humann_db \\
        --update-config no
        
    humann_databases \\
        $args \\
        --download uniref $unirefdatabase humann_db/$folder \\
        --update-config no
    """
}
