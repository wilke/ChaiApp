# ChaiApp Acceptance Testing Plan

Acceptance testing for **App-ChaiLab.pl** BV-BRC service script on GPU machine with Apptainer.

> **Note:** The core `chai-lab fold` tool has been validated by performance benchmarks (15 tests, all passed 2025-12-08). This plan focuses on testing the BV-BRC service wrapper.

## Prerequisites

- GPU machine with NVIDIA CUDA 12.1+
- Apptainer/Singularity installed
- Network access (for MSA server)
- Chai-Lab Apptainer image built

## Setup

### 1. Clone/Pull Repository
```bash
git clone git@github.com:wilke/ChaiApp.git
cd ChaiApp
# or if already cloned:
git pull
```

### 2. Build Apptainer Image (if not already built)
```bash
cd container
singularity build chai-lab-bvbrc.sif docker://dxkb/chai-bvbrc:latest-gpu
cd ..
```

### 3. Create Working Directories
```bash
mkdir -p output cache
```

---

## Test Suite: App-ChaiLab.pl Service Script

### Test 1: Service Script Syntax Check
Verify Perl script compiles without errors.

```bash
singularity exec container/chai-lab-bvbrc.sif \
  perl -c /kb/module/service-scripts/App-ChaiLab.pl
```

**Expected:** `App-ChaiLab.pl syntax OK`

---

### Test 2: Simple Protein via Service Script
Test basic prediction through App-ChaiLab.pl.

```bash
singularity run --nv \
  --bind $(pwd)/test_data:/data \
  --bind $(pwd)/output:/output \
  --bind $(pwd)/cache:/cache \
  --bind $(pwd)/tests:/tests \
  container/chai-lab-bvbrc.sif \
  App-ChaiLab /tests/params.json
```

**params.json used:**
```json
{
    "input_file": "/data/simple_protein.fasta",
    "output_path": "/output",
    "use_msa_server": true,
    "use_templates_server": false,
    "num_samples": 1
}
```

**Expected:**
- Script prints "Starting Chai-1 structure prediction"
- Script prints "Found N sequence(s) in input file"
- Prediction runs via chai-lab fold
- Script prints "Chai-lab job completed"
- CIF file(s) in `output/`

**Validation:**
```bash
./tests/validate_output.sh output/
```

---

### Test 3: Protein-Ligand with Constraints via Service Script
Test constraints file handling.

First, create test params:
```bash
cat > tests/params_ligand.json << 'EOF'
{
    "input_file": "/data/protein_ligand.fasta",
    "constraints_file": "/data/constraints.json",
    "output_path": "/output",
    "use_msa_server": true,
    "use_templates_server": false,
    "num_samples": 1
}
EOF
```

Run test:
```bash
rm -rf output/*
singularity run --nv \
  --bind $(pwd)/test_data:/data \
  --bind $(pwd)/output:/output \
  --bind $(pwd)/cache:/cache \
  --bind $(pwd)/tests:/tests \
  container/chai-lab-bvbrc.sif \
  App-ChaiLab /tests/params_ligand.json
```

**Expected:**
- Script downloads constraints file
- chai-lab runs with `--constraints` flag
- Output contains protein + ligand structure

---

### Test 4: Multimer via Service Script
Test multi-chain handling.

```bash
cat > tests/params_multimer.json << 'EOF'
{
    "input_file": "/data/multimer.fasta",
    "output_path": "/output",
    "use_msa_server": true,
    "use_templates_server": false,
    "num_samples": 1
}
EOF
```

Run test:
```bash
rm -rf output/*
singularity run --nv \
  --bind $(pwd)/test_data:/data \
  --bind $(pwd)/output:/output \
  --bind $(pwd)/cache:/cache \
  --bind $(pwd)/tests:/tests \
  container/chai-lab-bvbrc.sif \
  App-ChaiLab /tests/params_multimer.json
```

**Expected:**
- Script reports 2 sequences found
- Output contains 2-chain structure

---

### Test 5: Templates Server Option
Test use_templates_server parameter.

