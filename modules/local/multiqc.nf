nextflow.enable.types = true

//
// MultiQC report of the whole run. Adapted from the nf-core/modules multiqc module (MIT license).
//
process MULTIQC {
    label 'process_single'
    label 'multiqc'

    input:
    multiqc_files: List<Path>
    multiqc_config: List<Path>   // the pipeline's config, and optionally the user's (--multiqc_config)
    multiqc_logo: Path?

    stage:
    stageAs multiqc_files, '?/*'    // reports of different tools can have the same file names
    stageAs multiqc_config, 'config?/*'

    output:
    record(
        report: file('*.html'),
        data: file('*_data'),
        plots: file('*_plots', optional: true)
    )

    // No versions topic: MultiQC reads the collected versions, so it cannot also report to them.
    // Its version is printed in the report.

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ? "--filename ${task.ext.prefix}.html" : ''
    def config = multiqc_config.collect { f -> "--config ${f}" }.join(' ')
    def logo   = multiqc_logo ? "--cl-config 'custom_logo: \"${multiqc_logo}\"'" : ''
    """
    multiqc \\
        --force \\
        ${args} \\
        ${config} \\
        ${prefix} \\
        ${logo} \\
        .
    """

    stub:
    """
    mkdir multiqc_data
    touch multiqc_data/.stub
    mkdir multiqc_plots
    touch multiqc_plots/.stub
    touch multiqc_report.html
    """
}
