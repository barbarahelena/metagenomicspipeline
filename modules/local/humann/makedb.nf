nextflow.enable.types = true

process HUMANN_MAKEDB {
    label 'process_medium'
    label 'humann'
    storeDir 'db'
    conda "${moduleDir}/environment.yml"

    input:
    database: String    // UniRef database, e.g. 'uniref90_ec_filtered_diamond'

    output:
    file('humann_db')

    script:
    def metaphlanversion = 'mpa_vOct22_CHOCOPhlAnSGB_202403'
    if (task.ext.test) {   // the small demo databases that ship with HUMAnN, for test_full
        """
        mkdir -p humann_db
        mkdir humann_db/metaphlan_db

        metaphlan \\
           --install \\
           --index ${metaphlanversion} \\
           --bowtie2db humann_db/metaphlan_db

        # Link the demo databases that ship with HUMAnN
        python -c "
import humann
import os
humann_path = os.path.join(os.path.dirname(humann.__file__), 'data')
demo_nucleotide_db = os.path.join(humann_path, 'chocophlan_DEMO')
demo_protein_db = os.path.join(humann_path, 'uniref_DEMO')

if os.path.exists(demo_nucleotide_db) and os.path.exists(demo_protein_db):
    os.symlink(demo_nucleotide_db, 'humann_db/chocophlan')
    os.symlink(demo_protein_db, 'humann_db/uniref')
    os.symlink(demo_protein_db, 'humann_db/utility_mapping')
    print('Symlinks to HUMAnN demo databases created')
else:
    print(f'Warning: demo databases not found in {humann_path}')
    if os.path.exists(humann_path):
        for item in os.listdir(humann_path):
            print(f'  {item}')
"
        """
    } else {
        """
        mkdir humann_db
        mkdir humann_db/metaphlan_db

        metaphlan \\
            --install \\
            --index ${metaphlanversion} \\
            --bowtie2db humann_db/metaphlan_db

        humann_databases \\
            --download chocophlan full humann_db \\
            --update-config no

        humann_databases \\
            --download uniref ${database} humann_db \\
            --update-config no

        humann_databases \\
            --download utility_mapping full humann_db \\
            --update-config no
        """
    }

    stub:
    """
    mkdir -p humann_db/metaphlan_db humann_db/chocophlan humann_db/uniref humann_db/utility_mapping
    """
}
