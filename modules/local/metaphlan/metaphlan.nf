process METAPHLAN_METAPHLAN {
    tag "$meta.id"
    label 'process_medium'
    label 'metaphlan'
    label 'metaphlan_publish'
    label 'error_retry'

    input:
    tuple val(meta), path(input)
    path metaphlan_db

    output:
    tuple val(meta), path("*_profile.txt")   ,                emit: profile
    tuple val(meta), path("*.sam.bz2")       ,                emit: sambz
    tuple val(meta), path("*.biom")          ,                emit: biom
    tuple val(meta), path('*.bowtie2out.txt'), optional:true, emit: bt2out
    path "versions.yml"                      ,                emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def input_type = "$input" =~ /.*\.(fastq|fq)/ ? "--input_type fastq" : "$input" =~ /.*\.(fasta|fna|fa)/ ? "--input_type fasta" : "$input".endsWith(".bowtie2out.txt") ? "--input_type bowtie2out" : "--input_type sam"
    def input_data  = "$input_type".contains("fastq") && !meta.single_end ? "${input[0]},${input[1]}" : "$input"
    def bowtie2_out = "$input_type" == "--input_type bowtie2out" || "$input_type" == "--input_type sam" ? '' : "--bowtie2out ${prefix}.bowtie2out.txt"

    """
    BT2_DB=`find -L "${metaphlan_db}" -name "*rev.1.bt2*" -exec dirname {} \\;`
    BT2_DB_INDEX=`find -L ${metaphlan_db} -name "*.rev.1.bt2*" | sed 's/\\.rev.1.bt2.*\$//' | sed 's/.*\\///'`
    
    metaphlan \\
        --nproc $task.cpus \\
        $input_type \\
        $input_data \\
        $args \\
        $bowtie2_out \\
        -t rel_ab_w_read_stats \\
        -s ${prefix}.sam.bz2 \\
        --bowtie2db \$BT2_DB \\
        --index \$BT2_DB_INDEX \\
        --biom ${prefix}.biom \\
        --output_file ${prefix}_profile.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        metaphlan: \$(metaphlan --version 2>&1 | awk '{print \$3}')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.bowtie2out.txt
    touch ${prefix}.sam.bz2
    touch ${prefix}.biom
    touch ${prefix}_profile.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        metaphlan: \$(metaphlan --version 2>&1 | awk '{print \$3}')
    END_VERSIONS
    """
}
