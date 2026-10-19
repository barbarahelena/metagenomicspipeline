# metagenomicspipeline: Parameters

All pipeline parameters, generated from [`nextflow_schema.json`](../nextflow_schema.json). Run `nextflow run barbarahelena/metagenomicspipeline --help` for the same list, or `--help <parameter>` for the details of one parameter. Hidden parameters (rarely needed) are marked *(hidden)*; `--help --show_hidden` lists them too.

## Input/output options

Define where the pipeline should find input data and save output data.

| Parameter | Description | Type | Default |
| --- | --- | --- | --- |
| `--input` | Path to comma-separated file containing information about the samples in the experiment. **required** | string |  |
| `--outdir` | The output directory where the results will be saved. You have to use absolute paths to storage on Cloud infrastructure. **required** | string |  |
| `--email` | Email address for completion summary. | string |  |
| `--multiqc_title` | MultiQC report title. Printed as page header, used for filename if not otherwise specified. | string |  |

## Reference genome options

Reference genome for removing host reads: give --fasta, --bowtie2_index or --genome.

| Parameter | Description | Type | Default |
| --- | --- | --- | --- |
| `--genome` | Name of iGenomes reference. | string |  |
| `--fasta` | Path to the host reference genome FASTA, used to build a Bowtie2 index for removing host reads. | string |  |
| `--bowtie2_index` | Path to a directory with a prebuilt Bowtie2 index (*.bt2) of the host genome. Takes precedence over --fasta. | string |  |
| `--igenomes_base` | The base path to the igenomes reference files *(hidden)* | string | `s3://ngi-igenomes/igenomes` |
| `--igenomes_ignore` | Do not load the iGenomes reference config. *(hidden)* | boolean | `false` |

## Skip options

| Parameter | Description | Type | Default |
| --- | --- | --- | --- |
| `--skip_preprocessing` | Skip all preprocessing (quality filtering, host read removal, run merging, subsampling); FastQC still runs. | boolean | `false` |
| `--skip_qualityfilter` | Skip quality filtering and adapter trimming with fastp. | boolean | `false` |
| `--skip_hostfilter` | Skip host read removal with Bowtie2. | boolean | `false` |
| `--skip_subsampling` | Skip subsampling of the reads to --subsamplelevel. | boolean | `false` |
| `--skip_metaphlan` | Skip taxonomic profiling with MetaPhlAn. | boolean | `false` |
| `--skip_humann` | Skip functional profiling with HUMAnN. | boolean | `false` |
| `--skip_kraken` | Skip taxonomic classification with Kraken2 and Bracken (skipped by default; use --skip_kraken false to run it). | boolean | `true` |
| `--skip_shortbred` | Skip ShortBRED quantification of antibiotic resistance genes (CARD markers; skipped by default). | boolean | `true` |

## Preprocessing of reads

| Parameter | Description | Type | Default |
| --- | --- | --- | --- |
| `--adapterlist` | FASTA file with adapter sequences for fastp. Without it, fastp detects adapters itself. | string |  |
| `--save_trimmed_fail` | Keep the reads that fail fastp filtering (in the fastp task folder). | boolean | `false` |
| `--fastp_cutright` | Trim reads from the 3' end with a sliding window (fastp --cut_right). | boolean | `true` |
| `--fastp_windowsize` | Sliding window size for --fastp_cutright (fastp --cut_window_size). | integer | `4` |
| `--fastp_meanquality` | Mean quality the sliding window must reach (fastp --cut_mean_quality). | integer | `15` |
| `--fastp_length` | Minimum read length after trimming; shorter reads are discarded (fastp --length_required). | integer | `70` |
| `--perform_runmerging` | Merge the runs of a sample (samplesheet rows with the same sample name) after host read removal. | boolean | `false` |
| `--subsamplelevel` | Number of reads (pairs) to subsample each sample to. Samples with fewer reads are kept as they are. | integer | `20000000` |
| `--publish_mergedreads` | How host-filtered and merged reads are saved to the output directory. They are large, so they are symlinked to the work directory by default. | string (`symlink`, `rellink`, `link`, `copy`, `copyNoFollow`, `move`) | `symlink` |

