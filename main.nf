nextflow.enable.dsl=2

// Define input parameters
params.samplesheet = null
params.outdir = 'results'
params.batch_col = 'batch'

// Validate input
if (params.samplesheet == null) {
    exit 1, "Please provide a samplesheet with --samplesheet"
}

// PROCESSES DEFINITION

process QC_Filtering {

    conda "${baseDir}/env/base.yml" 

  publishDir { "${params.outdir}/1_QC/${sample_id}" }, mode: 'copy'

  input:
    tuple val(sample_id), path(input_h5ad)

  output:
    tuple val(sample_id), path("${sample_id}_filtered.h5ad"), emit: h5ad
    path("qc_report_${sample_id}.ipynb"), emit: notebook

  script:
  """
  python3 -m papermill ${baseDir}/notebooks_Template/1_FilteringQC.ipynb qc_report_${sample_id}.ipynb \\
    -p input_file "${input_h5ad}" \\
    -p output_file "${sample_id}_filtered.h5ad" \\
    -p sample_name "${sample_id}"
  """
}
process concatenate_h5ad {
    conda "${baseDir}/env/base.yml"

    publishDir "${params.outdir}/2_Concatenate/", mode: 'copy'

    input:
        path all_h5ad

    output:
        path("concatenated_filtered.h5ad"), emit: concatenated_h5ad
        path("concatenate_report.ipynb"), emit: notebook

    script:
    """
    #!/usr/bin/env bash
    set -euo pipefail

    # Write YAML for papermill
    echo "input_files:" > params.yml
    for f in ${all_h5ad}; do
        echo "  - \${f}" >> params.yml
    done
    echo "output_file: concatenated_filtered.h5ad" >> params.yml
    echo "batch_col: ${params.batch_col}" >> params.yml

    # Run papermill
    python3 -m papermill ${baseDir}/notebooks_Template/2_Concatenate.ipynb \\
        concatenate_report.ipynb -f params.yml
    """
}


workflow {
    samples_ch = channel
        .fromPath(params.samplesheet)
        .splitCsv(header: true)
        .map { row -> tuple(row.sample as String, file(row.path)) }
      qc = QC_Filtering(samples_ch)

    filtered_list = qc.h5ad.map { it[1] }.toList()
    concatenate_h5ad(filtered_list)
    // collect all filtered h5ads into one single list value


}