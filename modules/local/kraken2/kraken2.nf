nextflow.enable.types = true

process KRAKEN2_KRAKEN2 {
    tag id

    input:
    record(id: String, single_end: Boolean, fastq: List<Path>)
    db: Path
    save_output_fastqs: Boolean
    save_reads_assignment: Boolean

    output:
    sample = record(
        id: id,
        report: file('*report.txt'),
        classified: files('*.classified{.,_}*', optional: true).toSorted { a, b -> a.name <=> b.name },
        unclassified: files('*.unclassified{.,_}*', optional: true).toSorted { a, b -> a.name <=> b.name },
        classifiedreads: file('*classifiedreads.txt', optional: true)
    )

    topic:
    tuple(task.process, 'kraken2', eval('kraken2 --version 2>&1 | head -n 1 | sed "s/^.*Kraken version //; s/ .*//"')) >> 'versions'

    script:
    def args                      = task.ext.args ?: ''
    def prefix                    = task.ext.prefix ?: id
    def paired                    = single_end ? "" : "--paired"
    def classified                = single_end ? "${prefix}.classified.fastq"   : "${prefix}.classified#.fastq"
    def unclassified              = single_end ? "${prefix}.unclassified.fastq" : "${prefix}.unclassified#.fastq"
    def classified_option         = save_output_fastqs ? "--classified-out ${classified}" : ""
    def unclassified_option       = save_output_fastqs ? "--unclassified-out ${unclassified}" : ""
    def readclassification_option = save_reads_assignment ? "--output ${prefix}.kraken2.classifiedreads.txt" : "--output /dev/null"
    """
    kraken2 \\
        --db ${db} \\
        --threads ${task.cpus} \\
        --report ${prefix}.kraken2.report.txt \\
        --gzip-compressed \\
        ${unclassified_option} \\
        ${classified_option} \\
        ${readclassification_option} \\
        ${paired} \\
        ${args} \\
        ${fastq.join(' ')}
    """

    stub:
    def prefix = task.ext.prefix ?: id
    """
    touch ${prefix}.kraken2.report.txt
    ${save_reads_assignment ? "touch ${prefix}.kraken2.classifiedreads.txt" : ''}
    """
}
