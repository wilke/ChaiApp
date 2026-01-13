# ChaiApp Acceptance Testing Plan

Acceptance testing for **App-ChaiLab.pl** BV-BRC service script on GPU machine with Apptainer.

> **Note:** The core `chai-lab fold` tool has been validated by performance benchmarks (15 tests, all passed 2025-12-08). This plan focuses on testing the BV-BRC service wrapper.

## Prerequisites

- GPU machine with NVIDIA CUDA 12.1+
- Apptainer/Singularity installed
- Network access (for MSA server)
- Chai-Lab Apptainer image built
- BV-BRC CLI tools installed (p3-login, p3-ls, p3-cp, p3-mkdir, p3-rm)

## Setup

### 1. BV-BRC Workspace Setup

#### 1.1 Verify Login Status
Check your BV-BRC username and workspace path:
```bash
p3-login --status
```

**Expected output:**
```
You are logged in as RAST user <username>@bvbrc
```

Note your username (e.g., `awilke@bvbrc`) - this determines your workspace path.

#### 1.2 Verify Workspace Access
Check your home directory listing:
```bash
p3-ls /<username>@bvbrc/home/
```

Replace `<username>` with your actual username from step 1.1.

#### 1.3 Create Test Directory Structure
Create the AppTests folder structure for ChaiApp testing:
```bash
# Set your username
BVBRC_USER="<username>@bvbrc"

# Create AppTests folder (if it doesn't exist)
p3-mkdir "/${BVBRC_USER}/home/AppTests" 2>/dev/null || echo "AppTests already exists"

# Create ChaiApp folder with input/output subfolders
p3-mkdir "/${BVBRC_USER}/home/AppTests/ChaiApp" 2>/dev/null || echo "ChaiApp already exists"
p3-mkdir "/${BVBRC_USER}/home/AppTests/ChaiApp/input" 2>/dev/null || echo "input already exists"
p3-mkdir "/${BVBRC_USER}/home/AppTests/ChaiApp/output" 2>/dev/null || echo "output already exists"

# Verify structure
p3-ls "/${BVBRC_USER}/home/AppTests/ChaiApp/"
```

#### 1.4 Upload Test Input Data
Copy test input files to the workspace:
```bash
BVBRC_USER="<username>@bvbrc"

# Upload test FASTA files
p3-cp test_data/simple_protein.fasta "ws:/${BVBRC_USER}/home/AppTests/ChaiApp/input/"
p3-cp test_data/multimer.fasta "ws:/${BVBRC_USER}/home/AppTests/ChaiApp/input/"
p3-cp test_data/protein_ligand.fasta "ws:/${BVBRC_USER}/home/AppTests/ChaiApp/input/"

# Verify uploads
p3-ls "/${BVBRC_USER}/home/AppTests/ChaiApp/input/"
```

#### 1.5 Clean Output Folder (for fresh runs)
Before running tests, clean the output folder:
```bash
BVBRC_USER="<username>@bvbrc"

# Remove all files in output folder
p3-rm -r "/${BVBRC_USER}/home/AppTests/ChaiApp/output/*" 2>/dev/null || echo "Output folder already clean"

# Verify it's empty
p3-ls "/${BVBRC_USER}/home/AppTests/ChaiApp/output/"
```

---

### 2. Local Development Setup

#### 2.1 Clone/Pull Repository
```bash
git clone git@github.com:wilke/ChaiApp.git
cd ChaiApp
# or if already cloned:
git pull
```

#### 2.2 Build Apptainer Image (if not already built)
```bash
cd container
singularity build chai-lab-bvbrc.sif docker://dxkb/chai-bvbrc:latest-gpu
cd ..
```

#### 2.3 Create Working Directories
```bash
mkdir -p output cache
```

---

## Test Configuration Files

All test configurations are in `tests/` with unique output paths to prevent overwrites:

| Config File | Purpose | Output Path |
|-------------|---------|-------------|
| `params_ws.json` | BV-BRC workspace basic | `.../output/test_ws_basic` |
| `params_ws_ligand.json` | Protein-ligand with constraints | `.../output/test_ws_ligand` |
| `params_ws_multimer.json` | Multi-chain prediction | `.../output/test_ws_multimer` |
| `params_ws_multisamples.json` | Multiple samples (3) | `.../output/test_ws_multisamples` |
| `params_ws_nosamples.json` | Default samples | `.../output/test_ws_nosamples` |
| `params_ws_templates.json` | Templates server enabled | `.../output/test_ws_templates` |
| `params_missing_input.json` | Error handling test | `.../output/test_ws_error` |

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

### Test 2: Simple Protein via BV-BRC Workspace
Test basic prediction using BV-BRC workspace paths.

**Config:** `tests/params_ws.json`
```json
{
    "input_file": "/awilke@bvbrc/home/AppTests/ChaiApp/input/simple_protein.fasta",
    "output_path": "/awilke@bvbrc/home/AppTests/ChaiApp/output/test_ws_basic",
    "output_file": "ws_basic_prediction",
    "use_msa_server": true,
    "use_templates_server": false,
    "num_samples": 1
}
```

