process CONCAT {
    tag "$meta.id"
    label 'process_single'
    label 'seqtk'
    
    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path('*_concat.fastq.gz')            , emit: concats
    tuple val(meta), path('*_concat.out')                   , emit: log
    path "versions.yml"                                   , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
  
    """
    [ ! -f  ${prefix}_1.fastq.gz ] && ln -sf ${reads[0]} ${prefix}_1.fastq.gz
    [ ! -f  ${prefix}_2.fastq.gz ] && ln -sf ${reads[1]} ${prefix}_2.fastq.gz

    cat ${prefix}_1_subsampled.fastq.gz ${prefix}_2_subsampled.fastq.gz > ${prefix}_concat.fastq.gz

    seqkit stats -b ${prefix}_concat.fastq.gz > ${prefix}_concat.out
        
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