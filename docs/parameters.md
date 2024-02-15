| Category                   | Parameter                | Description                                                                                   | Default Value   |
|----------------------------|--------------------------|-----------------------------------------------------------------------------------------------|-----------------|
| Input/output options       | input                    | Path to input data file.                                                                      | -               |
|                            | outdir                   | Path to the directory where the results will be saved.                                         | -               |
|                            | email                    | Email address for receiving completion notification.                                           | -               |
|                            | multiqc_title            | Title for the MultiQC report.                                                                  | -               |
| Reference genome options  | igenomes_ignore          | Flag to ignore iGenomes reference configuration.                                               | -               |
|                            | fasta                    | Path to the reference genome FASTA file.                                                       | -               |
|                            | adapterlist              | Path to the adapter list file.                                                                 | -               |
| Skip options               | skip_preprocessing       | Skip preprocessing step.                                                                      | -               |
|                            | skip_qualityfilter       | Skip quality filtering step.                                                                   | -               |
|                            | skip_humanfilter         | Skip human filtering step.                                                                     | -               |
|                            | skip_subsampling         | Skip subsampling step.                                                                         | -               |
|                            | skip_metaphlan           | Skip MetaPhlAn analysis.                                                                       | -               |
|                            | skip_humann              | Skip HUMAnN analysis.                                                                          | -               |
|                            | skip_strainphlan         | Skip StrainPhlAn analysis.                                                                     | true            |
| Preprocessing of reads     | save_trimmed_fail        | Save trimmed reads that fail filtering.                                                        | -               |
|                            | fastp_cutright           | Perform trimming from the right end.                                                           | true            |
|                            | fastp_windowsize         | Window size for quality filtering in Fastp.                                                    | 4               |
|                            | fastp_meanquality       | Mean quality threshold for filtering in Fastp.                                                  | 15              |
|                            | fastp_length             | Minimum length threshold for reads in Fastp.                                                   | 70              |
|                            | subsamplelevel           | Level of subsampling for reads.                                                                | 20000000        |
| HUMAnN                     | database                 | Database to use for HUMAnN analysis.                                                           | -               |
| StrainPhlAn                | phylophlan_mode          | PhyloPhlAn mode for analysis.                                                                  | accurate        |
|                            | sample_with_n_markers    | Minimum number of markers in a sample for StrainPhlAn.                                          | 80              |
|                            | marker_in_n_samples      | Minimum number of samples containing a marker for StrainPhlAn.                                  | 80              |
|                            | mutation_rates           | Include mutation rates in StrainPhlAn analysis.                                                 | true            |