**Expected:**
- Script downloads input from workspace
- Prediction completes successfully
- Results uploaded to workspace output folder

**Validation:**
```bash
p3-ls /awilke@bvbrc/home/AppTests/ChaiApp/output/test_ws_basic/
```

---

### Test 3: Protein-Ligand with Constraints via Service Script
Test constraints file handling.

**Config:** `tests/params_ws_ligand.json`
```json
{
    "input_file": "/awilke@bvbrc/home/AppTests/ChaiApp/input/protein_ligand.fasta",
    "constraints_file": "/awilke@bvbrc/home/AppTests/ChaiApp/input/constraints.json",
    "output_path": "/awilke@bvbrc/home/AppTests/ChaiApp/output/test_ws_ligand",
    "output_file": "ws_ligand_prediction",
    "use_msa_server": true,
    "use_templates_server": false,
    "num_samples": 1
}
```

**Expected:**
- Script downloads constraints file
- chai-lab runs with `--constraints` flag
- Output contains protein + ligand structure

**Validation:**
```bash
p3-ls /awilke@bvbrc/home/AppTests/ChaiApp/output/test_ws_ligand/
```

---

### Test 4: Multimer via Service Script
Test multi-chain handling.

**Config:** `tests/params_ws_multimer.json`
```json
{
    "input_file": "/awilke@bvbrc/home/AppTests/ChaiApp/input/multimer.fasta",
    "output_path": "/awilke@bvbrc/home/AppTests/ChaiApp/output/test_ws_multimer",
    "output_file": "ws_multimer_prediction",
    "use_msa_server": true,
    "use_templates_server": false,
    "num_samples": 1
}
```

**Expected:**
- Script reports 2 sequences found
- Output contains 2-chain structure

**Validation:**
```bash
p3-ls /awilke@bvbrc/home/AppTests/ChaiApp/output/test_ws_multimer/
```

---

### Test 5: Templates Server Option
Test use_templates_server parameter.

**Config:** `tests/params_ws_templates.json`
```json
{
    "input_file": "/awilke@bvbrc/home/AppTests/ChaiApp/input/simple_protein.fasta",
    "output_path": "/awilke@bvbrc/home/AppTests/ChaiApp/output/test_ws_templates",
    "output_file": "ws_templates_prediction",
    "use_msa_server": true,
    "use_templates_server": true,
    "num_samples": 1
}
```

**Expected:**
- chai-lab runs with `--use-templates-server` flag
- Prediction completes (may take longer due to template search)

**Validation:**
```bash
p3-ls /awilke@bvbrc/home/AppTests/ChaiApp/output/test_ws_templates/
```

---

### Test 6: Multiple Samples
Test num_samples parameter handling.

**Config:** `tests/params_ws_multisamples.json`
```json
{
    "input_file": "/awilke@bvbrc/home/AppTests/ChaiApp/input/simple_protein.fasta",
    "output_path": "/awilke@bvbrc/home/AppTests/ChaiApp/output/test_ws_multisamples",
    "output_file": "ws_multisamples_prediction",
    "use_msa_server": true,
    "use_templates_server": false,
    "num_samples": 3
}
```

**Expected:**
- chai-lab runs with `--num-samples 3`
- Output contains 3 structure predictions

**Validation:**
```bash
p3-ls /awilke@bvbrc/home/AppTests/ChaiApp/output/test_ws_multisamples/
```

---

### Test 7: Error Handling - Missing Input
Test service script handles missing input gracefully.

**Config:** `tests/params_missing_input.json`
```json
{
    "input_file": "/awilke@bvbrc/home/AppTests/ChaiApp/input/nonexistent.fasta",
    "output_path": "/awilke@bvbrc/home/AppTests/ChaiApp/output/test_ws_error",
    "output_file": "ws_error_prediction",
    "use_msa_server": true,
    "use_templates_server": false,
    "num_samples": 1
}
```

**Expected:**
- Script exits with error
- Error message indicates file not found

---

## Acceptance Criteria

| Test | Description | Pass/Fail |
|------|-------------|-----------|
| 1 | Service script syntax check | |
| 2 | Simple protein (workspace) via App-ChaiLab.pl | |
| 3 | Protein-ligand with constraints | |
| 4 | Multimer prediction | |
| 5 | Templates server option | |
| 6 | Multiple samples parameter | |
| 7 | Error handling for missing input | |

**Minimum for acceptance:** Tests 1-4 and 7 pass.

---

## Quick Reference

```bash
# Direct chai-lab (for comparison/debugging)
singularity run --nv \
  --bind ./test_data:/data \
  --bind ./output:/output \
  container/chai-lab-bvbrc.sif \
  chai-lab fold /data/simple_protein.fasta /output/test_debug --use-msa-server

# Verify workspace outputs
p3-ls /awilke@bvbrc/home/AppTests/ChaiApp/output/
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
