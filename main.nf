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

  publishDir { "${params.outdir}/${sample_id}/qc" }, mode: 'copy'

  input:
    tuple val(sample_id), path(input_h5ad)

  output:
    tuple val(sample_id), path("${sample_id}_filtered.h5ad"), emit: h5ad
    path("qc_report.ipynb"), emit: notebook

  script:
  """
  python3 -m papermill ${baseDir}/notebooks_Template/1_FilteringQC.ipynb qc_report_${sample_id}.ipynb \\
    -p input_file "${input_h5ad}" \\
    -p output_file "${sample_id}_filtered.h5ad" \\
    -p sample_name "${sample_id}"
  """
}

// WORKFLOW DEFINITION
workflow {

  samples_ch = Channel
    .fromPath(params.samplesheet)
    .splitCsv(header: true)
    .map { row -> tuple(row.sample as String, file(row.path)) }

  qc = QC_Filtering(samples_ch)

}