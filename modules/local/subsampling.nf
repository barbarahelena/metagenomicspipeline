nextflow.enable.types = true

process SUBSAMPLING {
    tag id
    label 'seqkit'
    label 'error_retry'

    input:
    record(id: String, single_end: Boolean, fastq: List<Path>)
    subsamplelevel: Integer   // number of reads (pairs) to keep

    output:
    sample = record(
        id: id,
        single_end: single_end,
        fastq: files('*_subsampled.fastq.gz').toSorted { a, b -> a.name <=> b.name },
        readcount: file('*_readcount.txt')
    )

    topic:
    tuple(task.process, 'seqkit', eval('seqkit version | sed "s/seqkit v//"')) >> 'versions'

    script:
    def prefix = task.ext.prefix ?: id
    def sample_cmd = ''
    def copy_cmd   = ''
    if (single_end) {
        sample_cmd = """
        zcat ${fastq[0]} | seqkit sample -s 42 -p \$proportion -o ${prefix}_sample.fastq
        seqkit head ${prefix}_sample.fastq -n ${subsamplelevel} -o ${prefix}_subsampled.fastq.gz
        rm ${prefix}_sample.fastq
        """
        copy_cmd = "cp ${fastq[0]} ${prefix}_subsampled.fastq.gz"
    } else {
        sample_cmd = """
        zcat ${fastq[0]} | seqkit sample -s 42 -p \$proportion -o ${prefix}_1_sample.fastq
        zcat ${fastq[1]} | seqkit sample -s 42 -p \$proportion -o ${prefix}_2_sample.fastq
        seqkit head ${prefix}_1_sample.fastq -n ${subsamplelevel} -o ${prefix}_1_subsampled.fastq.gz
        seqkit head ${prefix}_2_sample.fastq -n ${subsamplelevel} -o ${prefix}_2_subsampled.fastq.gz
        rm ${prefix}_1_sample.fastq ${prefix}_2_sample.fastq
        """
        copy_cmd = "cp ${fastq[0]} ${prefix}_1_subsampled.fastq.gz\n        cp ${fastq[1]} ${prefix}_2_subsampled.fastq.gz"
    }
    """
    echo "Calculating stats of unprocessed reads"
    noreads=\$(zcat ${fastq[0]} | awk '{s++}END{print s/4}')
    echo "Reads in : \$noreads" > "${prefix}_readcount.txt"

    echo "Sample has \$noreads reads"
    echo "Calculating proportion: subsampling threshold ${subsamplelevel}"
    proportion=\$(awk -v num_reads=\$noreads -v subn=${subsamplelevel} 'BEGIN { printf "%.2f", subn / num_reads + 0.01 }')
    echo "The proportion is \$proportion"

    if (( \$(awk 'BEGIN {print ("'\$proportion'" < 1)}') )); then
        echo "Downsampling reads"
        ${sample_cmd}
    else
        echo "Sample has less than ${subsamplelevel} reads, skipping subsampling"
        ${copy_cmd}
    fi
    echo "Done"
    """

    stub:
    def prefix = task.ext.prefix ?: id
    """
    touch ${prefix}_readcount.txt
    ${single_end ? "touch ${prefix}_subsampled.fastq.gz" : "touch ${prefix}_1_subsampled.fastq.gz ${prefix}_2_subsampled.fastq.gz"}
    """
}
