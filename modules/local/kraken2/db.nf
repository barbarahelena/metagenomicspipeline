nextflow.enable.types = true

process KRAKEN2_DB {
    tag db_name
    storeDir 'db/kraken2'

    input:
    db_name: String   // core_nt, standard_64gb, standard_16gb or standard_8gb

    output:
    file(db_name)

    topic:
    tuple(task.process, 'kraken2_db', db_link(db_name)) >> 'versions'

    script:
    """
    mkdir -p ${db_name}
    wget -O ${db_name}.tar.gz https://genome-idx.s3.amazonaws.com/kraken/${db_link(db_name)}.tar.gz

    # Extract preserving original database structure
    tar -xzf ${db_name}.tar.gz -C ${db_name}
    rm ${db_name}.tar.gz
    ls -la ${db_name}/
    """

    stub:
    """
    mkdir -p ${db_name}
    touch ${db_name}/hash.k2d
    touch ${db_name}/opts.k2d
    touch ${db_name}/taxo.k2d
    """
}

// Name of the prebuilt index for each database (https://benlangmead.github.io/aws-indexes/k2)
def db_link(db_name: String) -> String {
    def links = [
        core_nt      : 'k2_core_nt_20241228',
        standard_64gb: 'k2_standard_20241228',
        standard_16gb: 'k2_standard_16gb_20241228',
        standard_8gb : 'k2_standard_08gb_20241228'
    ]
    if (!links.containsKey(db_name)) {
        error "Unknown Kraken2 database name: ${db_name}. Choose one of: ${links.keySet().join(', ')}"
    }
    return links[db_name]
}
