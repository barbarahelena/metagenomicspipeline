nextflow.enable.types = true

process BRACKEN_COMBINEKRAKENOUTPUTS {
    label 'process_single'

    conda "conda-forge::pandas=1.4.3"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:1.4.3' :
        'biocontainers/pandas:1.4.3' }"

    input:
    reports: List<Path>   // Kraken2-style Bracken reports, one per sample

    output:
    file('*.txt')

    topic:
    tuple(task.process, 'python', eval('python --version 2>&1 | sed "s/Python //"')) >> 'versions'
    tuple(task.process, 'pandas', eval('python -c "import pandas; print(pandas.__version__)"')) >> 'versions'

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "combined_krakenoutput"
    """
    combine_kraken_outputs.py \\
        ${args} \\
        ${reports.join(' ')} \\
        -o ${prefix}.txt
    """

    stub:
    def prefix = task.ext.prefix ?: "combined_krakenoutput"
    """
    touch ${prefix}.txt
    """
}
