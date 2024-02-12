process HUMANN_MERGETABLESPATH {
    label 'process_single'
    label 'humann'
    publishDir 'humann/', mode: 'copy'

    input:
    path(paths)

    output:
    path "pathway_abundance.txt"               , emit: path
    path "pathway_abundance_cpm.txt"           , emit: pathcpm
    path "pathway_abundance_cpm_stratified.txt", emit: pathstrata
    path "versions.yml"                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    
    """
    echo "directory: \$PWD"

    humann_join_tables \\
        --input \$PWD \\
        --output pathway_abundance.txt

    humann_renorm_table \\
        --input pathway_abundance.txt \\
        --units cpm \\
        --output pathway_abundance_cpm.txt

    humann_split_stratified_table \\
        --input pathway_abundance_cpm.txt \\
        --output ./
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        humann: \$(humann --version 2>&1 | awk '{print \$2}')
    END_VERSIONS
    """
}
