nextflow.enable.types = true

process BRACKEN_BUILD {
    tag kraken_db.name

    input:
    kraken_db: Path
    readlength: Integer
    kmerlength: Integer

    output:
    file('bracken_db')

    topic:
    tuple(task.process, 'bracken', eval('bracken -v | cut -f2 -d"v"')) >> 'versions'

    script:
    def args = task.ext.args ?: ""
    // bracken-build writes its files into the database folder. Build into a folder of links
    // to the Kraken2 database, so the input database itself is not modified.
    """
    mkdir bracken_db
    ln -s \$(readlink -f ${kraken_db})/* bracken_db/

    bracken-build \\
        ${args} \\
        -d bracken_db \\
        -t ${task.cpus} \\
        -k ${kmerlength} \\
        -l ${readlength}
    """

    stub:
    """
    mkdir bracken_db
    touch bracken_db/database${readlength}mers.kmer_distrib
    """
}
