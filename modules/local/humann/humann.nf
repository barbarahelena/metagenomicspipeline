process HUMANN_HUMANN {
    tag "$meta.id"
    label 'error_retry_humann'
    label 'humann'
    label 'humann_publish'
    cpus 8
    memory '24.GB'
    time '3.h'
    conda "${moduleDir}/environment.yml"

    input:
    tuple val(meta), path(reads)
    path humann_db
    val database

    output:
    tuple val(meta), path("humann_results/*_pathabundance.tsv")  ,                emit: pathways
    tuple val(meta), path("humann_results/*_pathcoverage.tsv")   ,                emit: reactions
    tuple val(meta), path("humann_results/*_genefamilies.tsv")   ,                emit: genes
    tuple val(meta), path("logs/*.log")                          ,                emit: log
    path "versions.yml"                                          ,                emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def unirefdatabase = database ? database : "uniref90_ec_filtered_diamond"
    def folder = unirefdatabase == "uniref90_ec_filtered_diamond" ? "uniref_filt" : unirefdatabase == "uniref90_diamond" ? "uniref" : "otherdb"

    """
    BT2_DB=`find -L "${humann_db}/metaphlan_db_oct22" -name "*rev.1.bt2*" -exec dirname {} \\;`
    BT2_DB_INDEX=`find -L "${humann_db}/metaphlan_db_oct22" -name "*.rev.1.bt2*" | sed 's/\\.rev.1.bt2.*\$//' | sed 's/.*\\///'`

    mkdir humann_results
    mkdir logs
    if [ "${meta.single_end}" == "True" ]; then
        cp ${reads} ${prefix}_concat.fastq.gz
    else
        cat ${reads[0]} ${reads[1]} > ${prefix}_concat.fastq.gz
    fi

    humann --help

    humann \\
        ${args} \\
        --input ${prefix}_concat.fastq.gz \\
        --input-format "fastq.gz" \\
        --output humann_results/ \\
        --output-basename ${prefix} \\
        --o-log logs/${prefix}.log \\
        --threads $task.cpus \\
        --memory-use minimum \\
        --protein-database $humann_db/$folder/uniref \\
        --nucleotide-database $humann_db/chocophlan \\
        --utility-database $humann_db/$folder/utility_mapping \\
        --metaphlan-options "--bowtie2db \$BT2_DB --index \$BT2_DB_INDEX -t rel_ab_w_read_stats" \\
        --remove-temp-output \\
        --verbose
        
    rm ${prefix}_concat.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        humann: 3.9
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir humann_results
    mkdir logs
    touch humann_results/${prefix}_pathabundance.tsv
    touch humann_results/${prefix}_pathcoverage.tsv
    touch humann_results/${prefix}_genefamilies.tsv
    touch logs/${prefix}.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        humann: 3.9
    END_VERSIONS
    """
}
