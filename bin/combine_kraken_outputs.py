#!/usr/bin/env python

"""Provide a command line tool to merge Kraken2-style Bracken output tables with all tax levels."""

import pandas as pd
import argparse

def merge_kraken_bracken_reports(file_paths, output_file):
    """
    Merge multiple Kraken2-style Bracken reports into a single DataFrame.
    Each file contributes an abundance column while preserving the taxonomic hierarchy.
    
    :param file_paths: List of paths to Kraken2-style Bracken reports
    :param output_file: Path to save the merged output
    """
    dataframes = []
    
    for file_path in file_paths:
        sample_name = file_path.split('/')[-1].replace('.txt', '')  # Extract sample name from filename
        df = pd.read_csv(file_path, sep='\t', header=None, 
                         names=["abundance", "reads", "kraken_taxid", "rank", "ncbi_taxid", "name"], 
                         dtype={"ncbi_taxid": str})
        df = df[["ncbi_taxid", "name", "rank", "abundance"]]  # Keep relevant columns
        df.rename(columns={"abundance": sample_name}, inplace=True)
        dataframes.append(df)
    
    # Merge on ncbi_taxid, name, and rank to preserve structure
    merged_df = dataframes[0]
    for df in dataframes[1:]:
        merged_df = merged_df.merge(df, on=["ncbi_taxid", "name", "rank"], how='outer')
    
    # Fill missing values with 0 (if some taxa are missing in certain samples)
    merged_df.fillna(0, inplace=True)
    
    # Save to output file
    merged_df.to_csv(output_file, sep="\t", index=False)

def main():
    parser = argparse.ArgumentParser(description="Merge Kraken2-style Bracken reports into one table.")
    parser.add_argument("files", nargs='+', help="List of input Bracken report files.")
    parser.add_argument("-o", "--output", required=True, help="Output file path for merged report.")
    args = parser.parse_args()
    
    merge_kraken_bracken_reports(args.files, args.output)

if __name__ == "__main__":
    main()
