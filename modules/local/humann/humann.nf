nextflow.enable.types = true

process HUMANN_HUMANN {
    tag id
    label 'error_retry_humann'
    label 'humann'
    cpus 8
    memory 24.GB
    time 3.h
    conda "${moduleDir}/environment.yml"

    input:
    record(id: String, single_end: Boolean, fastq: List<Path>)
    humann_db: Path

    output:
    sample = record(
        id: id,
        pathways: file('humann_results/*_pathabundance.tsv'),
        reactions: file('humann_results/*_reactions.tsv'),
        genes: file('humann_results/*_genefamilies.tsv'),
        log: file('logs/*.log')
    )

    topic:
    tuple(task.process, 'humann', eval('humann --version 2>&1 | sed "s/humann v//"')) >> 'versions'

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: id
    def concat = single_end ? "cp ${fastq[0]} ${prefix}_concat.fastq.gz" : "cat ${fastq[0]} ${fastq[1]} > ${prefix}_concat.fastq.gz"
    """
    BT2_DB=`find -L "${humann_db}/metaphlan_db" -name "*rev.1.bt2*" -exec dirname {} \\;`
    BT2_DB_INDEX=`find -L "${humann_db}/metaphlan_db" -name "*.rev.1.bt2*" | sed 's/\\.rev.1.bt2.*\$//' | sed 's/.*\\///'`

    mkdir humann_results
    mkdir logs
    ${concat}

    humann \\
        ${args} \\
        --input ${prefix}_concat.fastq.gz \\
        --input-format "fastq.gz" \\
        --output humann_results/ \\
        --output-basename ${prefix} \\
        --o-log logs/${prefix}.log \\
        --threads ${task.cpus} \\
        --memory-use minimum \\
        --protein-database ${humann_db}/uniref \\
        --nucleotide-database ${humann_db}/chocophlan \\
        --utility-database ${humann_db}/utility_mapping \\
        --metaphlan-options "--bowtie2db \$BT2_DB --index \$BT2_DB_INDEX -t rel_ab_w_read_stats" \\
        --remove-temp-output \\
        --verbose

    rm ${prefix}_concat.fastq.gz
    """

    stub:
    def prefix = task.ext.prefix ?: id
    """
    mkdir humann_results
    mkdir logs
    touch humann_results/${prefix}_pathabundance.tsv
    touch humann_results/${prefix}_reactions.tsv
    touch humann_results/${prefix}_genefamilies.tsv
    touch logs/${prefix}.log
    """
}
