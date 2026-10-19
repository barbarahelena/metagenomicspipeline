#!/usr/bin/env bash
#
# Make the test data in assets/testdata: a mock gut community with a known composition.
#
#   - 6 gut bacteria (300 kb of each reference genome) make up a tiny Kraken2/Bracken database
#   - Methanobrevibacter smithii is in the reads but not in the database: its reads stay unclassified
#   - ~5% human reads (genome.fasta) are removed by host read removal
#   - Illumina NovaSeq-like 2x150 bp reads are simulated with InSilicoSeq, with fixed seeds
#
# The expected composition of each sample is written to mock_composition.csv.
#
# Needs Docker and an internet connection (NCBI). Run from anywhere:
#     bash assets/testdata/make_testdata.sh
#
# Then update the nf-test snapshot: nf-test test --profile +docker --update-snapshot

set -euo pipefail

TESTDATA="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="${WORK:-$(mktemp -d)}"
THREADS=4
SLICE=300000        # bases taken from the largest sequence of each genome
READS_PER_RUN=20000 # reads per run (InSilicoSeq counts both mates: 10,000 pairs)

SEQKIT=quay.io/biocontainers/seqkit:2.9.0--h9ee0642_0
KRAKEN2=docker.io/barbarahelena/kraken2:2.1.6
BRACKEN=quay.io/biocontainers/bracken:3.1--h9948957_0
ISS=quay.io/biocontainers/insilicoseq:2.0.1--pyh7cba7a3_0

run() {   # run <image> <command...>, with $WORK mounted as the working directory
    local image=$1; shift
    docker run --rm --platform linux/amd64 -u "$(id -u):$(id -g)" -e HOME=/tmp \
        -v "$WORK":/work -w /work "$image" "$@"
}

echo "Working in $WORK"
mkdir -p "$WORK/genomes"

# name, NCBI species taxid, RefSeq complete genome, in database (1/0)
GENOMES="
Bacteroides_fragilis,817,GCF_000025985.1,1
Phocaeicola_vulgatus,821,GCF_000012825.1,1
Faecalibacterium_prausnitzii,853,GCF_058248305.1,1
Escherichia_coli,562,GCF_000005845.2,1
Bifidobacterium_longum,216816,GCF_000196555.1,1
Akkermansia_muciniphila,239935,GCF_009731575.1,1
Methanobrevibacter_smithii,2173,GCF_000016525.1,0
"

#
# 1. Genomes: download, keep the first $SLICE bases of the largest sequence, add the Kraken2 taxid
#
for line in $GENOMES; do
    IFS=, read -r name taxid acc _indb <<< "$line"
    if [ ! -s "$WORK/genomes/$name.fa" ]; then
        curl -sSL -o "$WORK/genomes/$acc.zip" \
            "https://api.ncbi.nlm.nih.gov/datasets/v2/genome/accession/$acc/download?include_annotation_type=GENOME_FASTA"
        unzip -q -o -j "$WORK/genomes/$acc.zip" '*.fna' -d "$WORK/genomes/$acc"
        run $SEQKIT sh -c "cat genomes/$acc/*.fna \
            | seqkit sort --by-length --reverse 2>/dev/null \
            | seqkit head -n 1 \
            | seqkit subseq -r 1:$SLICE \
            | seqkit replace -p '.+' -r '${name}|kraken:taxid|${taxid}' \
            | seqkit seq -w 80 > genomes/$name.fa"
    fi
done
cp "$TESTDATA/genome.fasta" "$WORK/genomes/Homo_sapiens.fa"

#
# 2. Kraken2 + Bracken database of the 6 bacteria. Only the NCBI taxonomy dump is needed:
#    the sequence names carry their taxid, so no accession-to-taxid tables.
#
if [ ! -s "$WORK/db/database150mers.kmer_distrib" ]; then
    echo "Building the Kraken2/Bracken database (log: $WORK/db_build.log)"
    mkdir -p "$WORK/db/taxonomy"
    curl -sSL https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz | tar -xz -C "$WORK/db/taxonomy" names.dmp nodes.dmp
    {
        for line in $GENOMES; do
            IFS=, read -r name _taxid _acc indb <<< "$line"
            if [ "$indb" = 1 ]; then
                run $KRAKEN2 kraken2-build --add-to-library "genomes/$name.fa" --db db --no-masking
            fi
        done
        run $KRAKEN2 kraken2-build --build --db db --threads $THREADS
        run $BRACKEN bracken-build -d db -t $THREADS -k 35 -l 150
    } > "$WORK/db_build.log" 2>&1
fi

rm -rf "$TESTDATA/kraken2_bracken"
mkdir -p "$TESTDATA/kraken2_bracken"
cp "$WORK"/db/{hash.k2d,opts.k2d,taxo.k2d,database150mers.kmer_distrib} "$TESTDATA/kraken2_bracken/"

