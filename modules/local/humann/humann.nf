process HUMANN_HUMANN {
    tag "$meta.id"
    label 'process_medium'
    label 'humann'
    publishDir 'humann/', mode: 'copy'

    input:
    tuple val(meta), path(reads), path(taxprofile)
    path humann_db

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
    def profile = "$taxprofile" == true ? "" : "--taxonomic-profile $taxprofile"

    """
    mkdir humann_results
    mkdir logs
    echo $reads
    echo ${reads}
    cat ${reads[0]} ${reads[1]} > ${prefix}_concat.fastq.gz

    humann \\
        --input ${prefix}_concat.fastq.gz \\
        --input-format "fastq.gz" \\
        --output humann_results/ \\
        --output-basename ${prefix} \\
        --o-log logs/${prefix}.log \\
        $profile \\
        --threads $task.cpus \\
        --memory-use maximum \\
        --search-mode uniref90 \\
        --protein-database $humann_db/uniref \\
        --nucleotide-database $humann_db/chocophlan \\
        $args \\
        --verbose
    rm ${prefix}_concat.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        humann: \$(humann --version 2>&1 | awk '{print \$2}')
    END_VERSIONS
    """
    stub:
     """
    

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        humann: \$(humann --version 2>&1 | awk '{print \$2}')
    END_VERSIONS
    """
}
