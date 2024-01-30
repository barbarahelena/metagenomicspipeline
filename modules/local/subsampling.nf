process SUBSAMPLING {
    tag "$meta.id"
    label 'process_medium'
    label 'seqtk'
    
    input:
    tuple val(meta), path(reads)
    val(subsamplelevel)

    output:
    tuple val(meta), path('*_{1,2}_subsampled.fastq.gz')  , emit: reads
    tuple val(meta), path('*_concat.fastq.gz')            , emit: concats
    path "versions.yml"                                   , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def subsample_n = subsamplelevel ? subsamplelevel : 20000000
   
    """
    [ ! -f  ${prefix}_1.fastq.gz ] && ln -sf ${reads[0]} ${prefix}_1.fastq.gz
    [ ! -f  ${prefix}_2.fastq.gz ] && ln -sf ${reads[1]} ${prefix}_2.fastq.gz

	seqtk sample -s128 ${prefix}_1.fastq.gz $subsample_n | gzip >  ${prefix}_1_subsampled.fastq.gz
	seqtk sample -s128 ${prefix}_2.fastq.gz $subsample_n | gzip >  ${prefix}_2_subsampled.fastq.gz
    cat ${prefix}_1_subsampled.fastq.gz ${prefix}_2_subsampled.fastq.gz > ${prefix}_concat.fastq.gz

    cat <<-'END_VERSIONS' > versions.yml
    "${task.process}":
        seqtk: \$(echo \$(seqtk 2>&1) | sed 's/^.*Version: //; s/ .*//')
    END_VERSIONS
    """

    stub:
    def prefix              = task.ext.prefix ?: "${meta.id}"

    """

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqtk: \$(echo \$(seqtk 2>&1) | sed 's/^.*Version: //; s/ .*\$//')
    END_VERSIONS
    """
}
