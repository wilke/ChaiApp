#!/usr/bin/env cwl-runner

cwlVersion: v1.2
class: CommandLineTool

label: Chai-1 Molecular Structure Prediction
doc: |
  Chai-1 molecular structure prediction for proteins, nucleic acids, and ligands.

  Chai-Lab's Chai-1 is a multi-modal foundation model for molecular structure
  prediction. It supports:
  - Protein structure prediction
  - Multi-chain protein complexes
  - Protein-DNA/RNA complexes
  - Small molecule ligand binding
  - Covalent modifications
  - Experimental restraints

  For more information: https://github.com/chaidiscovery/chai-lab

requirements:
  DockerRequirement:
    dockerPull: dxkb/chai-bvbrc:latest-gpu
  ResourceRequirement:
    coresMin: 8
    ramMin: 65536  # 64GB
    tmpdirMin: 51200  # 50GB
  NetworkAccess:
    networkAccess: true  # For MSA server access
  InlineJavascriptRequirement: {}

hints:
  cwltool:CUDARequirement:
    cudaVersionMin: "11.8"
    cudaDeviceCountMin: 1
    cudaDeviceCountMax: 1

baseCommand: [chai-lab, fold]

inputs:
  input_fasta:
    type: File
    inputBinding:
      position: 1
    doc: |
      Input FASTA file with sequences to fold.
      Multiple chains can be specified with separate FASTA entries.
      Chain types are inferred from sequence content:
      - Standard amino acids: protein
      - ACGT/U: nucleic acid
      Special prefixes in headers can specify ligands and modifications.

  output_directory:
    type: string
    default: output
    inputBinding:
      position: 2
    doc: Output directory for prediction results.

  use_msa_server:
    type: boolean?
    default: true
    inputBinding:
      prefix: --use-msa-server
    doc: |
      Use the ColabFold MSA server for generating multiple sequence alignments.
      Recommended for best prediction quality. Requires network access.

  use_templates_server:
    type: boolean?
    default: false
    inputBinding:
      prefix: --use-templates-server
    doc: |
      Use template structures from the PDB via the templates server.
      Can improve predictions when homologous structures exist.

  num_samples:
    type: int?
    default: 5
    inputBinding:
      prefix: --num-samples
    doc: |
      Number of structure samples to generate. More samples provide
      diversity but increase runtime. Default: 5.

  constraints_file:
    type: File?
    inputBinding:
      prefix: --constraints
    doc: |
      JSON file specifying experimental restraints/constraints.
      Supports distance constraints, contact maps, and other
      experimental data to guide prediction.

  msa_file:
    type: File?
    inputBinding:
      prefix: --msa-file
    doc: |
      Pre-computed MSA file. Use this if you have already generated
      alignments and want to skip the MSA server step.

  template_hits_file:
    type: File?
    inputBinding:
      prefix: --template-hits
    doc: |
      Pre-computed template hits file. Use this if you have already
      searched for templates and want to skip the templates server.

outputs:
  predictions:
    type: Directory
    outputBinding:
      glob: $(inputs.output_directory)
    doc: |
      Directory containing all prediction outputs including:
      - Structure files (CIF format)
      - Confidence scores
      - Predicted aligned error (PAE) matrices
      - Summary statistics

  structure_files:
    type: File[]
    outputBinding:
      glob: "$(inputs.output_directory)/**/*.cif"
    doc: Predicted structure files in mmCIF format.

  confidence_files:
    type: File[]
    outputBinding:
      glob: "$(inputs.output_directory)/**/*scores*.npz"
    doc: Confidence score files (pLDDT, PAE) in NPZ format.

  summary:
    type: File?
    outputBinding:
      glob: "$(inputs.output_directory)/**/summary*.json"
    doc: Summary JSON with prediction statistics and rankings.

stdout: chailab_stdout.txt
stderr: chailab_stderr.txt

s:author:
  - class: s:Person
    s:name: BV-BRC Team
    s:email: help@bv-brc.org

s:license: https://spdx.org/licenses/Apache-2.0

$namespaces:
  s: https://schema.org/
  cwltool: http://commonwl.org/cwltool#

$schemas:
  - https://schema.org/version/latest/schemaorg-current-https.rdf
