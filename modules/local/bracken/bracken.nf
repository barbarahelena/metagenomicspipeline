nextflow.enable.types = true

process BRACKEN_BRACKEN {
    tag id
    label 'process_low'

    input:
    record(id: String, report: Path)   // Kraken2 report
    database: Path                     // Kraken2 database with database<readlength>mers.kmer_distrib
    readlength: Integer
    threshold: Integer

    output:
    sample = record(
        id: id,
        report: file("${id}.tsv"),
        txt: file("${id}.kraken2.report_bracken.txt")
    )

    topic:
    tuple(task.process, 'bracken', eval('bracken -v | cut -f2 -d"v"')) >> 'versions'

    script:
    def args = task.ext.args ?: ""
    """
    bracken \\
        ${args} \\
        -t ${threshold} \\
        -r '${readlength}' \\
        -d '${database}' \\
        -i '${report}' \\
        -o '${id}.tsv' \\
        -w '${id}.kraken2.report_bracken.txt'
    """

    stub:
    """
    touch ${id}.tsv
    touch ${id}.kraken2.report_bracken.txt
    """
}
