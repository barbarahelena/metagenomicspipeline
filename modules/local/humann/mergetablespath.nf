nextflow.enable.types = true

process HUMANN_MERGETABLESPATH {
    label 'process_single'
    label 'humann'
    conda "${moduleDir}/environment.yml"

    input:
    paths: List<Path>   // *_pathabundance.tsv, one per sample

    output:
    path         = file('pathway_abundance.txt')
    pathcpm      = file('pathway_abundance_cpm.txt')
    pathstrata   = file('pathway_abundance_cpm_stratified.txt')
    pathnostrata = file('pathway_abundance_cpm_unstratified.txt')

    topic:
    tuple(task.process, 'humann', eval('humann --version 2>&1 | sed "s/humann v//"')) >> 'versions'

    script:
    """
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
    """

    stub:
    """
    touch pathway_abundance.txt
    touch pathway_abundance_cpm.txt
    touch pathway_abundance_cpm_stratified.txt
    touch pathway_abundance_cpm_unstratified.txt
    """
}
