process HUMANN_MERGETABLESGENE {
    label 'process_single'
    label 'humann'
    label 'humann_publish'

    input:
    path(genes)

    output:
    path "gene_families.txt"                , emit: genes
    path "gene_families_cpm.txt"            , emit: genescpm
    path "gene_families_cpm_stratified.txt" , emit: genesstrata
    path "versions.yml"                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    
    """
    echo "directory: \$PWD"

    humann_join_tables \\
        --input \$PWD \\
        --output gene_families.txt

    humann_renorm_table \\
        --input gene_families.txt \\
        --units cpm \\
        --output gene_families_cpm.txt

    humann_split_stratified_table \\
        --input gene_families_cpm.txt \\
        --output ./
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        humann: \$(humann --version 2>&1 | awk '{print \$2}')
    END_VERSIONS
    """
}
