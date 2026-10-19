nextflow.enable.types = true

process METAPHLAN_METAPHLAN {
    tag id
    label 'process_medium'
    label 'metaphlan'
    label 'error_retry'

    input:
    record(id: String, single_end: Boolean, fastq: List<Path>)
    metaphlan_db: Path

    output:
    sample = record(
        id: id,
        profile: file('*_profile.txt'),
        sambz: file('*.sam.bz2'),
        mapout: file('*.mapout.txt', optional: true)
    )

    topic:
    tuple(task.process, 'metaphlan', eval('metaphlan --version 2>&1 | awk \'{print $3}\'')) >> 'versions'

    script:
    def args       = task.ext.args ?: ''
    def prefix     = task.ext.prefix ?: id
    def input_data = single_end ? "${fastq[0]}" : "${fastq[0]},${fastq[1]}"
    """
    BT2_DB=`find -L "${metaphlan_db}" -name "*rev.1.bt2*" -exec dirname {} \\;`
    BT2_DB_INDEX=`find -L ${metaphlan_db} -name "*.rev.1.bt2*" | sed 's/\\.rev.1.bt2.*\$//' | sed 's/.*\\///'`

    metaphlan \\
        --nproc ${task.cpus} \\
        --input_type fastq \\
        ${input_data} \\
        ${args} \\
        --mapout ${prefix}.mapout.txt \\
        -t rel_ab_w_read_stats \\
        -s ${prefix}.sam.bz2 \\
        --db_dir \$BT2_DB \\
        --index \$BT2_DB_INDEX \\
        --output_file ${prefix}_profile.txt
    """

    stub:
    def prefix = task.ext.prefix ?: id
    """
    touch ${prefix}.sam.bz2
    touch ${prefix}.mapout.txt
    touch ${prefix}_profile.txt
    """
}
