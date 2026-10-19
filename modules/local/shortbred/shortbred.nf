nextflow.enable.types = true

process SHORTBRED_SHORTBRED {
    tag id
    label 'process_low'
    label 'shortbred'

    input:
    record(id: String, single_end: Boolean, fastq: List<Path>)
    database: Path   // ShortBRED marker file (.faa)

    output:
    sample = record(id: id, shortbred: file("${id}_shortbred"))

    topic:
    tuple(task.process, 'shortbred', eval('shortbred_identify.py --version 2>&1 | sed "1!d; s/shortbred //"')) >> 'versions'

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: id
    """
    cat ${fastq.join(' ')} > ${prefix}_concat.fastq.gz

    shortbred_quantify.py ${args} \\
        --markers ${database} \\
        --wgs ${prefix}_concat.fastq.gz \\
        --results ${prefix}_shortbred \\
        --usearch usearch

    rm ${prefix}_concat.fastq.gz
    """

    stub:
    def prefix = task.ext.prefix ?: id
    """
    touch ${prefix}_shortbred
    """
}
