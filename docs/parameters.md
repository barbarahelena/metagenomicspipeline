# metagenomicspipeline: Parameters

| Group                   | Property                    | Type      | Description                                                  | Default Value | Required |
|-------------------------|-----------------------------|-----------|--------------------------------------------------------------|---------------|----------|
| Input options           | input                       | string    | Path to the input data.                                      | null          | *        |
|                         | adapterlist                 | string    | Path to the list of adapter sequences.                       | null          |          |
| References              | genome                      | string    | Path to the reference genome.                                 | null          |          |
|                         | igenomes_base               | string    | Base directory for iGenomes.                                  | 's3://ngi-igenomes/igenomes' |          |
|                         | igenomes_ignore             | boolean   | Ignore iGenomes.                                             | false         |          |
| Skip subworkflows        | skip_preprocessing          | boolean   | Skip preprocessing subworkflow.                              | false         |          |
|                         | skip_metaphlan              | boolean   | Skip MetaPhlAn subworkflow.                                  | false         |          |
|                         | skip_humann                 | boolean   | Skip HUMAnN subworkflow.                                     | false         |          |
|                         | skip_strainphlan            | boolean   | Skip StrainPhlAn subworkflow.                                | true          |          |
| Preprocessing           | subsamplelevel              | integer   | Subsample level for preprocessing.                           | 20000000      |          |
|                         | save_trimmed_fail           | boolean   | Save trimmed reads even if trimming fails.                   | false         |          |
|                         | skip_qualityfilter          | boolean   | Skip quality filtering.                                      | false         |          |
|                         | skip_humanfilter            | boolean   | Skip human filtering.                                        | false         |          |
|                         | skip_subsampling            | boolean   | Skip subsampling.                                            | false         |          |
|                         | fastp_quality_filters       | string    | Quality filters for Fastp.                                   | -f 5 -r -W 4 -M 15 -l 70 |          |
| StrainPhlAn             | sample_with_n_markers       | integer   | Number of samples with markers for StrainPhlAn.              | 80            |          |
|                         | marker_in_n_samples         | integer   | Number of markers in samples for StrainPhlAn.                | 80            |          |
|                         | phylophlan_mode             | string    | PhyloPhlAn mode.                                             | 'accurate'    |          |
|                         | mutation_rates              | boolean   | Enable mutation rates in StrainPhlAn.                        | true          |          |
| MultiQC options         | multiqc_config              | string    | Path to MultiQC config file.                                 | null          |          |
|                         | multiqc_title               | string    | MultiQC report title.                                        | null          |          |
|                         | multiqc_logo                | string    | Path to MultiQC logo file.                                   | null          |          |
|                         | max_multiqc_email_size      | string    | File size limit for MultiQC reports in summary emails.       | '25.MB'       |          |
|                         | multiqc_methods_description | string    | Path to MultiQC methods description file.                   | null          |          |
