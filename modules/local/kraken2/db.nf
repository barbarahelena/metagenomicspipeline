process KRAKEN2_DB {
    memory { task.ext.memory }
    cpus { task.ext.cpus }
    time { task.ext.time }
    queue { task.ext.queue }
    storeDir "/db/kraken2"

    input:
    val(db_name)
    
    output:
    path("${db_name}")        , emit: kraken_db
    path "versions.yml"       , emit: versions

    script:
    def db_link = db_name == 'core_nt' ? 'k2_core_nt_20241228' :
                  db_name == 'standard_8gb' ? 'k2_standard_08gb_20241228' :
                  db_name == 'standard_16gb' ? 'k2_standard_16gb_20241228' :
                  { error "Unknown database name: ${db_name}" }()

    """
    mkdir -p ${db_name}
    wget -O ${db_name}.tar.gz https://genome-idx.s3.amazonaws.com/kraken/${db_link}.tar.gz
    tar -xvf ${db_name}.tar.gz -C ${db_name} --strip-components 1
    rm ${db_name}.tar.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kraken2: \$(kraken2 --version 2>&1 | sed 's/^.*Kraken version //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p ${db_name}
    touch ${db_name}/hash.k2d
    touch ${db_name}/opts.k2d
    touch ${db_name}/taxo.k2d

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kraken2: \$(kraken2 --version 2>&1 | sed 's/^.*Kraken version //; s/ .*\$//')
    END_VERSIONS
    """
}
