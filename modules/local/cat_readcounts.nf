nextflow.enable.types = true

process CAT_READCOUNTS {
    label 'process_single'

    input:
    readcounts: List<Path>   // *_readcount.txt, one per sample

    output:
    file('*.csv')

    topic:
    // GNU awk knows --version, mawk (Ubuntu's default) only -W version
    tuple(task.process, 'awk', eval('{ awk --version 2>/dev/null || awk -W version 2>&1; } | head -n 1')) >> 'versions'

    script:
    def prefix = task.ext.prefix ?: "readcounts_table"
    """
    output_file="${prefix}.csv"
    echo "SampleID,ReadCount" > \$output_file

    for file in ${readcounts.join(' ')}; do
        sampleID=\$(basename "\$file" _readcount.txt)
        readcount=\$(grep "Reads in" "\$file" | awk '{print \$4}')
        if [ -n "\$readcount" ]; then
            echo "\$sampleID,\$readcount" >> \$output_file
        else
            echo "Warning: No read count found in \$file"
        fi
    done

    echo "Readcounts table created: \$output_file"
    """

    stub:
    def prefix = task.ext.prefix ?: "readcounts_table"
    """
    touch ${prefix}.csv
    """
}
