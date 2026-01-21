# Runtime Metrics for Chai-1 Structure Prediction

**Application:** ChaiLab
**Version:** 2.1.0
**Last Updated:** 2026-01-21

---

## Overview

This document provides runtime resource requirements for the Chai-1 molecular structure prediction service. These metrics are derived from acceptance testing on NVIDIA H100 NVL GPUs and are used for job scheduling and resource allocation.

---

## Hardware Requirements

### GPU Requirements

| Requirement | Specification |
|-------------|---------------|
| GPU Type | NVIDIA A100 (minimum), H100 (recommended) |
| GPU Memory | 40GB minimum, 80GB recommended |
| GPU Count | 1 (single GPU per job) |
| CUDA Version | 12.1+ |

### System Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU Cores | 4 | 8 |
| System RAM | 32GB | 64GB |
| Disk Space | 20GB | 50GB |
| Network | Required for MSA server |

---

## Resource Scaling by Input Size

### Small Input (< 200 residues)

**Example:** Single domain protein, ~150 residues

| Resource | Value |
|----------|-------|
| Memory | 32GB |
| CPU | 4 cores |
| GPU Memory | ~20GB |
| Runtime | 15-30 minutes |
| Disk | 10GB |

### Medium Input (200-500 residues)

**Example:** `simple_protein.fasta` - 384 residues

| Resource | Value |
|----------|-------|
| Memory | 64GB |
| CPU | 8 cores |
| GPU Memory | ~40GB |
| Runtime | 30-60 minutes |
| Disk | 25GB |

**Observed Metrics (Test 2):**
- MSA depth: 2,134 sequences
- Prediction score: 0.1809
- Output: Single CIF file (~500KB)

### Large Input (500-1000 residues)

**Example:** `multimer.fasta` - 768 residues (2-chain homodimer)

| Resource | Value |
|----------|-------|
| Memory | 80GB |
| CPU | 8 cores |
| GPU Memory | ~60GB |
| Runtime | 60-120 minutes |
| Disk | 40GB |

**Observed Metrics (Test 4):**
- Chains detected: protein|A, protein|B
- Prediction score: 0.8886
- Output: Single CIF file (~1MB)

### Extra Large Input (> 1000 residues)

**Example:** Large multimer or complex with ligands

| Resource | Value |
|----------|-------|
| Memory | 96GB+ |
| CPU | 8 cores |
| GPU Memory | 80GB |
| Runtime | 2-4 hours |
| Disk | 50GB+ |

---

## Resource Scaling by Features

### MSA Server Usage

When `use_msa_server: true` (default):

| Impact | Value |
|--------|-------|
| Additional Runtime | +15-30 minutes |
| Network Bandwidth | ~50MB download |
| External Dependency | ColabFold MMseqs2 server |

### Templates Server Usage

When `use_templates_server: true`:

| Impact | Value |
|--------|-------|
| Additional Runtime | +10-20 minutes |
| Network Bandwidth | ~100MB download |
| External Dependency | ColabFold + RCSB PDB |

**Observed Metrics (Test 5):**
- Template hits found: 287
- Templates downloaded from RCSB PDB

### Multiple Samples

Runtime scales linearly with sample count:

| Samples | Runtime Multiplier |
|---------|-------------------|
| 1 | 1.0x (baseline) |
| 3 | ~2.5x |
| 5 | ~4x |
| 10 | ~8x |

**Observed Metrics (Test 6):**
- Samples requested: 3
- Outputs generated: 3 CIF files
- Scores: 0.1804, 0.1808, 0.1808

### Constraints/Restraints

When using `constraints_file`:

| Impact | Value |
|--------|-------|
| Additional Runtime | Minimal (+1-2 minutes) |
| Memory | No significant increase |

---

## Preflight Resource Estimation

The service script (`App-ChaiLab.pl`) implements dynamic resource estimation in the `preflight` function:

```perl
# Base resources
cpu = 8
memory = "64G"
runtime = 7200  # 2 hours
storage = "50G"

# Adjustments for num_samples
if (num_samples > 10):
    runtime = 14400  # 4 hours
    memory = "96G"
elif (num_samples > 5):
    runtime = 10800  # 3 hours
    memory = "80G"

# Adjustments for MSA
if (use_msa_server):
    runtime += 1800  # +30 minutes

# Adjustments for templates
if (use_templates_server):
    runtime += 1200  # +20 minutes
```

---

## Storage Requirements

### Input Files

| File Type | Typical Size |
|-----------|--------------|
| FASTA (protein) | 1-10 KB |
| Constraints JSON | 1-5 KB |
| Pre-computed MSA | 10-100 MB |
| Template hits (m8) | 1-10 MB |

### Output Files

| File Type | Typical Size |
|-----------|--------------|
| Structure (CIF) | 200KB - 2MB per sample |
| Scores (JSON) | 1-5 KB |
| Total per job | 1-20 MB |

### Cache Directory

The Chai-Lab model weights and databases are cached:

| Component | Size |
|-----------|------|
| Model weights | ~2GB |
| MSA databases (if local) | ~100GB |
| Template databases (if local) | ~50GB |

**Note:** When using MSA/templates servers, local database storage is not required.

---

## Test Data Reference

Test data is located in `test_data/`:

| File | Description | Size | Residues |
|------|-------------|------|----------|
| `simple_protein.fasta` | Single chain protein | 396 bytes | 384 |
| `multimer.fasta` | 2-chain homodimer | 792 bytes | 768 (2x384) |
| `protein_ligand.fasta` | Protein + ligand (SMILES) | 434 bytes | 384 + ligand |
| `constraints.json` | Pocket restraints | 410 bytes | N/A |

### Test Parameter Files

Located in `tests/`:

| File | Test Scenario |
|------|---------------|
| `params_ws.json` | Simple protein via workspace |
| `params_ws_ligand.json` | Protein-ligand with constraints |
| `params_ws_multimer.json` | Multimer prediction |
| `params_ws_multisamples.json` | Multiple diffusion samples |
| `params_ws_templates.json` | With templates server |
| `params_ws_dry_run.json` | Dry run mode |
| `params_missing_input.json` | Error handling test |

---

## Acceptance Test Results Summary

**Platform:** lambda13 (8x NVIDIA H100 NVL)
**Date:** 2026-01-20

| Test | Input | Runtime | Memory | GPU Mem | Score |
|------|-------|---------|--------|---------|-------|
| 2 | simple_protein (384 res) | ~45 min | 48GB | 35GB | 0.1809 |
| 3 | protein_ligand + constraints | ~50 min | 52GB | 38GB | N/A |
| 4 | multimer (768 res) | ~75 min | 62GB | 55GB | 0.8886 |
| 5 | with templates | ~65 min | 55GB | 40GB | N/A |
| 6 | 3 samples | ~120 min | 58GB | 42GB | 0.1804-0.1808 |

---

## Recommendations

### For Job Scheduling

1. **Default allocation:** 8 CPU, 64GB RAM, 1 GPU (A100/H100), 2-hour runtime
2. **Scale runtime** based on input size and num_samples
3. **Add buffer** for MSA/templates server network latency
4. **Monitor GPU memory** for large inputs (>500 residues)

### For Capacity Planning

1. **GPU utilization:** ~90% during inference
2. **Throughput:** 1-2 predictions per GPU per hour (medium inputs)
3. **Queue management:** Consider separate queues for small/large inputs

### For Cost Optimization

1. Use `num_samples: 1` for initial screening
2. Increase samples only for high-confidence targets
3. Consider pre-computing MSAs for frequently-used sequences
