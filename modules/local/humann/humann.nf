process HUMANN_HUMANN {
    tag "$meta.id"
    label 'error_retry_humann'
    label 'humann'
    label 'humann_publish'
    cpus 8
    memory '24.GB'
    time '3.h'

    input:
    tuple val(meta), path(reads), path(taxprofile)
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
    def profile = "$taxprofile" == true ? "" : "--taxonomic-profile $taxprofile"
    def unirefdatabase = database ? database : "uniref90_ec_filtered_diamond"
    def folder = unirefdatabase == "uniref90_ec_filtered_diamond" ? "uniref_filt" : unirefdatabase == "uniref90_diamond" ? "uniref" : "otherdb" 

    """
    mkdir humann_results
    mkdir logs
    cat ${reads[0]} ${reads[1]} > ${prefix}_concat.fastq.gz

    humann \\
        --input ${prefix}_concat.fastq.gz \\
        --input-format "fastq.gz" \\
        --output humann_results/ \\
        --output-basename ${prefix} \\
        --o-log logs/${prefix}.log \\
        $profile \\
        --threads $task.cpus \\
        --memory-use minimum \\
        --search-mode uniref90 \\
        --protein-database $humann_db/$folder/uniref \\
        --nucleotide-database $humann_db/chocophlan \\
        --remove-temp-output \\
        $args \\
        --verbose
        
    rm ${prefix}_concat.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        humann: \$(humann --version 2>&1 | grep -oP 'humann v\\K\\d+\\.\\d+' || echo "FAILED)
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
        humann: \$(humann --version 2>&1 | grep -oP 'humann v\\K\\d+\\.\\d+' || echo "FAILED)
    END_VERSIONS
    """
}
