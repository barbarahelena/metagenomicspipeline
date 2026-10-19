nextflow.enable.types = true

process BOWTIE2_BUILD {
    tag fasta.name
    label 'process_high'
    label 'bowtie2'
    storeDir 'db'

    input:
    fasta: Path

    output:
    index = files("bowtie2/${fasta.baseName}.*.bt2").toSorted { a, b -> a.name <=> b.name }

    // No versions topic: eval() fails for storeDir tasks taken from the store. BOWTIE2_FILTERHOST reports bowtie2.

    script:
    def args = task.ext.args ?: ''
    """
    mkdir bowtie2
    bowtie2-build ${args} --threads ${task.cpus} ${fasta} bowtie2/${fasta.baseName}
    """

    stub:
    """
    mkdir bowtie2
    touch bowtie2/${fasta.baseName}.{1..4}.bt2
    touch bowtie2/${fasta.baseName}.rev.{1,2}.bt2
    """
}
