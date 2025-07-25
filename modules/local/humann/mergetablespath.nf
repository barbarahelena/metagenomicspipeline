process HUMANN_MERGETABLESPATH {
    label 'process_single'
    label 'humann'
    label 'humann_publish'
    conda "${moduleDir}/environment.yml"

    input:
    path(paths)

    output:
    path "pathway_abundance.txt"                    , emit: path
    path "pathway_abundance_cpm.txt"                , emit: pathcpm
    path "pathway_abundance_cpm_stratified.txt"     , emit: pathstrata
    path "pathway_abundance_cpm_unstratified.txt"   , emit: pathnostrata
    path "versions.yml"                             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:    
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
        humann: 3.9
    END_VERSIONS
    """
    stub:
    """
    touch pathway_abundance.txt
    touch pathway_abundance_cpm.txt
    touch pathway_abundance_cpm_stratified.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        humann: 3.9
    END_VERSIONS
    """
}