```bash
cat > tests/params_templates.json << 'EOF'
{
    "input_file": "/data/simple_protein.fasta",
    "output_path": "/output",
    "use_msa_server": true,
    "use_templates_server": true,
    "num_samples": 1
}
EOF
```

Run test:
```bash
rm -rf output/*
singularity run --nv \
  --bind $(pwd)/test_data:/data \
  --bind $(pwd)/output:/output \
  --bind $(pwd)/cache:/cache \
  --bind $(pwd)/tests:/tests \
  container/chai-lab-bvbrc.sif \
  App-ChaiLab /tests/params_templates.json
```

**Expected:**
- chai-lab runs with `--use-templates-server` flag
- Prediction completes (may take longer due to template search)

---

### Test 6: Multiple Samples
Test num_samples parameter handling.

```bash
cat > tests/params_samples.json << 'EOF'
{
    "input_file": "/data/simple_protein.fasta",
    "output_path": "/output",
    "use_msa_server": true,
    "use_templates_server": false,
    "num_samples": 3
}
EOF
```

Run test:
```bash
rm -rf output/*
singularity run --nv \
  --bind $(pwd)/test_data:/data \
  --bind $(pwd)/output:/output \
  --bind $(pwd)/cache:/cache \
  --bind $(pwd)/tests:/tests \
  container/chai-lab-bvbrc.sif \
  App-ChaiLab /tests/params_samples.json
```

**Expected:**
- chai-lab runs with `--num-samples 3`
- Output contains 3 structure predictions

---

### Test 7: Error Handling - Missing Input
Test service script handles missing input gracefully.

```bash
cat > tests/params_bad.json << 'EOF'
{
    "input_file": "/data/nonexistent.fasta",
    "output_path": "/output",
    "use_msa_server": true,
    "num_samples": 1
}
EOF
```

Run test:
```bash
singularity run --nv \
  --bind $(pwd)/test_data:/data \
  --bind $(pwd)/output:/output \
  --bind $(pwd)/cache:/cache \
  --bind $(pwd)/tests:/tests \
  container/chai-lab-bvbrc.sif \
  App-ChaiLab /tests/params_bad.json
```

**Expected:**
- Script exits with error
- Error message indicates file not found

---

## Acceptance Criteria

| Test | Description | Pass/Fail |
|------|-------------|-----------|
| 1 | Service script syntax check | |
| 2 | Simple protein via App-ChaiLab.pl | |
| 3 | Protein-ligand with constraints | |
| 4 | Multimer prediction | |
| 5 | Templates server option | |
| 6 | Multiple samples parameter | |
| 7 | Error handling for missing input | |

**Minimum for acceptance:** Tests 1-4 and 7 pass.

---

## Quick Reference

```bash
# Run App-ChaiLab.pl
singularity run --nv \
  --bind ./test_data:/data \
  --bind ./output:/output \
  --bind ./cache:/cache \
  --bind ./tests:/tests \
  container/chai-lab-bvbrc.sif \
  App-ChaiLab /tests/params.json

# Direct chai-lab (for comparison/debugging)
singularity run --nv \
  --bind ./test_data:/data \
  --bind ./output:/output \
  container/chai-lab-bvbrc.sif \
  chai-lab fold /data/simple_protein.fasta /output --use-msa-server
```

---

## Reference: Benchmark Results (chai-lab validated)

The core `chai-lab fold` command was validated on 2025-12-08:

| Test | Chains | Residues | Time (s) | Memory (GB) | Status |
|------|--------|----------|----------|-------------|--------|
| single_50aa | 1 | 50 | 61 | 10.5 | PASS |
| single_500aa | 1 | 500 | 78 | 12.7 | PASS |
| single_1000aa | 1 | 1000 | 151 | 20.2 | PASS |
| 2chain_medium | 2 | 400 | 83 | 12.7 | PASS |
| 5chain_small | 5 | 400 | 83 | 12.7 | PASS |

All 15 benchmark tests passed with exit code 0.
