# Chai-Lab Input Reference

This document describes all inputs for Chai-1 molecular structure prediction, categorized by their nature: **constant/infrastructure** inputs vs **variable/user-provided** inputs.

---

## Input Categories Overview

| Category | Type | Examples |
|----------|------|----------|
| **Infrastructure (Constant)** | Model weights, databases, servers | Chai-1 weights, MSA server URL |
| **Required (Variable)** | User must provide | Input FASTA sequences, output path |
| **Optional (Variable)** | User may provide | Constraints, pre-computed MSAs, templates |
| **Runtime Parameters** | User-configurable settings | Number of samples, server toggles |

---

## 1. Infrastructure/Constant Inputs

These are **pre-configured resources** that remain constant across runs. Users do not need to provide these.

### 1.1 Model Weights (~5GB)

| Component | Description | Location | Source |
|-----------|-------------|----------|--------|
| Chai-1 weights | Neural network parameters | `$CHAI_DOWNLOADS_DIR/` or `/cache/` | Auto-downloaded on first run |
| Tokenizers | Sequence tokenization models | Included with weights | Hugging Face |

**Notes:**
- Weights are automatically downloaded on first run
- Cache location: `/cache/` in containers (bind mount for persistence)
- Environment variable: `CHAI_DOWNLOADS_DIR`
- Size: ~5GB total

### 1.2 External Servers (Optional but Recommended)

| Server | URL | Purpose | Required |
|--------|-----|---------|----------|
| ColabFold MSA Server | `https://api.colabfold.com` | Generate MSAs from sequence databases | No (improves accuracy) |
| Templates Server | (ColabFold) | Search PDB for structural templates | No (improves accuracy) |

**Server Requirements:**
- Network access required when using servers
- Rate limits apply to public servers
- Self-hosting option available for high-throughput

### 1.3 System Dependencies

| Dependency | Purpose | Container Location |
|------------|---------|-------------------|
| Python 3.10 | Runtime | `/opt/venv/` |
| CUDA 12.1+ | GPU acceleration | System |
| Kalign | Template alignment | `/usr/bin/kalign` |
| PyTorch | Deep learning | Installed via pip |

### 1.4 GPU Requirements

| GPU Type | VRAM | Suitable For |
|----------|------|--------------|
| A100 80GB | 80GB | Large complexes, multiple chains |
| A100 40GB | 40GB | Medium complexes |
| A10/A30 | 24GB | Small proteins |
| RTX 4090 | 24GB | Single chains, small complexes |

---

## 2. Required Variable Inputs

These **must be provided by the user** for each prediction job.

### 2.1 Input FASTA File (Required)

The primary input describing molecules to predict.

**Format:** Extended FASTA with entity type annotations

```
>CHAIN_ID|ENTITY_TYPE
SEQUENCE
```

**Supported Entity Types:**

| Entity Type | Description | Sequence Format | Example |
|-------------|-------------|-----------------|---------|
| `protein` | Protein chain (default) | Amino acid codes (ACDEFGHIKLMNPQRSTVWY) | `MVTPEGNVSL...` |
| `dna` | DNA strand | Nucleotides (ATCG) | `ATCGATCG...` |
| `rna` | RNA strand | Nucleotides (AUCG) | `AUGCAUGC...` |
| `smiles` | Small molecule/ligand | SMILES notation | `CC(=O)OC1=CC=CC=C1` |

**Examples:**

**Single protein:**
```fasta
>A|protein
MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
```

**Protein-ligand complex:**
```fasta
>A|protein
MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
>L|smiles
CC(=O)OC1=CC=CC=C1C(=O)O
```

**Protein-DNA complex:**
```fasta
>A|protein
MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
>B|dna
ATCGATCGATCGATCG
>C|dna
CGATCGATCGATCGAT
```

**Modified residues (phosphorylation, glycosylation):**
```fasta
>A|protein
MVTPEGN[SEP]SLVDESLLVGVTDED[TPO]RAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
```

Where `[SEP]` = phosphoserine, `[TPO]` = phosphothreonine, `[NAG-FUC]` = glycan.

### 2.2 Output Path (Required)

Where to save prediction results.

