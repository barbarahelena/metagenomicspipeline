process SAMPLESHEETCHECK {
    tag "$samplesheet"
    label 'process_single'
    label 'python'

    input:
    path samplesheet
    val mergeruns

    output:
    path '*.csv'       , emit: csv
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def merge = mergeruns ? "--mergeruns" : ""

    """
    check_samplesheet.py $merge \\
        $samplesheet \\
        samplesheet.valid.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
