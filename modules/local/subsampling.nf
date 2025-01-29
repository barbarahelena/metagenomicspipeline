process SUBSAMPLING {
    tag "$meta.id"
    label 'seqkit'
    label 'error_retry'
    
    input:
    tuple val(meta), path(reads)
    val(subsamplelevel)

    output:
    tuple val(meta), path('*_subsampled.fastq.gz'), emit: reads
    tuple val(meta), path('*_readcount.txt'), emit: log
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def subsample_n = subsamplelevel ? subsamplelevel : 20000000
    """
    echo "Calculating stats of unprocessed reads"
    if [ "${meta.single_end}" == "True" ]; then
        noreads=\$(zcat ${reads} | awk '{s++}END{print s/4}')
        echo "Reads in : \$noreads" > "${prefix}_readcount.txt"
    else
        noreads=\$(zcat ${reads[0]} | awk '{s++}END{print s/4}')
        echo "Reads in : \$noreads" > "${prefix}_readcount.txt"
    fi
    
    echo "Sample has \$noreads reads"
    echo "Calculating proportion: subsampling threshold ${subsample_n}"
    proportion=\$(awk -v num_reads=\$noreads -v subn=${subsample_n} 'BEGIN { printf "%.2f", subn / num_reads + 0.01 }')
    echo "The proportion is \$proportion"

    if (( \$(awk 'BEGIN {print ("'\$proportion'" < 1)}') )); then   
        echo "Downsampling reads"
        if [ "${meta.single_end}" == "True" ]; then
            zcat ${reads} | seqkit sample -s 42 -p \$proportion -o ${prefix}_sample.fastq
            seqkit head ${prefix}_sample.fastq -n ${subsample_n} -o ${prefix}_subsampled.fastq.gz
            rm ${prefix}_sample.fastq
        else
            zcat ${reads[0]} | seqkit sample -s 42 -p \$proportion -o ${prefix}_1_sample.fastq
            zcat ${reads[1]} | seqkit sample -s 42 -p \$proportion -o ${prefix}_2_sample.fastq
            seqkit head ${prefix}_1_sample.fastq -n ${subsample_n} -o ${prefix}_1_subsampled.fastq.gz
            seqkit head ${prefix}_2_sample.fastq -n ${subsample_n} -o ${prefix}_2_subsampled.fastq.gz
            rm ${prefix}_1_sample.fastq ${prefix}_2_sample.fastq
        fi
    else
        echo "Sample has less than ${subsample_n} reads, skipping subsampling"
        if [ "${meta.single_end}" == "True" ]; then
            cp ${reads} ${prefix}_subsampled.fastq.gz
        else
            cp ${reads[0]} ${prefix}_1_subsampled.fastq.gz
            cp ${reads[1]} ${prefix}_2_subsampled.fastq.gz
        fi
    fi
    echo "Done"
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: \$( seqkit version | sed 's/seqkit v//' )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_readcount.txt
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: \$( seqkit version | sed 's/seqkit v//' )
    END_VERSIONS
    """
}