#
# 3. Reads. Abundance = fraction of the reads of a run that come from that genome.
#    Sample GUT1 was sequenced twice (two runs, same community) to test run merging.
#
#    (Plain strings and no bash 4 features: macOS ships bash 3.2.)
#
#              B.frag P.vulg F.prau E.coli B.long A.muci M.smit human
ABUNDANCE_GUT1="0.35   0.20   0.15   0.10   0.05   0.05   0.05   0.05"
ABUNDANCE_GUT2="0.05   0.10   0.30   0.05   0.15   0.20   0.10   0.05"
ABUNDANCE_GUT3="0.10   0.05   0.05   0.40   0.25   0.05   0.05   0.05"
NAMES="Bacteroides_fragilis Phocaeicola_vulgatus Faecalibacterium_prausnitzii Escherichia_coli Bifidobacterium_longum Akkermansia_muciniphila Methanobrevibacter_smithii Homo_sapiens"
TAXIDS="817 821 853 562 216816 239935 2173 9606"
IN_DB="yes yes yes yes yes yes no no"

cat "$WORK"/genomes/{Bacteroides_fragilis,Phocaeicola_vulgatus,Faecalibacterium_prausnitzii,Escherichia_coli,Bifidobacterium_longum,Akkermansia_muciniphila,Methanobrevibacter_smithii,Homo_sapiens}.fa \
    > "$WORK/community.fa"
# InSilicoSeq names abundances by the first word of each sequence name
run $SEQKIT seqkit seq --name --only-id community.fa > "$WORK/record_ids.txt"

simulate() {   # simulate <sample> <run> <seed> <abundances, in the order of community.fa>
    local sample=$1 run_id=$2 seed=$3 abundances=$4
    paste "$WORK/record_ids.txt" <(printf '%s\n' $abundances) > "$WORK/abundance_$sample.txt"
    run $ISS iss generate \
        --genomes community.fa \
        --abundance_file "abundance_$sample.txt" \
        --model novaseq \
        --n_reads $READS_PER_RUN \
        --seed "$seed" \
        --cpus 1 \
        --output "reads_${sample}_${run_id}" > "$WORK/iss_${sample}_${run_id}.log" 2>&1
    # Recompress without a timestamp in the gzip header, so the files are identical on every run
    for mate in 1 2; do
        gzip -n -9 -c "$WORK/reads_${sample}_${run_id}_R${mate}.fastq" > "$TESTDATA/reads/${sample}_${run_id}_${mate}.fastq.gz"
    done
}

rm -rf "$TESTDATA/reads"
mkdir -p "$TESTDATA/reads"
echo "Simulating reads"
simulate GUT1 RUN1 101 "$ABUNDANCE_GUT1"
simulate GUT1 RUN2 102 "$ABUNDANCE_GUT1"
simulate GUT2 RUN1 201 "$ABUNDANCE_GUT2"
simulate GUT3 RUN1 301 "$ABUNDANCE_GUT3"

#
# 4. Samplesheets and the known composition
#
cat > "$TESTDATA/samplesheet_test.csv" <<EOF
sample,run_accession,fastq_1,fastq_2
GUT1,RUN1,reads/GUT1_RUN1_1.fastq.gz,reads/GUT1_RUN1_2.fastq.gz
GUT1,RUN2,reads/GUT1_RUN2_1.fastq.gz,reads/GUT1_RUN2_2.fastq.gz
GUT2,RUN1,reads/GUT2_RUN1_1.fastq.gz,reads/GUT2_RUN1_2.fastq.gz
GUT3,RUN1,reads/GUT3_RUN1_1.fastq.gz,reads/GUT3_RUN1_2.fastq.gz
EOF

cat > "$TESTDATA/samplesheet_test_single.csv" <<EOF
sample,fastq_1,fastq_2
GUT2_paired,reads/GUT2_RUN1_1.fastq.gz,reads/GUT2_RUN1_2.fastq.gz
GUT3_single,reads/GUT3_RUN1_1.fastq.gz,
EOF

# One column per field list, then transposed into rows: organism,taxid,in_kraken2_db,GUT1,GUT2,GUT3
{
    echo "organism,taxid,in_kraken2_db,GUT1,GUT2,GUT3"
    paste -d, <(printf '%s\n' $NAMES) <(printf '%s\n' $TAXIDS) <(printf '%s\n' $IN_DB) \
        <(printf '%s\n' $ABUNDANCE_GUT1) <(printf '%s\n' $ABUNDANCE_GUT2) <(printf '%s\n' $ABUNDANCE_GUT3)
} > "$TESTDATA/mock_composition.csv"

echo "Done. Test data written to $TESTDATA"
