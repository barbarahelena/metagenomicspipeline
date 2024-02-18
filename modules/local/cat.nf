process CAT {
    tag "$meta.id"
    label 'process_single'
    label 'cat'

    input:
    tuple val(meta), path(reads, stageAs: "input*/*")

    output:
    tuple val(meta), path("*.merged.fastq.gz")  , emit: reads
    path "versions.yml"                         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def readList = reads instanceof List ? reads.collect{ it.toString() } : [reads.toString()]
    if (readList.size >= 2) {
        def read1 = []
        def read2 = []
        readList.eachWithIndex{ v, ix -> ( ix & 1 ? read2 : read1 ) << v }
        """
        cat ${read1.join(' ')} > ${prefix}_1.merged.fastq.gz
        cat ${read2.join(' ')} > ${prefix}_2.merged.fastq.gz

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            cat: \$(echo \$(cat --version 2>&1) | sed 's/^.*coreutils) //; s/ .*\$//')
        END_VERSIONS
        """
    }

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def readList = reads instanceof List ? reads.collect{ it.toString() } : [reads.toString()]
    if (readList.size > 2) {
        """
        touch ${prefix}_1.merged.fastq.gz
        touch ${prefix}_2.merged.fastq.gz

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            cat: \$(echo \$(cat --version 2>&1) | sed 's/^.*coreutils) //; s/ .*\$//')
        END_VERSIONS
        """
    }
}
