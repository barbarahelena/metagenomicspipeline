nextflow.enable.types = true

process FASTP {
    tag run_accession ? "${id}_${run_accession}" : id
    label 'process_medium'
    label 'fastp'

    input:
    record(id: String, single_end: Boolean, run_accession: String?, fastq: List<Path>)
    adapter_fasta: Path?          // null = no adapter list, fastp auto-detects
    save_trimmed_fail: Boolean
    cutright: Boolean
    windowsize: Integer
    meanquality: Integer
    length: Integer

    output:
    sample = record(
        id: id,
        single_end: single_end,
        run_accession: run_accession,
        fastq: files('*.fastp.fastq.gz').toSorted { a, b -> a.name <=> b.name },
        json: file('*.json'),
        html: file('*.html'),
        log: file('*.log'),
        fail: files('*.fail.fastq.gz', optional: true).toSorted { a, b -> a.name <=> b.name }
    )

    topic:
    tuple(task.process, 'fastp', eval('fastp --version 2>&1 | sed -e "s/fastp //g"')) >> 'versions'

    script:
    def args           = task.ext.args ?: ''
    def prefix         = task.ext.prefix ?: (run_accession ? "${id}_${run_accession}" : id)
    def adapter_list   = adapter_fasta ? "--adapter_fasta ${adapter_fasta}" : ""
    def fail_fastq     = !save_trimmed_fail ? "" : single_end ? "--failed_out ${prefix}.fail.fastq.gz" : "--unpaired1 ${prefix}.fail.fastq.gz"
    def cutright_fastp = cutright ? "--cut_right" : ""
    def input_str      = single_end ? "--in1 ${fastq[0]}" : "--in1 ${fastq[0]} --in2 ${fastq[1]}"
    def output_str     = single_end ? "--out1 ${prefix}.fastp.fastq.gz" : "--out1 ${prefix}_1.fastp.fastq.gz --out2 ${prefix}_2.fastp.fastq.gz"
    // Soft-links to the original fastqs give consistent sample names in MultiQC
    def links          = single_end
        ? "[ ! -f ${prefix}.fastq.gz ] && ln -sf ${fastq[0]} ${prefix}.fastq.gz || true"
        : "[ ! -f ${prefix}_1.fastq.gz ] && ln -sf ${fastq[0]} ${prefix}_1.fastq.gz || true\n    [ ! -f ${prefix}_2.fastq.gz ] && ln -sf ${fastq[1]} ${prefix}_2.fastq.gz || true"
    """
    ${links}

    fastp \\
        ${input_str} \\
        ${output_str} \\
        --json ${prefix}.fastp.json \\
        --html ${prefix}.fastp.html \\
        ${adapter_list} \\
        ${fail_fastq} \\
        --thread ${task.cpus} \\
        ${single_end ? '' : '--detect_adapter_for_pe'} \\
        ${cutright_fastp} \\
        --cut_window_size ${windowsize} \\
        --cut_mean_quality ${meanquality} \\
        --length_required ${length} \\
        ${args} \\
        2> >(tee ${prefix}.fastp.log >&2)
    """

    stub:
    def prefix      = task.ext.prefix ?: (run_accession ? "${id}_${run_accession}" : id)
    def touch_reads = single_end ? "${prefix}.fastp.fastq.gz" : "${prefix}_1.fastp.fastq.gz ${prefix}_2.fastp.fastq.gz"
    """
    touch ${touch_reads}
    touch ${prefix}.fastp.json
    touch ${prefix}.fastp.html
    touch ${prefix}.fastp.log
    """
}
