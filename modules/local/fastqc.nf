nextflow.enable.types = true

//
// FastQC on the raw reads. Adapted from the nf-core/modules fastqc module (MIT license).
//
process FASTQC {
    tag id
    label 'process_low'
    label 'fastqc'

    input:
    record(id: String, fastq: List<Path>)

    stage:
    stageAs fastq, '?/*'   // runs can have the same file names

    output:
    sample = record(
        id: id,
        html: files('*.html').toSorted { a, b -> a.name <=> b.name },
        zip: files('*.zip').toSorted { a, b -> a.name <=> b.name }
    )

    topic:
    tuple(task.process, 'fastqc', eval('fastqc --version | sed "/FastQC v/!d; s/.*v//"')) >> 'versions'

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: id
    // Link the reads to <prefix>.fastq.gz (single-end) or <prefix>_1/_2.fastq.gz, so the reports are named after the sample
    def indices   = (0..<fastq.size()).toList()
    def new_names = indices.collect { i -> fastq.size() == 1 ? "${prefix}.${fastq[i].extension}" : "${prefix}_${i + 1}.${fastq[i].extension}" }.toList()
    def link_cmds = indices.collect { i -> "[ -f ${new_names[i]} ] || ln -s ${fastq[i]} ${new_names[i]}" }.join('\n    ')
    def renamed   = new_names.join(' ')
    // FastQC allocates --memory per thread; keep the total within the task's memory (100-10000 MB per thread)
    def memory_per_thread = task.memory ? (task.memory.toUnit('MB') / task.cpus).intValue() : 0
    def memory_arg        = memory_per_thread ? "--memory ${Math.max(100, Math.min(10000, memory_per_thread))}" : ''
    """
    ${link_cmds}

    fastqc \\
        ${args} \\
        --threads ${task.cpus} \\
        ${memory_arg} \\
        ${renamed}
    """

    stub:
    def prefix = task.ext.prefix ?: id
    """
    touch ${prefix}.html
    touch ${prefix}.zip
    """
}