| Interface | Parameter | Example |
|-----------|-----------|---------|
| CLI | Positional argument | `chai-lab fold input.fasta output_dir/` |
| BV-BRC | `output_path` | Workspace folder path |
| CWL | `output_directory` | `chailab_output` |

---

## 3. Optional Variable Inputs

These **may be provided** to guide or improve predictions.

### 3.1 Constraints File (JSON)

Experimental restraints to guide structure prediction.

**File naming:** `*_constraints.json` or passed via `--constraints` flag

**Supported constraint types:**

#### Distance Restraints
Specify expected distances between atoms:

```json
{
  "restraints": [
    {
      "type": "distance",
      "chain1": "A",
      "residue1": 45,
      "atom1": "CA",
      "chain2": "B",
      "residue2": 67,
      "atom2": "CA",
      "distance": 8.0,
      "tolerance": 2.0
    }
  ]
}
```

#### Contact Restraints
Specify that residues should be in contact:

```json
{
  "restraints": [
    {
      "type": "contact",
      "chain1": "A",
      "residue1": 45,
      "chain2": "L",
      "residue2": 1,
      "max_distance": 6.0
    }
  ]
}
```

#### Pocket Restraints
Define binding pocket residues for ligand docking:

```json
{
  "restraints": [
    {
      "type": "pocket",
      "binder_chain": "L",
      "pocket_residues": [
        {"chain": "A", "residue": 45},
        {"chain": "A", "residue": 67},
        {"chain": "A", "residue": 89}
      ],
      "max_distance": 6.0
    }
  ]
}
```

#### Covalent Bonds
Specify covalent connections between chains:

```json
{
  "covalent_bonds": [
    {
      "chain1": "A",
      "residue1": 123,
      "atom1": "SG",
      "chain2": "L",
      "residue2": 1,
      "atom2": "C1"
    }
  ]
}
```

### 3.2 Pre-computed MSA File

Provide your own Multiple Sequence Alignment instead of using the MSA server.

| Format | Extension | Description |
|--------|-----------|-------------|
| Parquet | `.aligned.pqt` | Chai-Lab native format with metadata |
| A3M | `.a3m` | Can be converted to Parquet |

**Usage:**
```bash
chai-lab fold input.fasta output/ --msa-file precomputed.aligned.pqt
```

**Converting A3M to Parquet:**
```bash
chai a3m-to-pqt input.a3m output.aligned.pqt
```

### 3.3 Template Hits File

Pre-computed structural templates from PDB.

| Format | Extension | Description |
|--------|-----------|-------------|
| M8 | `.m8` | MMseqs2 search results |

**Usage:**
```bash
chai-lab fold input.fasta output/ --template-hits templates.m8
```

---

## 4. Runtime Parameters

User-configurable settings that affect prediction behavior.

### 4.1 MSA Server Toggle

| Parameter | Default | Description |
|-----------|---------|-------------|
| `use_msa_server` | `true` | Use ColabFold MSA server for alignments |

**CLI:** `--use-msa-server` (enabled by default in BV-BRC)

**Impact:** Significantly improves prediction accuracy. Adds 1-10 minutes runtime.

### 4.2 Templates Server Toggle

| Parameter | Default | Description |
|-----------|---------|-------------|
| `use_templates_server` | `false` | Search PDB for structural templates |

**CLI:** `--use-templates-server`

**Impact:** Can improve predictions when homologs exist. Adds ~5 minutes runtime.

### 4.3 Number of Samples

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| `num_samples` | `5` | 1-50+ | Structure samples to generate |

**CLI:** `--num-samples N`

**Impact:**
- More samples = more diversity, longer runtime
- Default of 5 balances quality and speed
- >10 samples significantly increases runtime and memory

### 4.4 Resource Estimates by Configuration

| Configuration | Memory | Runtime | GPU |
|---------------|--------|---------|-----|
| 1-5 samples, MSA server | 64GB | ~2 hours | A100 |
| 5-10 samples, MSA server | 80GB | ~3 hours | A100 |
| >10 samples, MSA+Templates | 96GB | ~4 hours | A100 80GB |

---

## 5. Output Files

