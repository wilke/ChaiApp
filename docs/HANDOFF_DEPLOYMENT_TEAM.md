# Deployment Team Hand-off Document: ChaiLab

**Application:** Chai-1 Molecular Structure Prediction
**App ID:** ChaiLab
**Version:** 2.1.0
**Date:** 2026-01-21

---

## Overview

This document provides all information needed to deploy the ChaiLab application to the BV-BRC production environment.

---

## Container Information

### Docker Image

| Property | Value |
|----------|-------|
| Registry | DockerHub |
| Image | `dxkb/chai-bvbrc:latest-gpu` |
| Alternative Tag | `dxkb/chai-bvbrc:20260120-f959602` |
| Digest | `sha256:e92a6f5e6cf98564eb448602531b3d652431963e50ac6ff1f8bea0d589dd1e6a` |
| Size | ~15GB |
| Platform | linux/amd64 |
| Base | `dxkb/chai:latest-gpu` (Chai-Lab + CUDA 12.1) |

### Build Metadata

```bash
# Verify image metadata
docker inspect dxkb/chai-bvbrc:latest-gpu --format '
Version: {{index .Config.Labels "org.opencontainers.image.version"}}
Git Commit: {{index .Config.Labels "org.opencontainers.image.revision"}}
Build Date: {{index .Config.Labels "build.date"}}'

# Expected output:
# Version: 2.1.0
# Git Commit: f9596026c544d5a2af2ac718fd9919821421c3a7
# Build Date: 2026-01-20T18:56:04Z
```

### Container Build Info File

```bash
docker run --rm dxkb/chai-bvbrc:latest-gpu cat /kb/module/BUILD_INFO

# Expected output:
# BUILD_DATE=2026-01-20T18:56:04Z
# GIT_COMMIT=f9596026c544d5a2af2ac718fd9919821421c3a7
# GIT_BRANCH=main
# VERSION=2.1.0
```

---

## Apptainer/Singularity Deployment

### Build Apptainer Image

```bash
# From Docker image
singularity build chai-lab-bvbrc.sif docker://dxkb/chai-bvbrc:latest-gpu

# Or from definition file
singularity build chai-lab-bvbrc.sif container/chai-lab-bvbrc.def
```

### Apptainer Definition File

**Location:** `container/chai-lab-bvbrc.def`

```singularity
Bootstrap: docker
From: dxkb/chai-bvbrc:latest-gpu

%labels
    Author BV-BRC Team
    Version 2.1.0
    Application ChaiLab

%test
    # Verify Perl runtime
    /opt/patric-common/runtime/bin/perl -e 'print "Perl OK\n"'

    # Verify service script
    /opt/patric-common/runtime/bin/perl -c /kb/module/service-scripts/App-ChaiLab.pl

    # Verify chai-lab
    chai-lab --help > /dev/null && echo "chai-lab OK"
```

---

## Infrastructure Requirements

### GPU Nodes

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| GPU Type | NVIDIA A100 (40GB) | NVIDIA H100 (80GB) |
| GPU Count | 1 per job | 1 per job |
| CUDA Driver | 525+ | 535+ |
| CUDA Toolkit | 12.1 | 12.1+ |

### Node Resources

| Resource | Per Job |
|----------|---------|
| CPU Cores | 8 |
| RAM | 64GB (up to 96GB for large inputs) |
| Local Disk | 50GB scratch |
| Network | Required (MSA server access) |

### Network Access

The application requires outbound HTTPS access to:

| Service | URL | Purpose |
|---------|-----|---------|
| ColabFold MSA | `https://api.colabfold.com` | MSA generation |
| ColabFold Templates | `https://api.colabfold.com` | Template search |
| RCSB PDB | `https://files.rcsb.org` | Template download |

---

## Service Script

### Location

```
/kb/module/service-scripts/App-ChaiLab.pl
```

### Execution

```bash
# Via Docker
docker run --gpus all \
  -v /data:/data \
  -v /output:/output \
  dxkb/chai-bvbrc:latest-gpu \
  App-ChaiLab /path/to/params.json

# Via Apptainer
singularity run --nv \
  --bind /data:/data \
  --bind /output:/output \
  chai-lab-bvbrc.sif \
  App-ChaiLab /path/to/params.json
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CHAI_DOWNLOADS_DIR` | `/cache` | Model weights cache |
| `TMPDIR` | `/tmp` | Scratch directory |
| `RT` | `/opt/patric-common/runtime` | BV-BRC Perl runtime |
| `KB_DEPLOYMENT` | `/opt/patric-common/deployment` | BV-BRC deployment |

---

## App Specification

### Location

```
app_specs/ChaiLab.json
```

### Deployment

Copy to the app service specs directory:

```bash
cp app_specs/ChaiLab.json $TARGET/services/app_service/app_specs/
```

### Preflight Resources

```json
{
    "preflight": {
        "cpu": 8,
        "memory": "64G",
        "runtime": 7200,
        "storage": "50G",
        "policy": {
            "gpu": 1,
            "gpu_type": "a100"
        }
    }
}
```

---

## Test Verification

### Quick Smoke Test

```bash
# 1. Verify entrypoint
docker run --rm dxkb/chai-bvbrc:latest-gpu chai-lab --help

# 2. Verify service script syntax
docker run --rm dxkb/chai-bvbrc:latest-gpu \
  perl -c /kb/module/service-scripts/App-ChaiLab.pl

# 3. Verify BV-BRC modules
docker run --rm dxkb/chai-bvbrc:latest-gpu \
  perl -e 'use Bio::KBase::AppService::AppScript; print "OK\n"'
```

