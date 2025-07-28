process HUMANN_MAKEDB {
    label 'process_medium'
    label 'humann'
    storeDir 'db'
    conda "${moduleDir}/environment.yml"

    input:
    val database

    output:
    path "humann_db"            , emit: db

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def metaphlanversion = 'mpa_vOct22_CHOCOPhlAnSGB_202403'
    def unirefdatabase = database ? database : "uniref90_ec_filtered_diamond"
    def folder = unirefdatabase == "uniref90_ec_filtered_diamond" ? "uniref_filt" : unirefdatabase == "uniref90_diamond" ? "uniref" : "otherdb"
    def test_mode = task.ext.test ?: false
    
    if (test_mode) {
        """
        mkdir -p humann_db
        mkdir humann_db/metaphlan_db
        
        metaphlan \\
           --install \\
           --index $metaphlanversion \\
           --bowtie2db humann_db/metaphlan_db

        # Create symlink to test database in HUMAnN package
        python -c "
import humann
import os
humann_path = os.path.join(os.path.dirname(humann.__file__), 'data')
demo_nucleotide_db = os.path.join(humann_path, 'chocophlan_DEMO')
demo_protein_db = os.path.join(humann_path, 'uniref_DEMO')
demo_utility_db = os.path.join(humann_path, 'utility_DEMO')

print(f'HUMAnN package path: {humann_path}')
print(f'Looking for demo_nucleotide_db at: {demo_nucleotide_db}')
print(f'Looking for demo_protein_db at: {demo_protein_db}')

if os.path.exists(demo_nucleotide_db) and os.path.exists(demo_protein_db):
    print('Demo databases found, creating symlinks...')
    os.symlink(demo_nucleotide_db, 'humann_db/chocophlan')
    os.symlink(demo_protein_db, 'humann_db/$folder')
    os.symlink(demo_protein_db, 'humann_db/utility_mapping')
    print('Symlinks created successfully')
else:
    print('Warning: Demo databases not found, creating minimal structure')
    # List contents to help debug
    if os.path.exists(humann_path):
        print(f'Contents of {humann_path}:')
        for item in os.listdir(humann_path):
            print(f'  {item}')
"
        """
    } else {
        """
        mkdir humann_db
        mkdir humann_db/metaphlan_db
        
        # MetaPhlAn 4.1 database installation
        metaphlan \\
            --install \\
            --index $metaphlanversion \\
            --bowtie2db humann_db/metaphlan_db

        humann_databases \\
            --download chocophlan full humann_db \\
            --update-config no
            
        humann_databases \\
            --download uniref $unirefdatabase humann_db \\
            --update-config no
        
        humann_databases \\
            --download utility_mapping full humann_db \\
            --update-config no
        """
    }
}
