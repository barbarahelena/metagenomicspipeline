process HUMANN_HUMANN {
    tag "$meta.id"
    label 'process_medium'
    label 'humann'

    input:
    tuple val(meta), path(input), path(taxprofile)
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
    def input_type = "$input" =~ /.*\.(fastq.gz)$/ ? "fastq.gz" : "$input" =~ /.*\.(fastq|fq)$/ ? "fastq" : "$input" =~ /.*\.(fasta|fna|fa)/ ? "fasta" : "sam"

    """
    mkdir humann_results
    mkdir logs   
    humann \\
        --input $input \\
        --input-format $input_type \\
        --output humann_results/ \\
        --output-basename ${prefix} \\
        --o-log logs/${prefix}.log \\
        --taxonomic-profile $taxprofile \\
        --threads $task.cpus \\
        --memory-use maximum \\
        --search-mode uniref90 \\
        --protein-database $humann_db/uniref \\
        --nucleotide-database $humann_db/chocophlan \\
        $args \\
        --verbose
        


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
