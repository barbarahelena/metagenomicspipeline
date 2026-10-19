# metagenomicspipeline: Usage

## Introduction

The metagenomicspipeline takes shotgun metagenomics reads (single-end or paired-end), removes low-quality and host reads, subsamples them to an equal depth and profiles them with MetaPhlAn (taxonomy) and HUMAnN (functions). Kraken2/Bracken and ShortBRED can be switched on. See [parameters.md](parameters.md) for all options and [output.md](output.md) for the results.

The pipeline needs [Nextflow](https://www.nextflow.io/docs/latest/install.html) 26.10.0 or later, and Docker, Singularity/Apptainer or Conda for the software.

## Samplesheet input

You will need to create a samplesheet with information about the samples you would like to analyse before running the pipeline. Use this parameter to specify its location:

```bash
--input '[path to samplesheet file]'
```

It is a comma-separated file with a header row and these columns:

| Column          | Description                                                                                                                                 |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `sample`        | Sample name, without spaces. Numbers (e.g. participant IDs) are fine.                                                                       |
| `run_accession` | Optional. Name of the sequencing run, needed when a sample has several rows (runs); see [Run merging](#run-merging).                        |
| `fastq_1`       | Path to the FastQ file with reads 1 (or the single-end reads). Gzipped, with the extension `.fastq.gz` or `.fq.gz`.                         |
| `fastq_2`       | Path to the FastQ file with reads 2. Leave empty for single-end reads.                                                                      |

For example, with two paired-end samples and one single-end sample:

```csv
sample,fastq_1,fastq_2
CONTROL_REP1,AEG588A1_S1_L002_R1_001.fastq.gz,AEG588A1_S1_L002_R2_001.fastq.gz
CONTROL_REP2,AEG588A2_S2_L002_R1_001.fastq.gz,AEG588A2_S2_L002_R2_001.fastq.gz
CONTROL_REP3,AEG588A3_S3_L002_R1_001.fastq.gz,
```

An [example samplesheet](../assets/samplesheet.csv) has been provided with the pipeline.

The samplesheet is checked before the pipeline starts (against [assets/schema_input.json](../assets/schema_input.json)): missing files, wrong extensions and duplicate sample names stop the run with an error message.

Paths can be absolute, remote (`s3://`, `https://`) or relative. Relative paths are read relative to the folder you launch the pipeline from or, if no file is found there, relative to the folder of the samplesheet, so a samplesheet can sit next to its data.

### Run merging

If a sample was sequenced in several runs, give each run its own row with the same `sample` name and a different `run_accession`, and use `--perform_runmerging`:

```csv
sample,run_accession,fastq_1,fastq_2
SAMPLE1,RUN1,SAMPLE1_RUN1_R1.fastq.gz,SAMPLE1_RUN1_R2.fastq.gz
SAMPLE1,RUN2,SAMPLE1_RUN2_R1.fastq.gz,SAMPLE1_RUN2_R2.fastq.gz
SAMPLE2,RUN1,SAMPLE2_RUN1_R1.fastq.gz,SAMPLE2_RUN1_R2.fastq.gz
```

The runs are quality-filtered and host-filtered separately, then merged before subsampling. Without `--perform_runmerging`, a sample name may appear only once. The runs of a sample must all be single-end or all paired-end.

## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run barbarahelena/metagenomicspipeline \
  --input ./samplesheet.csv \
  --outdir ./results \
  --genome GRCh38 \
  -profile docker
```

This will launch the pipeline with the `docker` configuration profile. See below for more information about profiles.

Note that the pipeline will create the following files in your working directory:

```bash
work                # Directory containing the nextflow working files
<OUTDIR>            # Finished results in specified location (defined with --outdir)
db                  # Downloaded databases and the Bowtie2 index, reused by later runs
.nextflow.log       # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

The parameters are checked before anything runs: a value of the wrong type (`--subsamplelevel ten`), a file that does not exist or a misspelled parameter (`--skip_kraken2`) stops the run with an error. Run `nextflow run barbarahelena/metagenomicspipeline --help` for the list of parameters, or `--help <parameter>` for one of them.

If you wish to repeatedly use the same parameters for multiple runs, rather than specifying each flag in the command, you can specify these in a params file.

Pipeline settings can be provided in a `yaml` or `json` file via `-params-file <file>`.

> [!WARNING]
> Do not use `-c <file>` to specify parameters as this will result in errors. Custom config files specified with `-c` must only be used for [tuning resources](#resources), other infrastructural tweaks (such as output directories), or [tool arguments](#custom-tool-arguments).

The above pipeline run specified with a params file in yaml format:

```bash
nextflow run barbarahelena/metagenomicspipeline -profile docker -params-file params.yaml
```

with `params.yaml` containing:

```yaml
input: './samplesheet.csv'
outdir: './results/'
genome: 'GRCh38'
<...>
```

## Host reference genome

Reads from the host (e.g. human reads) are removed with Bowtie2. Give the host genome in one of three ways:

- `--bowtie2_index <dir>`: a folder with a prebuilt Bowtie2 index (`*.bt2`). Fastest.
- `--fasta <file>`: a FASTA file; the pipeline builds the index once and stores it in `db/bowtie2/`.
- `--genome GRCh38`: a reference from [iGenomes](https://emea.support.illumina.com/sequencing/sequencing_software/igenome.html) (paths in [conf/igenomes.config](../conf/igenomes.config)).

Use `--skip_hostfilter` if your reads were already host-filtered.

## Profilers

| Profiler            | Runs by default | Switch                     | Database                                                    |
| ------------------- | --------------- | -------------------------- | ----------------------------------------------------------- |
| MetaPhlAn           | yes             | `--skip_metaphlan`         | downloaded (about 50 GB)                                    |
| HUMAnN              | yes             | `--skip_humann`            | downloaded (about 65 GB with the default `--humann_db`)     |
| Kraken2 and Bracken | no              | `--skip_kraken false`      | `--kraken2_db <dir>`, or downloaded with `--kraken2_dbname` |
| ShortBRED           | no              | `--skip_shortbred false`   | downloaded (CARD 2017 markers)                              |

### Kraken2 databases

Without `--kraken2_db`, the pipeline downloads one of the [prebuilt Kraken2 databases](https://benlangmead.github.io/aws-indexes/k2) (version 2024-12-28). Kraken2 loads the whole database in memory:

| `--kraken2_dbname`        | Memory for Kraken2 |
| ------------------------- | ------------------ |
| `standard_8gb`            | 12 GB              |
| `standard_16gb` (default) | 20 GB              |
| `standard_64gb`           | 100 GB             |
| `core_nt`                 | 250 GB             |

The prebuilt databases include the Bracken files for common read lengths. Set `--bracken_readlength` to the read length of your data (default 150). For a custom database without Bracken files, add `--bracken_build`.

## Databases

The databases are downloaded the first time you use a profiler, so the first run takes longer. They are stored in the folder `db/` in the folder you launch the pipeline from; altogether MetaPhlAn and HUMAnN need about 115 GB. Later runs from the same folder find them there and skip the download.

Nextflow only checks whether the database folder exists, not what is in it. Delete the folder in `db/` if you change something that affects a database (e.g. another `--humann_db` or `--kraken2_dbname`, or switching from `-profile test_full`, which uses small HUMAnN test databases, to a real run). Launch the pipeline from the same folder each time to reuse the databases.

## Updating the pipeline

When you run the above command, Nextflow automatically pulls the pipeline code from GitHub and stores it as a cached version. When running the pipeline after this, it will always use the cached version if available - even if the pipeline has been updated since. To make sure that you're running the latest version of the pipeline, make sure that you regularly update the cached version of the pipeline:

```bash
nextflow pull barbarahelena/metagenomicspipeline
```

## Reproducibility

It is a good idea to specify a pipeline version when running the pipeline on your data. This ensures that a specific version of the pipeline code and software are used when you run your pipeline. If you keep using the same tag, you'll be running the same version of the pipeline, even if there have been changes to the code since.

First, go to the [releases page](https://github.com/barbarahelena/metagenomicspipeline/releases) and find the latest pipeline version - numeric only (eg. `2.0.0`). Then specify this when running the pipeline with `-r` (one hyphen) - eg. `-r 2.0.0`. Of course, you can switch to another version by changing the number after the `-r` flag.

This version number will be logged in reports when you run the pipeline, so that you'll know what you used when you look back in the future. The exact commit is written to `pipeline_info/git_commit_hash.txt`, and the version of every tool to `pipeline_info/software_versions.tsv`.

With the same input, parameters and pipeline version, the pipeline gives the same results: subsampling uses a fixed seed, and the steps before it keep the reads in the same order.

To further assist in reproducibility, you can share and re-use [parameter files](#running-the-pipeline) to repeat pipeline runs with the same settings without having to write out a command with every single parameter.

> [!TIP]
> If you wish to share such a file (such as upload as supplementary material for academic publications), make sure to NOT include cluster specific paths to files, nor institutional specific profiles.

## Core Nextflow arguments

> [!NOTE]
> These options are part of Nextflow and use a _single_ hyphen (pipeline parameters use a double-hyphen).

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments.

Note that multiple profiles can be loaded, for example: `-profile test,docker` - the order of arguments is important!
They are loaded in sequence, so later profiles can overwrite earlier profiles.

If `-profile` is not specified, the pipeline will run locally and expect all software to be installed and available on the `PATH`. This is _not_ recommended, since it can lead to different results on different machines dependent on the computer environment.

> [!IMPORTANT]
> We highly recommend the use of Docker or Singularity/Apptainer containers for full pipeline reproducibility, however when this is not possible, Conda is also supported.

Software:

- `docker`: [Docker](https://docker.com/)
- `singularity`, `apptainer`: [Singularity](https://sylabs.io/docs/) or [Apptainer](https://apptainer.org/), the usual choice on HPCs
- `podman`, `shifter`, `charliecloud`: other container engines
- `conda`, `mamba`: [Conda](https://conda.io/docs/) environments. Please only use Conda as a last resort, when it's not possible to use containers.
- `arm`: add this on an Apple Silicon Mac (e.g. `-profile docker,arm`): several tools have no arm64 builds, so they run as x86_64 through emulation.

Test data:

- `test`: a small mock gut community with known composition in `assets/testdata`, with Kraken2/Bracken on and MetaPhlAn/HUMAnN off. Needs no other parameters or downloads.
- `test_full`: larger test with MetaPhlAn, HUMAnN (with its small demo databases) and Kraken2 (`standard_8gb`). Downloads the databases.

Compute environments:

- `snellius`: the Snellius HPC (SURF): SLURM, Singularity, and job names without special characters
- `beast`: a large local server: at most 80 CPUs and 200 GB per task, and at most 2 MetaPhlAn and HUMAnN tasks at once
- `local`: at most 2 MetaPhlAn and HUMAnN tasks at once
- `dkfz_plus`: LSF cluster with Singularity
- `debug`: keeps the work files and prints more information

The pipeline also loads the institutional profiles of [nf-core/configs](https://github.com/nf-core/configs) when it runs, so you can use the profile of your institution if it is listed there.

### `-resume`

Specify this when restarting a pipeline. Nextflow will use cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously. For input to be considered the same, not only the names must be identical but the files' contents as well. For more info about this parameter, see [this blog post](https://www.nextflow.io/blog/2019/demystifying-nextflow-resume.html).

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

### `-c`

Specify the path to a specific config file (this is a core Nextflow command). See the [Nextflow documentation](https://www.nextflow.io/docs/latest/config.html) for more information, and the sections below for examples.

## Custom configuration

### Resources

Each step has a default number of CPUs, memory and time (by label in [conf/base.config](../conf/base.config)). Failed tasks are retried once (twice for the steps that fail most on clusters), and most steps get more memory and time on each retry. No task requests more than 16 CPUs, 128 GB memory or 240 hours; these limits are lower in the `test` profiles and higher in `beast` and `dkfz_plus`.

To change the limits for your machine or cluster, or the resources of one step, put this in a config file and add it with `-c custom.config`:

```groovy
process {
    // The most any single task may request
    resourceLimits = [ cpus: 32, memory: 256.GB, time: 48.h ]

    withName: 'HUMANN_HUMANN' {
        cpus   = 16
        memory = 48.GB
    }
}
```

### Custom tool arguments

A pipeline might not always support every possible argument or option of a particular tool used in pipeline. Most steps take extra arguments with `ext.args` in a config file, e.g.:

```groovy
process {
    withName: 'METAPHLAN_METAPHLAN' {
        ext.args = '--min_mapq_val 5'
    }
    withName: 'BOWTIE2_FILTERHOST' {
        ext.args = '--very-sensitive'
    }
}
```

The process names are in the log of a run (e.g. `METAGENOMICSPIPELINE:PREPROCESSING:FASTP`; the last part is enough).

### HPC settings

I had some problems getting Nextflow pipelines to work on an HPC. This is a short list of issues I encountered with solutions. These solutions are all implemented, although for SLURM use and the job name replacement you have to use `-profile snellius`.

#### Use singularity

Docker usually does not work on HPCs for security reasons; the alternative is Singularity (or Apptainer). Run the pipeline with `-profile singularity`. If you use `-profile snellius`, singularity is also enabled.

#### Retry failed jobs

Because SLURM jobs might occasionally fail, every task is retried once before the pipeline fails, and the steps with the `error_retry` label (e.g. MetaPhlAn, subsampling) twice. Most steps get more memory and time on each retry.

#### Use slurm

If you're using a scheduler on a computing cluster, you should define that in the process scope configuration file. The queue size and rate limit of job submissions are also defined. The configs below are used in the `-profile snellius` but with a specified partition name. Make sure you replace the partition name when using this profile on other computing clusters.

```groovy
process {
    executor       = 'slurm'
    clusterOptions = '-p partitionname'
}
executor {
    queueSize       = 50
    submitRateLimit = '10 sec'
}
```

#### Job names with special characters

On some HPCs, certain characters such as parentheses and colons are not allowed in the SLURM job names. The config below is used in the `-profile snellius`.

```groovy
executor {
    jobName = { "${task.name}".replaceAll('[():\\s]', '_') }
}
```

## Testing the pipeline

The pipeline has an [nf-test](https://www.nf-test.com/) test suite in `tests/`:

- `-profile test` runs the pipeline on reads simulated from a mock gut community in `assets/testdata` (FastQC, fastp, host read removal, run merging, subsampling, Kraken2 and Bracken). It checks that Bracken's species fractions match the known composition, and compares the checksums of the read count table and the Kraken2/Bracken reports, and the list of output files, with `tests/default.nf.test.snap`. See [assets/testdata/README.md](../assets/testdata/README.md).
- `-profile test -stub, all optional steps` checks that every step, including MetaPhlAn, HUMAnN, ShortBRED and `bracken-build`, is wired correctly (stub blocks only, no real computation and no database downloads).
- `-profile test -stub, no preprocessing` checks a mix of single- and paired-end samples with `--skip_preprocessing`.

```bash
nf-test test --profile +docker            # Linux, or CI
nf-test test --profile +docker,+arm       # Apple Silicon Mac
```

If a change is meant to alter results, update the snapshot with `--update-snapshot` and review the diff of `tests/default.nf.test.snap` before committing it.

Check syntax and types without running anything:

```bash
nextflow lint .
```

CI runs `nextflow lint`, then nf-test on the minimum supported Nextflow version and the latest stable release. See [CONTRIBUTING.md](../.github/CONTRIBUTING.md) for the conventions of the code.

## Running in the background

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).

## Nextflow memory requirements

In some cases, the Nextflow Java virtual machines can start to request a large amount of memory.
We recommend adding the following line to your environment to limit this (typically in `~/.bashrc` or `~./bash_profile`):

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```
