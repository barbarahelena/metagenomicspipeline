#!/usr/bin/env python

"""Provide a command line tool to validate and transform tabular samplesheets."""

import argparse
import csv
import logging
import sys
from collections import Counter
from pathlib import Path

logger = logging.getLogger()

class RowChecker:
    """
    Define a service that can validate and transform each given row.

    Attributes:
        modified (list): A list of dicts, where each dict corresponds to a previously
            validated and transformed row. The order of rows is maintained.
    """

    VALID_FORMATS = (
        ".fq.gz",
        ".fastq.gz",
    )

    def __init__(self):
        self.modified = []

    def validate_and_transform(self, row):
        """
        Validate and transform a given row.

        Args:
            row (dict): A dict representing a row from the samplesheet.

        Raises:
            AssertionError: If the row is invalid.
        """
        # Validate 'sample' and 'fastq_1'
        assert "sample" in row, "Missing 'sample' column."
        assert "fastq_1" in row, "Missing 'fastq_1' column."
        assert any(row["fastq_1"].endswith(ext) for ext in self.VALID_FORMATS), "Invalid 'fastq_1' format."

        # Validate 'fastq_2' if present
        if "fastq_2" in row and row["fastq_2"]:
            assert any(row["fastq_2"].endswith(ext) for ext in self.VALID_FORMATS), "Invalid 'fastq_2' format."

        # Transform the row as needed (e.g., add 'single_end' column)
        row["single_end"] = "fastq_2" not in row or not row["fastq_2"]
        self.modified.append(row)

    def validate_unique_samples(self, mergeruns):
        """
        Validate that each sample is unique.

        Args:
            mergeruns (bool): Whether to merge runs for the same sample.

        Raises:
            AssertionError: If samples are not unique and mergeruns is False.
        """
        sample_counts = Counter(row["sample"] for row in self.modified)
        duplicates = [sample for sample, count in sample_counts.items() if count > 1]
        if duplicates and not mergeruns:
            raise AssertionError(f"Duplicate samples found: {', '.join(duplicates)}")

def sniff_format(handle):
    """
    Sniff the format of the CSV file.

    Args:
        handle: A file handle.

    Returns:
        A csv.Dialect object.
    """
    sample = handle.read(1024)
    handle.seek(0)
    return csv.Sniffer().sniff(sample)

def main(file_in, file_out, mergeruns):
    """
    Main function to validate and transform the samplesheet.

    Args:
        file_in (Path): Input file path.
        file_out (Path): Output file path.
        mergeruns (bool): Whether to merge runs for the same sample.
    """
    required_columns = {"sample", "fastq_1"}
    optional_columns = {"fastq_2"}

    # See https://docs.python.org/3.9/library/csv.html#id3 to read up on `newline=""`.
    with file_in.open(newline="") as in_handle:
        reader = csv.DictReader(in_handle, dialect=sniff_format(in_handle))
        # Validate the existence of the expected header columns.
        if not required_columns.issubset(reader.fieldnames):
            req_cols = ", ".join(required_columns)
            logger.critical(f"The sample sheet **must** contain these column headers: {req_cols}.")
            sys.exit(1)
        
        # Check if the optional column 'fastq_2' is present
        has_fastq_2 = optional_columns.issubset(reader.fieldnames)

        # Validate each row.
        checker = RowChecker()
        for i, row in enumerate(reader):
            try:
                checker.validate_and_transform(row)
            except AssertionError as error:
                logger.critical(f"{str(error)} On line {i + 2}.")
                sys.exit(1)
        checker.validate_unique_samples(mergeruns)
    
    header = list(reader.fieldnames)
    if "fastq_2" not in header:
        header.append("fastq_2")
    header.insert(1, "single_end")

    # See https://docs.python.org/3.9/library/csv.html#id3 to read up on `newline=""`.
    with file_out.open(mode="w", newline="") as out_handle:
        writer = csv.DictWriter(out_handle, header, delimiter=",")
        writer.writeheader()
        for row in checker.modified:
            writer.writerow(row)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Validate and transform tabular samplesheets.")
    parser.add_argument("file_in", type=Path, help="Input samplesheet file.")
    parser.add_argument("file_out", type=Path, help="Output samplesheet file.")
    parser.add_argument("--mergeruns", action="store_true", help="Merge runs for the same sample.")
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO)
    main(args.file_in, args.file_out, args.mergeruns)