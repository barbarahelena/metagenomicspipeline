# metagenomicspipeline: Output

## Introduction

This document describes the output produced by the pipeline. The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/) and processes data using the following steps:

- [Inputcheck](#inputcheck) - Tidy samplesheet
- [FastQC](#fastqc) - Raw read QC
- [Fastp](#fastp) - Quality filter and adapter trimming reads
- [Bowtie2](#bowtie2)
- [Subsampling](#subsampling)
- [MetaPhlAn](#metaphlan) - tax profiling
- [HUMAnN](#humann) - gene and pathway abundance table
- [StrainPhlAn](#strainphlan) - species-level genome bins (SGBs)
- [MultiQC](#multiqc) - Aggregate report describing results and QC from the whole pipeline
- [Pipeline information](#pipeline-information) - Report metrics generated during the workflow execution

### FastQC

<details markdown="1">
<summary>Output files</summary>

- `fastqc/`
  - `*_fastqc.html`: FastQC report containing quality metrics.
  - `*_fastqc.zip`: Zip archive containing the FastQC report, tab-delimited data file and plot images.

</details>

[FastQC](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/) gives general quality metrics about your sequenced reads. It provides information about the quality score distribution across your reads, per base sequence content (%A/T/G/C), adapter contamination and overrepresented sequences. For further reading and documentation see the [FastQC help pages](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/Help/).

![MultiQC - FastQC sequence counts plot](images/mqc_fastqc_counts.png)

![MultiQC - FastQC mean quality scores plot](images/mqc_fastqc_quality.png)

![MultiQC - FastQC adapter content plot](images/mqc_fastqc_adapter.png)

:::note
The FastQC plots displayed in the MultiQC report shows _untrimmed_ reads. They may contain adapter sequence and potentially regions with low quality.
:::

### Fastp

<details markdown="1">
<summary>Output files</summary>

- `fastp/`
  - `*.unmapped_1.fastq.gz`: unaligned forward reads
  - `*.unmapped_2.fastq.gz`: unaligned reverse reads
  - `*.fastp.html`: html with qc data
  - `*.fastp.json`: json of metadata
  - `*.fastp.log`: log of fastp process

</details>

[Fastp]() is a fast and efficient tool designed for preprocessing next-generation sequencing data. It performs quality filtering, adapter trimming, and other data cleaning tasks. Fastp is particularly useful for improving the quality of raw reads, ensuring that only high-quality data is used for subsequent analyses.

### Bowtie2

<details markdown="1">
<summary>Output files</summary>

- `bowtie2/`
  - `bowtie2/`: folder with the indexed reference genome
  - `*.unmapped_1.fastq.gz`: unaligned forward reads
  - `*.unmapped_2.fastq.gz`: unaligned reverse reads
  - `*.bowtie2.log`: log of bowtie2 alignment
  - `*.stats`: samtools stats report

</details>

[Bowtie2](https://bowtie-bio.sourceforge.net/bowtie2/index.shtml) is employed to align reads with the human reference genome, filtering out human reads from the fastq files. [Samtools](http://www.htslib.org/) is used to generate index files and obtain statistics.

### Subsampling

<details markdown="1">
<summary>Output files</summary>

- `subsampling/`
  - `*_subsampled_1.fastq.gz`: subsampled forward reads
  - `*_subsampled_2.fastq.gz`: subsampled reverse reads
  - `*_readcount.txt`: number of reads before subsampling (forward reads)

</details>

[Seqkit](https://bioinf.shenwei.me/seqkit/) is used for subsampling reads that have more reads than the subsampling level. Reads lower than the subsampling level are simply copied without subsampling.

### MetaPhlAn

<details markdown="1">
<summary>Output files</summary>

- `metaphlan/`
  - `*_profile.txt`: tax profile per sample
  - `*.biom`: biom file per sample
  - `*.sam.bz2`: compressed sam file 
  - `*.concat.fastq.gz`: concatenated forward and reverse reads
  - `combined_table.txt`: merged metaphlan tax profile table

</details>

[MetaPhlAn](https://github.com/biobakery/MetaPhlAn) is a metagenomics tool that characterizes microbial communities by profiling the taxonomic composition of samples. It identifies microorganisms based on marker genes, providing insights into the abundance of different taxa. The output includes tax profiles and biom files for each sample. These are then merged into a combined table.

### HUMAnN

<details markdown="1">
<summary>Output files</summary>

- `humann/`
  - `humann_results/`: output of HUMAnN per sample
    - `*_genefamilies.tsv`: gene family abundance in reads per kilobase (RPK)
    - `*_pathabundance.tsv`: pathway abundance
    - `*_pathcoverage.tsv`: pathway coverage (presence / absence)
  - `logs/`: logs of HUMAnN per sample
  - `gene_families.txt`: gene families abundance (merged)
  - `gene_families_cpm.txt`: gene families abundance (merged) in counts per million
  - `gene_families_cpm_stratified.txt`: pathway abundance (merged) in cpm and stratified
  - `pathway_abundance.txt`: pathway abundance (merged)
  - `pathway_abundance_cpm.txt`: pathway abundance (merged) in counts per million
  - `pathway_abundance_cpm_stratified.txt`: pathway abundance (merged) in cpm and stratified

</details>

[HUMAnN](https://github.com/biobakery/humann) is a tool for characterizing the functional potential of microbial communities. It quantifies gene and pathway abundance, allowing researchers to understand the metabolic capabilities of the microbiome. The output includes various files summarizing gene families and pathway abundance.

### StrainPhlAn

<details markdown="1">
<summary>Output files</summary>

- `strainphlan/`

</details>

[StrainPhlAn](https://github.com/biobakery/MetaPhlAn/wiki/StrainPhlAn-4) focuses on obtaining strain-level information from metagenomic data. It identifies species-level genome bins (SGBs), providing a more detailed view of microbial community composition.

### MultiQC

<details markdown="1">
<summary>Output files</summary>

- `multiqc/`
  - `multiqc_report.html`: a standalone HTML file that can be viewed in your web browser.
  - `multiqc_data/`: directory containing parsed statistics from the different tools used in the pipeline.
  - `multiqc_plots/`: directory containing static images from the report in various formats.

</details>

[MultiQC](http://multiqc.info) is a visualization tool that generates a single HTML report summarising all samples in your project. Most of the pipeline QC results are visualised in the report and further statistics are available in the report data directory.

Results generated by MultiQC collate pipeline QC from supported tools e.g. FastQC. The pipeline has special steps which also allow the software versions to be reported in the MultiQC output for future traceability. For more information about how to use MultiQC reports, see <http://multiqc.info>.

### Pipeline information

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - Reports generated by Nextflow: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt` and `pipeline_dag.dot`/`pipeline_dag.svg`.
  - Reports generated by the pipeline: `pipeline_report.html`, `pipeline_report.txt` and `software_versions.yml`. The `pipeline_report*` files will only be present if the `--email` / `--email_on_fail` parameter's are used when running the pipeline.
  - Reformatted samplesheet files used as input to the pipeline: `samplesheet.valid.csv`.
  - Parameters used by the pipeline run: `params.json`.

</details>

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.