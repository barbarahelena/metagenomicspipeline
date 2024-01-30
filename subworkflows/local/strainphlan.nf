//
// Strainphlan: consensus markers, strainphlan, extract consensus markers, strainphlan, ngd, threshold, concat tables
//



workflow STRAINPHLAN {

    take:


    main:
    ch_versions = Channel.empty()


    emit:
    versions = ch_versions                     // channel: [ versions.yml ]
}

