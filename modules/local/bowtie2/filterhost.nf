process BOWTIE2_FILTERHOST {
    tag "$meta.id"
    label "process_high"
    label 'bowtie2'
    
    input:
    tuple val(meta), path(reads)
    path index

    output:
    tuple val(meta), path("*_unmapped*.fastq.gz"), emit: reads
    tuple val(meta), path("*.log"), emit: log
    tuple val(meta), path("*.stats"), emit: stats
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ""
    def ids = meta.run_accession ? "${meta.id}_${meta.run_accession}" : "${meta.id}"
    def prefix = task.ext.prefix ?: "${ids}"
    def reads_args = meta.single_end ? "-U ${reads}" : "-1 ${reads[0]} -2 ${reads[1]}"
    def unmapped_args = meta.single_end ? "--un-gz ${prefix}_unmapped.fastq.gz" : "--un-conc-gz ${prefix}_unmapped.fastq.gz"

    """
    INDEX=`find -L ./ -name "*.rev.1.bt2" | sed "s/\\.rev.1.bt2\$//"`
    [ -z "\$INDEX" ] && INDEX=`find -L ./ -name "*.rev.1.bt2l" | sed "s/\\.rev.1.bt2l\$//"`
    [ -z "\$INDEX" ] && echo "Bowtie2 index files not found" 1>&2 && exit 1

    bowtie2 \\
        -x \$INDEX \\
        $reads_args \\
        --threads $task.cpus \\
        $unmapped_args \\
        $args \\
        2> >(tee ${prefix}.bowtie2.log >&2) \\
        | samtools sort --threads $task.cpus -o ${prefix}.bam -
    
    samtools \\
        index ${prefix}.bam \\
        --threads $task.cpus-1 \\
        -o ${prefix}.bai

    samtools \\
        stats \\
        ${prefix}.bam \\
        --threads $task.cpus \\
        > ${prefix}.stats
    
    rm ${prefix}.bai
    rm ${prefix}.bam

    if [ "${meta.single_end}" == "False" ]; then
        if [ -f ${prefix}_unmapped.fastq.1.gz ]; then
            mv ${prefix}_unmapped.fastq.1.gz ${prefix}_unmapped_1.fastq.gz
        fi

        if [ -f ${prefix}_unmapped.fastq.2.gz ]; then
            mv ${prefix}_unmapped.fastq.2.gz ${prefix}_unmapped_2.fastq.gz
        fi
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bowtie2: \$(echo \$(bowtie2 --version 2>&1) | sed 's/^.*bowtie2-align-s version //; s/ .*\$//')
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
        pigz: \$( pigz --version 2>&1 | sed 's/pigz //g' )
    END_VERSIONS
    """

    stub:
    def args2 = task.ext.args2 ?: ""
    def prefix = task.ext.prefix ?: "${meta.id}"
    def extension_pattern = /(--output-fmt|-O)+\s+(\S+)/
    def extension = (args2 ==~ extension_pattern) ? (args2 =~ extension_pattern)[0][2].toLowerCase() : "bam"
    def create_unmapped = meta.single_end ? "touch ${prefix}_unmapped.fastq.gz" : "touch ${prefix}_unmapped_1.fastq.gz && touch ${prefix}_unmapped_2.fastq.gz"

    """
    touch ${prefix}.${extension}
    touch ${prefix}.bowtie2.log
    touch ${prefix}.bam
    touch ${prefix}.stats
    $create_unmapped

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bowtie2: \$(echo \$(bowtie2 --version 2>&1) | sed 's/^.*bowtie2-align-s version //; s/ .*\$//')
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
        pigz: \$( pigz --version 2>&1 | sed 's/pigz //g' )
    END_VERSIONS
    """
}