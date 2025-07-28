# metagenomicspipeline: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v.1.0.0 - [28/7/2025]

Major update to the workflow: now works with single-end and paired-end reads, integrated Kraken2 and updated MetaPhlAn and HUMAnN versions. The nf-core modules for `FastQC` and `MultiQC` were updated.

### `Added`
- Single-end reads input: Pipeline now automatically detects and processes both single-end and paired-end FASTQ files
- Kraken2: Taxonomic classification with different database options
- Bracken: Species-level abundance estimation from Kraken2 output
- Skip parameters: Added `--skip_kraken2`, `--skip_metaphlan`, `--skip_humann` options for flexible workflow execution
- Added process to merge all read counts in one table (after removal of host reads)
- Added `-profile test` and `-profile test_full` with test setup for HUMAnN database download, so that the size of the test db is a lot smaller.
- Ensured that `-profile conda` works, although container use (Apptainer/Singularity or Docker) is still recommended
- Conditional tool citations: Citations in MultiQC reports now reflect only the tools actually used in the run

### `Dependencies`
- Fastp: Updated to version 1.0.1
- Seqkit: Updated to version 2.9.0
- MetaPhlAn: Updated to version 4.2.2
- HUMAnN: Updated to version 4.0.0-alpha (no biocontainer available, pulls from Dockerhub)
- Kraken2: Added version 2.1.6 (no biocontainer available, pulls from Dockerhub)
- Bracken: Added version 3.1
- Fastqc: Updated to version 0.12.1
- Multiqc: Updated to version 1.30

### `Deprecated`
- The pipeline no longer merges gene family output of HUMAnN. With too many samples, this would result in out-of-memory crashes.
- StrainPhlAn was removed from this pipeline, I made a [separate workflow](https://github.com/barbarahelena/strainflow) for StrainPhlAn.

## v.0.5.0-beta - [15/2/2024]

Initial release of metagenomicspipeline, following the [nf-core](https://nf-co.re/) template as much as possible.
