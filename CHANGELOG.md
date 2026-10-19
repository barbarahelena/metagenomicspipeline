# metagenomicspipeline: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v2.0.0dev - [unreleased]

The pipeline now uses Nextflow's static types (typed processes, workflows and parameters) and needs Nextflow 26.10.0 or later.

### `Added`
- Credits for the reused nf-core components in `README.md`, and their MIT copyright notices in `LICENSE`
- Typed parameters in `main.nf`: a wrong type, a missing file or a misspelled parameter stops the run before it starts
- Samples are passed between steps as typed records (`subworkflows/local/types.nf`) instead of meta maps
- Software versions are collected from the `versions` topic channel, into `pipeline_info/software_versions.tsv` and the MultiQC report
- Results are published with workflow outputs (output block in `main.nf`) instead of `publishDir`
- nf-test pipeline tests (`tests/`), with a simulated mock gut community of known composition and a matching Kraken2/Bracken database in `assets/testdata` (`make_testdata.sh`)
- CI: `nextflow lint` and nf-test on the minimum and latest Nextflow version
- Documentation rewritten for this version: usage, output and parameters (generated from `nextflow_schema.json`, which now describes every parameter)
- `run_accession` column in the samplesheet schema; FastQC, fastp and Bowtie2 file names include it

### `Changed`
- nf-validation replaced by nf-schema 3.0.0; samplesheet validation by `assets/schema_input.json` instead of `bin/check_samplesheet.py`
- `--max_cpus`, `--max_memory` and `--max_time` replaced by `process.resourceLimits` (set in a profile or your own config)
- nf-core FastQC (0.13.0) and MultiQC (1.35) modules updated
- Without `--perform_runmerging`, a sample name may appear only once in the samplesheet
- Relative samplesheet paths that do not exist relative to the launch folder are looked up relative to the samplesheet

### `Fixed`
- `CITATIONS.md`: the Kraken2 entry cited the MetaPhlAn 4 paper; added fastp, Bowtie2, SAMtools, SeqKit (2), Bracken and ShortBRED; completed the MetaPhlAn 4 reference; removed a Docker DOI that does not resolve
- MultiQC methods description: lists the tools that ran with their references again (lost when `lib/` was removed), and acknowledges nf-core
- Pipeline DOI: the Zenodo concept DOI (all versions) instead of the DOI of release v0.5.0-beta
- Host read removal: Bowtie2 now writes reads in input order (`--reorder`). Before, with several threads, the order changed between runs, so subsampling picked different reads and profiles differed between identical runs
- `--bracken_build` wrote into the Kraken2 database folder and its output was never found; it now builds into a new folder
- `--skip_shortbred false` failed (undefined input channel)
- Single-end samples: shell checks of `single_end` compared against `True`, which never matched
- HUMAnN reported version 3.9 instead of the version in the container; test databases were linked to a folder HUMAnN did not read
- Version commands for Bowtie2 and Kraken2 that printed nothing

### `Removed`
- `--hook_url` (Slack/Teams notifications), `--kraken2_save_minimizers` (unused), nf-validation options
- `lib/` Groovy classes, `CUSTOM_DUMPSOFTWAREVERSIONS`, `SAMPLESHEETCHECK`, nf-core template GitHub workflows (AWS tests, nf-core lint)
- nf-core template files: issue template links, `CODE_OF_CONDUCT.md`, Dockstore, Gitpod and devcontainer configs, `pyproject.toml`

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
