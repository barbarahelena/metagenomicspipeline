nextflow.enable.types = true

//
// Write text to a file. Runs inside Nextflow (exec): no container, no shell.
// Used for the small text files of the run (versions, git commit, MultiQC sections),
// instead of collectFile, which has no well-defined type.
//
process WRITE_FILE {
    tag name

    input:
    name: String
    content: String

    output:
    file(name)

    exec:
    task.workDir.resolve(name).text = content
}
