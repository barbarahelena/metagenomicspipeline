process FASTP {
    tag "$meta.id"
    label 'process_medium'
    label 'fastp'
    
    input:
    tuple val(meta), path(reads)
    path  adapter_fasta
    val   save_trimmed_fail
    val   cutright
    val   windowsize
    val   meanquality
    val   length

    output:
    tuple val(meta), path('*.fastp.fastq.gz')        , emit: reads
    tuple val(meta), path('*.json')                  , emit: json
    tuple val(meta), path('*.html')                  , emit: html
    tuple val(meta), path('*.log')                   , emit: log
    path "versions.yml"                              , emit: versions
    tuple val(meta), path('*.fail.fastq.gz')         , optional:true, emit: reads_fail

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def adapter_list = adapter_fasta ? "--adapter_fasta ${adapter_fasta}" : ""
    def fail_fastq = save_trimmed_fail && !meta.single_end ? "--unpaired1 ${prefix}.fail.fastq.gz" : (save_trimmed_fail && meta.single_end ? "--failed_out ${prefix}.fail.fastq.gz" : "")
    def cutright = cutright ? "--cut_right" : ""

    // Determine input and output based on single-end or paired-end
    def input_str = meta.single_end ? "--in1 ${reads[0]}" : "--in1 ${reads[0]} --in2 ${reads[1]}"
    def output_str = meta.single_end ? "--out1 ${prefix}.fastp.fastq.gz" : "--out1 ${prefix}_1.fastp.fastq.gz --out2 ${prefix}_2.fastp.fastq.gz"

    // Added soft-links to original fastqs for consistent naming in MultiQC
    """
    ${meta.single_end ? "[ ! -f  ${prefix}.fastq.gz ] && ln -sf ${reads[0]} ${prefix}.fastq.gz" : "[ ! -f  ${prefix}_1.fastq.gz ] && ln -sf ${reads[0]} ${prefix}_1.fastq.gz && [ ! -f  ${prefix}_2.fastq.gz ] && ln -sf ${reads[1]} ${prefix}_2.fastq.gz"}
    
    fastp \\
        $input_str \\
        $output_str \\
        --json ${prefix}.fastp.json \\
        --html ${prefix}.fastp.html \\
        $adapter_list \\
        $fail_fastq \\
        --thread $task.cpus \\
        ${meta.single_end ? '' : '--detect_adapter_for_pe'} \\
        $cutright \\
        --cut_window_size $windowsize \\
        --cut_mean_quality $meanquality \\
        --length_required $length \\
        $args \\
        2> >(tee ${prefix}.fastp.log >&2)

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastp: \$(fastp --version 2>&1 | sed -e "s/fastp //g")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def touch_reads = meta.single_end ? "${prefix}.fastp.fastq.gz" : "${prefix}_1.fastp.fastq.gz ${prefix}_2.fastp.fastq.gz"
    """
    touch $touch_reads
    touch "${prefix}.fastp.json"
    touch "${prefix}.fastp.html"
    touch "${prefix}.fastp.log"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastp: \$(fastp --version 2>&1 | sed -e "s/fastp //g")
    END_VERSIONS
    """
}