### GPU Validation Test

```bash
# Create test directory
mkdir -p test_data output cache tests

# Copy test data from repository
# test_data/simple_protein.fasta
# tests/params.json

# Run prediction
docker run --gpus all \
  -v $(pwd)/test_data:/data \
  -v $(pwd)/output:/output \
  -v $(pwd)/cache:/cache \
  -v $(pwd)/tests:/tests \
  -e CHAI_DOWNLOADS_DIR=/cache \
  dxkb/chai-bvbrc:latest-gpu \
  App-ChaiLab /tests/params.json

# Validate output
ls -la output/
# Expected: pred.model_idx_0.cif, scores.json
```

### Full Acceptance Test Suite

**Location:** `tests/`

| Test | File | Expected |
|------|------|----------|
| 1. Syntax | N/A | `syntax OK` |
| 2. Simple protein | `params_ws.json` | CIF output |
| 3. Protein-ligand | `params_ws_ligand.json` | CIF with ligand |
| 4. Multimer | `params_ws_multimer.json` | Multi-chain CIF |
| 5. Templates | `params_ws_templates.json` | CIF output |
| 6. Multi-sample | `params_ws_multisamples.json` | 3 CIF files |
| 7. Error handling | `params_missing_input.json` | Error message |

---

## Test Data

### Repository Location

```
https://github.com/wilke/ChaiApp
```

### Test Data Files

| File | Path | Description |
|------|------|-------------|
| Simple protein | `test_data/simple_protein.fasta` | 384-residue protein |
| Multimer | `test_data/multimer.fasta` | 2-chain homodimer |
| Protein-ligand | `test_data/protein_ligand.fasta` | Protein + SMILES ligand |
| Constraints | `test_data/constraints.json` | Pocket restraints |

### Test Parameter Files

| File | Path | Description |
|------|------|-------------|
| Basic | `tests/params_ws.json` | Minimal parameters |
| Ligand | `tests/params_ws_ligand.json` | With constraints |
| Multimer | `tests/params_ws_multimer.json` | Multi-chain |
| Samples | `tests/params_ws_multisamples.json` | 3 samples |
| Templates | `tests/params_ws_templates.json` | With templates |
| Dry run | `tests/params_ws_dry_run.json` | No GPU needed |
| Error | `tests/params_missing_input.json` | Error test |

### Example params.json

```json
{
    "input_file": "/data/simple_protein.fasta",
    "output_path": "/output",
    "use_msa_server": true,
    "use_templates_server": false,
    "num_samples": 1
}
```

---

## Monitoring

### Health Checks

```bash
# Container health
docker run --rm dxkb/chai-bvbrc:latest-gpu cat /kb/module/BUILD_INFO

# GPU availability
docker run --rm --gpus all dxkb/chai-bvbrc:latest-gpu nvidia-smi

# Service script check
docker run --rm dxkb/chai-bvbrc:latest-gpu \
  perl -c /kb/module/service-scripts/App-ChaiLab.pl
```

### Logging

The service script outputs progress to stdout:

```
Starting Chai-1 structure prediction
Parameters: { ... }
Downloading input file: /workspace/user/input.fasta
Found 2 sequence(s) in input file
  - protein|A
  - ligand|L
Executing: chai-lab fold /tmp/input/input.fasta /tmp/output --use-msa-server --num-diffn-samples 1
...
Chai-lab prediction completed successfully
Uploading results to workspace: /workspace/user/output/
Chai-lab job completed
```

### Resource Monitoring

Key metrics to track:

| Metric | Typical Value | Alert Threshold |
|--------|---------------|-----------------|
| GPU Memory | 30-60GB | >75GB |
| GPU Utilization | 80-95% | <20% (stuck) |
| Runtime | 30-120 min | >4 hours |
| Output Size | 1-20MB | >100MB |

---

## Troubleshooting

### Common Issues

#### 1. GPU Not Detected

```bash
# Check NVIDIA driver
nvidia-smi

# Check Docker GPU support
docker run --rm --gpus all nvidia/cuda:12.1-base nvidia-smi
```

#### 2. MSA Server Timeout

```
Error: MSA server unreachable
```

- Check network connectivity to `api.colabfold.com`
- Retry job (transient failure)
- Consider using pre-computed MSAs

#### 3. Out of Memory

```
RuntimeError: CUDA out of memory
```

- Reduce input size
- Reduce `num_samples`
- Use larger GPU (H100 80GB)

#### 4. Output Directory Not Empty

```
Error: Output directory is not empty
```

- Service script now auto-cleans output directory
- Check TMPDIR permissions

---

## Rollback Procedure

If issues are found with `latest-gpu`:

```bash
# Revert to previous version
docker tag dxkb/chai-bvbrc:20260113-<commit> dxkb/chai-bvbrc:latest-gpu
docker push dxkb/chai-bvbrc:latest-gpu
```

Previous known-good versions:
- `dxkb/chai-bvbrc:20260120-f959602` (current)

---

## Related Documentation

| Document | Description |
|----------|-------------|
| `docs/RUNTIME_METRICS.md` | Resource requirements |
| `docs/HANDOFF_UI_TEAM.md` | UI integration guide |
| `docs/ACCEPTANCE_TESTING.md` | Test procedures |
| `docs/GPU_ACCEPTANCE_TEST_INSTRUCTIONS.md` | GPU test guide |

---

## Support

- **Repository:** https://github.com/wilke/ChaiApp
- **Issues:** https://github.com/wilke/ChaiApp/issues
- **Container:** https://hub.docker.com/r/dxkb/chai-bvbrc
