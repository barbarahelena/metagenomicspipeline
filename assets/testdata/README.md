# Test data: mock gut community

Used by `-profile test` and the nf-test suite (`tests/default.nf.test`). Everything here is made by
[`make_testdata.sh`](make_testdata.sh) (Docker and internet needed; fixed seeds).

| File | What |
| --- | --- |
| `reads/*.fastq.gz` | 10,000 simulated read pairs per run (InSilicoSeq, NovaSeq error model, 2x151 bp) |
| `samplesheet_test.csv` | Samples GUT1 (two runs, to test `--perform_runmerging`), GUT2 and GUT3 |
| `samplesheet_test_single.csv` | One paired-end and one single-end sample, without `run_accession` |
| `mock_composition.csv` | The fraction of reads from each organism in each sample: the truth the test checks against |
| `kraken2_bracken/` | Kraken2 + Bracken (150 bp) database of the six bacteria |
| `genome.fasta` | Small human reference (nf-core/test-datasets `homo_sapiens/genome/genome.fasta`), for host read removal |

## The community

| Organism | In Kraken2 DB | GUT1 | GUT2 | GUT3 |
| --- | --- | --- | --- | --- |
| *Bacteroides fragilis* | yes | 0.35 | 0.05 | 0.10 |
| *Phocaeicola vulgatus* | yes | 0.20 | 0.10 | 0.05 |
| *Faecalibacterium prausnitzii* | yes | 0.15 | 0.30 | 0.05 |
| *Escherichia coli* | yes | 0.10 | 0.05 | 0.40 |
| *Bifidobacterium longum* | yes | 0.05 | 0.15 | 0.25 |
| *Akkermansia muciniphila* | yes | 0.05 | 0.20 | 0.05 |
| *Methanobrevibacter smithii* | no: stays unclassified | 0.05 | 0.10 | 0.05 |
| Human (host) | no: removed by Bowtie2 | 0.05 | 0.05 | 0.05 |

To keep the database small (3 MB), the reads and the database use only the first 300 kb of each
reference genome (RefSeq complete genomes, accessions in `make_testdata.sh`). The read names start
with the organism they were simulated from.

The nf-test `-profile test` checks that Bracken's species fractions are within 0.05 of this
composition (renormalised to the six species in the database), besides the checksums in the snapshot.

## Changing the data

Edit the abundances or genomes in `make_testdata.sh`, run it, and update the expected results:

```bash
bash assets/testdata/make_testdata.sh
nf-test test --profile +docker --update-snapshot   # add ,+arm on an Apple Silicon Mac
```

Review the diff of `tests/default.nf.test.snap` before committing it.
