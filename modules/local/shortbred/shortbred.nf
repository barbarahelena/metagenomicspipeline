process SHORTBRED_SHORTBRED {
    tag "$meta.id"
    label 'process_low'
    label 'shortbred'
    label 'shortbred_publish'

    input:
    tuple val(meta), path(reads), path(profile)
    path database

    output:
    path "*_shortbred"            , emit: shortbred
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    cat ${reads[0]} ${reads[1]} > ${prefix}_concat.fastq.gz

    shortbred_quantify.py $args \\
                --markers ${database} \\
                --wgs ${prefix}_concat.fastq.gz \\
                --results ${prefix}_shortbred \\
                --usearch usearch
                
    rm ${prefix}_concat.fastq.gz

    shortbred_version=\$(shortbred_identify.py --version |& sed '1!d ; s/shortbred //')
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        shortbred: \$shortbred_version
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.bam

    shortbred_version=\$(shortbred_identify.py --version |& sed '1!d ; s/shortbred //')
    cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            shortbred: \$shortbred_version
    END_VERSIONS
    """
}
