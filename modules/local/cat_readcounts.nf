process CAT_READCOUNTS {
    label 'process_single'
    
    input:
    path readcounts

    output:
    path "*.csv"                , emit: readcounts
    path "versions.yml"         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "readcounts_table"
    """
    # Output file
    output_file="${prefix}.csv"

    # Write the header to the output file
    echo "SampleID,ReadCount" > \$output_file

    # Iterate through all *_readcount.txt files in the folder
    for file in ${readcounts}; do
        # Extract the sampleID from the filename
        sampleID=\$(basename "\$file" _readcount.txt)
        
        # Extract the readcount from the file content
        readcount=\$(grep "Reads in" "\$file" | awk '{print \$4}')
        
        # Check if readcount is not empty
        if [ -n "\$readcount" ]; then
            # Append the sampleID and readcount to the output file
            echo "\$sampleID,\$readcount" >> \$output_file
        else
            echo "Warning: No read count found in \$file"
        fi
    done

    echo "Readcounts table created: \$output_file"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: \$(awk --version 2>&1 | head -n 1 | cut -d ' ' -f 3)
    END_VERSIONS

    """
}
