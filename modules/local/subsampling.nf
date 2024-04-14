process SUBSAMPLING {
    tag "$meta.id"
    label 'seqkit'
    label 'error_retry'
    
    input:
    tuple val(meta), path(reads)
    val(subsamplelevel)

    output:
    tuple val(meta), path('*_{1,2}_subsampled.fastq.gz')  , emit: reads
    tuple val(meta), path('*_readcount.txt')              , emit: log
    path "versions.yml"                                   , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def subsample_n = subsamplelevel ? subsamplelevel : 20000000
   
    """
    echo "Calculating stats of unprocessed reads"
    noreads=\$(zcat ${reads[0]} | awk '{s++}END{print s/4}')
    echo "Reads in ${reads[0]}: \$noreads" > "${prefix}_readcount.txt"
    
    echo "Sample has \$noreads reads"
    echo "Calculating proportion: subsampling threshold ${subsample_n}"
    proportion=\$(awk -v num_reads=\$noreads -v subn=${subsample_n} 'BEGIN { printf "%.2f", subn / num_reads + 0.01 }')
    echo "The proportion is \$proportion"

    if (( \$(awk 'BEGIN {print ("'\$proportion'" < 1)}') )); then   
        echo "Downsampling forward reads"
        zcat ${reads[0]} | seqkit sample -s 42 -p \$proportion -o ${prefix}_sample.fastq
        seqkit head ${prefix}_sample.fastq -n ${subsample_n} -o ${prefix}_1_subsampled.fastq.gz
        rm ${prefix}_sample.fastq

        echo "Downsampling reverse reads"
        zcat ${reads[1]} | seqkit sample -s 42 -p \$proportion -o ${prefix}_sample.fastq
        seqkit head ${prefix}_sample.fastq -n ${subsample_n} -o ${prefix}_2_subsampled.fastq.gz
        rm ${prefix}_sample.fastq
    else
        echo "Sample has less than ${subsample_n} reads, skipping subsampling"
        cp ${reads[0]} ${prefix}_1_subsampled.fastq.gz
        cp ${reads[1]} ${prefix}_2_subsampled.fastq.gz
    fi
    echo "Done"
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: \$( seqkit version | sed 's/seqkit v//' )
    END_VERSIONS
    """

    stub:
    def prefix              = task.ext.prefix ?: "${meta.id}"
    """
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: \$( seqkit version | sed 's/seqkit v//' )
    END_VERSIONS
    """
}