Chai-Lab produces these outputs (not user inputs, but included for completeness):

| File | Format | Description |
|------|--------|-------------|
| `pred.model_idx_*.cif` | mmCIF | Predicted structures |
| `scores.model_idx_*.npz` | NumPy | Confidence scores (pLDDT, PAE) |
| `summary.json` | JSON | Ranking and statistics |

**Key confidence metrics:**

| Metric | Range | Interpretation |
|--------|-------|----------------|
| pLDDT | 0-100 | Per-residue confidence (>70 = reliable) |
| pTM | 0-1 | Global fold confidence (>0.5 = reliable) |
| ipTM | 0-1 | Interface confidence for complexes |

---

## 6. Quick Reference Tables

### Input Summary

| Input | Type | Required | User Provides | Changes Per Job |
|-------|------|----------|---------------|-----------------|
| Model weights | Infrastructure | Yes | No | Never |
| MSA server | Infrastructure | No | No | Never |
| Templates server | Infrastructure | No | No | Never |
| CUDA/GPU | Infrastructure | Yes | No | Never |
| **Input FASTA** | Variable | **Yes** | **Yes** | **Every job** |
| **Output path** | Variable | **Yes** | **Yes** | **Every job** |
| Constraints JSON | Variable | No | Yes | Per job |
| Pre-computed MSA | Variable | No | Yes | Per job |
| Template hits | Variable | No | Yes | Per job |
| `num_samples` | Parameter | No | Yes | Per job |
| `use_msa_server` | Parameter | No | Yes | Per job |
| `use_templates_server` | Parameter | No | Yes | Per job |

### BV-BRC App Spec Parameters

| Parameter ID | Type | Required | Default | Description |
|--------------|------|----------|---------|-------------|
| `input_file` | wsfile | Yes | - | Input FASTA file |
| `output_path` | folder | Yes | - | Output workspace folder |
| `constraints_file` | wsfile | No | - | Constraints JSON |
| `use_msa_server` | bool | No | true | Enable MSA server |
| `use_templates_server` | bool | No | false | Enable templates server |
| `num_samples` | int | No | 5 | Number of samples |
| `msa_file` | wsfile | No | - | Pre-computed MSA |
| `template_hits_file` | wsfile | No | - | Template hits file |

---

## 7. Example Workflows

### Minimal Prediction (single protein)

```bash
# Create input
cat > input.fasta << 'EOF'
>myprotein|protein
MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
EOF

# Run prediction
chai-lab fold input.fasta output/ --use-msa-server
```

### Protein-Ligand Docking with Pocket Constraints

```bash
# input.fasta
cat > input.fasta << 'EOF'
>protein|protein
MVTPEGNVSLVDESLLVGVTDEDRAVRSAHQFYERLIGLWAPAVMEAAHELGVFAALAE
>drug|smiles
CC(=O)OC1=CC=CC=C1C(=O)O
EOF

# constraints.json
cat > constraints.json << 'EOF'
{
  "restraints": [{
    "type": "pocket",
    "binder_chain": "drug",
    "pocket_residues": [
      {"chain": "protein", "residue": 12},
      {"chain": "protein", "residue": 15},
      {"chain": "protein", "residue": 34}
    ],
    "max_distance": 6.0
  }]
}
EOF

# Run prediction
chai-lab fold input.fasta output/ \
  --use-msa-server \
  --constraints constraints.json \
  --num-samples 10
```

### BV-BRC Service Invocation

```json
{
  "input_file": "/user@bvbrc.org/home/my_protein.fasta",
  "output_path": "/user@bvbrc.org/home/predictions/",
  "use_msa_server": true,
  "use_templates_server": true,
  "num_samples": 5
}
```

---

## References

- [Chai-Lab GitHub](https://github.com/chaidiscovery/chai-lab)
- [Chai-1 Paper](https://www.biorxiv.org/content/10.1101/2024.10.10.615955)
- [ColabFold MSA Server](https://github.com/sokrypton/ColabFold)
- [INPUT_FORMATS.md](./INPUT_FORMATS.md) - Detailed format specifications
- [MSA_SERVER.md](./MSA_SERVER.md) - MSA server documentation
