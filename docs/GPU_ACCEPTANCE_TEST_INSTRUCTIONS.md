# GPU Acceptance Test Instructions

**Date:** 2026-01-20
**Image:** `dxkb/chai-bvbrc:test` (also tagged `20260120-f959602`)
**Digest:** `sha256:e92a6f5e6cf98564eb448602531b3d652431963e50ac6ff1f8bea0d589dd1e6a`

---

## Issue #7 Has Been Fixed

The CLI option mismatches reported in Issue #7 have been corrected in this build:

| Parameter | Old (broken) | New (fixed) |
|-----------|--------------|-------------|
| Constraints | `--constraints` | `--constraint-path` |
| MSA directory | `--msa-file` | `--msa-directory` |
| Template hits | `--template-hits` | `--template-hits-path` |

**Build includes:**
- Git commit: `f9596026c544d5a2af2ac718fd9919821421c3a7`
- Version: 2.1.0
- Build date: 2026-01-20T18:56:04Z

---

## Instructions for Claude Code on GPU Machine

### Step 1: Pull Updated Image and Build Apptainer

```bash
# Navigate to ChaiApp directory
cd /path/to/ChaiApp

# Pull latest code
git pull

# Build new Apptainer image from updated Docker image
singularity build --force chai-lab-bvbrc.sif docker://dxkb/chai-bvbrc:test
```

### Step 2: Verify Build Metadata

```bash
# Check build info
singularity exec chai-lab-bvbrc.sif cat /kb/module/BUILD_INFO

# Expected output:
# BUILD_DATE=2026-01-20T18:56:04Z
# GIT_COMMIT=f9596026c544d5a2af2ac718fd9919821421c3a7
# GIT_BRANCH=main
# VERSION=2.1.0
```

### Step 3: Verify CLI Fix

```bash
# Verify the constraint-path fix is present
singularity exec chai-lab-bvbrc.sif grep "constraint-path" /kb/module/service-scripts/App-ChaiLab.pl

# Expected output:
# push @cmd, "--constraint-path", $local_constraints;
```

### Step 4: Re-run Test 3 (Protein-Ligand with Constraints)

This test was previously blocked by Issue #7.

```bash
# Create test params file
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

# Clear previous output
rm -rf output/*

# Run the test
singularity run --nv \
  --bind $(pwd)/test_data:/data \
  --bind $(pwd)/output:/output \
  --bind $(pwd)/cache:/cache \
  --bind $(pwd)/tests:/tests \
  chai-lab-bvbrc.sif \
  App-ChaiLab /tests/params_ligand.json

# Validate output
./tests/validate_output.sh output/
```

**Expected Result:**
- chai-lab runs with `--constraint-path` flag
- Prediction completes successfully
- Output contains protein + ligand structure in CIF format

### Step 5: Run Full Acceptance Test Suite (Optional)

If Test 3 passes, run the remaining tests to confirm all functionality:

```bash
# Test 1: Syntax check
singularity exec chai-lab-bvbrc.sif \
  perl -c /kb/module/service-scripts/App-ChaiLab.pl

# Test 2: Simple protein
singularity run --nv \
  --bind $(pwd)/test_data:/data \
  --bind $(pwd)/output:/output \
  --bind $(pwd)/cache:/cache \
  --bind $(pwd)/tests:/tests \
  chai-lab-bvbrc.sif \
  App-ChaiLab /tests/params.json

# Test 7: Error handling
cat > tests/params_bad.json << 'EOF'
{
    "input_file": "/data/nonexistent.fasta",
    "output_path": "/output",
    "use_msa_server": true,
    "num_samples": 1
}
EOF

singularity run --nv \
  --bind $(pwd)/test_data:/data \
  --bind $(pwd)/output:/output \
  --bind $(pwd)/tests:/tests \
  chai-lab-bvbrc.sif \
  App-ChaiLab /tests/params_bad.json
# Should exit with error about missing file
```

---

## Expected Acceptance Test Results

| Test | Description | Expected |
|:----:|-------------|:--------:|
| 1 | Syntax check | ✅ PASS |
| 2 | Simple protein | ✅ PASS |
| 3 | **Protein-ligand with constraints** | ✅ PASS (was blocked) |
| 4 | Multimer | ✅ PASS |
| 5 | Templates server | ✅ PASS |
| 6 | Multiple samples | ✅ PASS |
| 7 | Error handling | ✅ PASS |

**Target: 7/7 tests passing**

---

## After Testing

If all tests pass:

1. Update `docs/ACCEPTANCE_TEST_RESULTS_2026-01-13.md` with new results
2. Close Issue #7 if not already closed
3. Consider promoting `test` tag to `latest-gpu`:
   ```bash
   docker tag dxkb/chai-bvbrc:test dxkb/chai-bvbrc:latest-gpu
   docker push dxkb/chai-bvbrc:latest-gpu
   ```

---

## Troubleshooting

### Image not found
```bash
# Force pull latest
singularity pull --force docker://dxkb/chai-bvbrc:test
```

### Cache issues
```bash
# Clear Singularity cache
singularity cache clean
```

### Verify correct image
```bash
singularity inspect chai-lab-bvbrc.sif | grep -i version
```
