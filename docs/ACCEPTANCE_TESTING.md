# ChaiApp Acceptance Testing Plan

Acceptance testing for Chai-Lab BV-BRC integration on GPU machine with Apptainer.

## Prerequisites

- GPU machine with NVIDIA CUDA 12.1+
- Apptainer/Singularity installed
- Network access (for MSA server)
- ~10GB disk space (image + cache + outputs)

## Setup

### 1. Clone Repository
```bash
git clone git@github.com:wilke/ChaiApp.git
cd ChaiApp
```

### 2. Build Apptainer Image
```bash
cd container
singularity build chai-lab-bvbrc.sif docker://dxkb/chai-bvbrc:latest-gpu
```
**Expected:** ~6-7GB `.sif` file created (10-20 min)

### 3. Create Working Directories
```bash
cd ..
mkdir -p output cache
```

---

## Test Suite

### Test 1: Container Smoke Test
Verify container basics without GPU.

```bash
# Test help
singularity run chai-lab-bvbrc.sif chai-lab --help

# Test built-in validation
singularity test container/chai-lab-bvbrc.sif

# Verify service script
singularity exec container/chai-lab-bvbrc.sif ls -la /kb/module/service-scripts/
```

**Expected:** Help text displayed, tests pass, `App-ChaiLab.pl` listed.

---

### Test 2: GPU Verification
Confirm GPU is accessible.

```bash
singularity exec --nv container/chai-lab-bvbrc.sif nvidia-smi
```

**Expected:** GPU info displayed (model, memory, CUDA version).

---

### Test 3: Simple Protein Prediction
Single chain protein (~350 residues).

```bash
singularity run --nv \
  --bind $(pwd)/test_data:/data \
  --bind $(pwd)/output:/output \
  --bind $(pwd)/cache:/cache \
  container/chai-lab-bvbrc.sif \
  chai-lab fold /data/simple_protein.fasta /output/test3_simple \
  --use-msa-server --num-samples 1
```

**Expected:**
- Runtime: 10-15 min (first run downloads ~5GB weights)
- Output: CIF structure file in `output/test3_simple/`

**Validation:**
```bash
./tests/validate_output.sh output/test3_simple
```

---

### Test 4: Protein-Ligand with Constraints
Protein + small molecule with pocket constraints.

```bash
singularity run --nv \
  --bind $(pwd)/test_data:/data \
  --bind $(pwd)/output:/output \
  --bind $(pwd)/cache:/cache \
  container/chai-lab-bvbrc.sif \
  chai-lab fold /data/protein_ligand.fasta /output/test4_ligand \
  --use-msa-server --num-samples 1 \
  --constraints /data/constraints.json
```

**Expected:**
- Runtime: 5-10 min (weights cached)
- Output: CIF with protein + ligand coordinates

**Validation:**
```bash
./tests/validate_output.sh output/test4_ligand
```

---

### Test 5: Multimer Prediction
Homodimer (2 identical chains).

```bash
singularity run --nv \
  --bind $(pwd)/test_data:/data \
  --bind $(pwd)/output:/output \
  --bind $(pwd)/cache:/cache \
  container/chai-lab-bvbrc.sif \
  chai-lab fold /data/multimer.fasta /output/test5_multimer \
  --use-msa-server --num-samples 1
```

**Expected:**
- Runtime: 5-10 min
- Output: CIF with 2 chains

**Validation:**
```bash
./tests/validate_output.sh output/test5_multimer
```

---

### Test 6: BV-BRC Service Script
Test the App-ChaiLab.pl service wrapper.

```bash
singularity run --nv \
  --bind $(pwd)/test_data:/data \
  --bind $(pwd)/output:/output \
  --bind $(pwd)/cache:/cache \
  --bind $(pwd)/tests:/tests \
  container/chai-lab-bvbrc.sif \
  App-ChaiLab /tests/params.json
```

**Expected:**
- Service script executes without Perl errors
- Prediction runs (may warn about workspace without full BV-BRC)

---

### Test 7: Multiple Samples (Optional)
Generate multiple structure predictions for diversity.

```bash
singularity run --nv \
  --bind $(pwd)/test_data:/data \
  --bind $(pwd)/output:/output \
  --bind $(pwd)/cache:/cache \
  container/chai-lab-bvbrc.sif \
  chai-lab fold /data/simple_protein.fasta /output/test7_samples \
  --use-msa-server --num-samples 5
```

**Expected:**
- Runtime: 15-25 min
- Output: 5 CIF structure files

---

## Acceptance Criteria

| Test | Criterion | Pass/Fail |
|------|-----------|-----------|
| 1 | Container runs, help displays | |
| 2 | GPU detected via nvidia-smi | |
| 3 | Simple protein produces valid CIF | |
| 4 | Protein-ligand with constraints works | |
| 5 | Multimer prediction works | |
| 6 | Service script executes | |
| 7 | Multiple samples generated (optional) | |

**Minimum for acceptance:** Tests 1-6 pass.

---

## Troubleshooting

### Model weights download fails
```bash
# Pre-populate cache manually
singularity exec --nv container/chai-lab-bvbrc.sif \
  python3 -c "from chai_lab.chai1 import run_inference; print('Ready')"
```

### Out of GPU memory
- Reduce `--num-samples 1`
- Use smaller test sequences
- Check GPU memory with `nvidia-smi`

### MSA server timeout
- Retry - server may be busy
- Check network connectivity
- Consider `--msa-server-url` for alternate server

---

## Quick Reference

```bash
# Build image
singularity build chai-lab-bvbrc.sif docker://dxkb/chai-bvbrc:latest-gpu

# Run prediction
singularity run --nv \
  --bind ./test_data:/data \
  --bind ./output:/output \
  --bind ./cache:/cache \
  chai-lab-bvbrc.sif \
  chai-lab fold /data/simple_protein.fasta /output --use-msa-server

# Interactive shell
singularity shell --nv chai-lab-bvbrc.sif
```