## Profiling options

| Parameter | Description | Type | Default |
| --- | --- | --- | --- |
| `--humann_db` | UniRef protein database for HUMAnN: uniref90_ec_filtered_diamond, uniref90_diamond, uniref50_diamond or uniref50_ec_filtered_diamond. | string (`uniref90_diamond`, `uniref90_ec_filtered_diamond`, `uniref50_diamond`, `uniref50_ec_filtered_diamond`) | `uniref90_ec_filtered_diamond` |
| `--kraken2_db` | Path to a Kraken2 database folder. When not given, the prebuilt database --kraken2_dbname is downloaded. | string |  |
| `--kraken2_dbname` | Prebuilt Kraken2 database to download when --kraken2_db is not given. | string (`core_nt`, `standard_64gb`, `standard_16gb`, `standard_8gb`) | `standard_16gb` |
| `--kraken2_save_reads` | Save the classified and unclassified reads from Kraken2. | boolean | `false` |
| `--kraken2_save_readclassifications` | Save the Kraken2 classification of every read. | boolean | `false` |
| `--bracken_build` | Build the Bracken files for --bracken_readlength (bracken-build), e.g. for a custom Kraken2 database. The prebuilt databases include them for common read lengths. | boolean | `false` |
| `--bracken_readlength` | Read length for Bracken; the database needs a matching database<length>mers.kmer_distrib file. | integer | `150` |
| `--bracken_kmerlength` | k-mer length for bracken-build (--bracken_build). | integer | `35` |
| `--bracken_threshold` | Minimum number of reads a taxon needs before Bracken re-estimates its abundance. | integer | `10` |

## Generic options

Less common options for the pipeline, typically set in a config file.

| Parameter | Description | Type | Default |
| --- | --- | --- | --- |
| `--help` | Display help text. *(hidden)* | boolean or string |  |
| `--version` | Display version and exit. *(hidden)* | boolean | `false` |
| `--publish_dir_mode` | Method used to save pipeline results to output directory. *(hidden)* | string (`symlink`, `rellink`, `link`, `copy`, `copyNoFollow`, `move`) | `copy` |
| `--email_on_fail` | Email address for completion summary, only when pipeline fails. *(hidden)* | string |  |
| `--plaintext_email` | Send plain-text email instead of HTML. *(hidden)* | boolean | `false` |
| `--max_multiqc_email_size` | File size limit when attaching MultiQC reports to summary emails. *(hidden)* | string | `25.MB` |
| `--monochrome_logs` | Do not use coloured log outputs. *(hidden)* | boolean | `false` |
| `--trace_report_suffix` | Suffix to add to the trace report filename. Default is the date and time in the format yyyy-MM-dd_HH-mm-ss. *(hidden)* | string |  |
| `--multiqc_config` | Custom config file to supply to MultiQC. *(hidden)* | string |  |
| `--multiqc_logo` | Custom logo file to supply to MultiQC. File name must also be set in the MultiQC config file *(hidden)* | string |  |
| `--multiqc_methods_description` | Custom MultiQC yaml file containing HTML including a methods description. | string |  |
| `--validate_params` | Boolean whether to validate parameters against the schema at runtime *(hidden)* | boolean | `true` |
| `--help_full` | Display the full detailed help message. *(hidden)* | boolean | `false` |
| `--show_hidden` | Display hidden parameters in the help message (only works when --help or --help_full are provided). *(hidden)* | boolean | `false` |

## Institutional config options

Parameters used to describe centralised config profiles. These should not be edited.

| Parameter | Description | Type | Default |
| --- | --- | --- | --- |
| `--custom_config_version` | Git commit id for Institutional configs. *(hidden)* | string | `master` |
| `--custom_config_base` | Base directory for Institutional configs. *(hidden)* | string | `https://raw.githubusercontent.com/nf-core/configs/master` |
| `--config_profile_name` | Institutional config name. *(hidden)* | string |  |
| `--config_profile_description` | Institutional config description. *(hidden)* | string |  |
| `--config_profile_contact` | Institutional config contact information. *(hidden)* | string |  |
| `--config_profile_url` | Institutional config URL link. *(hidden)* | string |  |
