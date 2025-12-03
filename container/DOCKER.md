# Docker Usage Guide for Chai-Lab

This guide explains how to use Chai-Lab with Docker for containerized molecular structure prediction.

## Quick Start

### Building the Image

**For GPU (CUDA) support:**
```bash
# Standard build
docker build --platform linux/amd64 -t dxkb/chai:latest-gpu -f Dockerfile.cuda .
```

### Using Docker Compose

```bash
docker-compose up chai-gpu
```

## Running Predictions

### Basic Usage

Place your input FASTA files in a `./data` directory, then run:

```bash
docker run --gpus all \
  -v $(pwd)/data:/data \
  -v $(pwd)/output:/output \
  -v chai-cache:/cache \
  dxkb/chai:latest-gpu \
  chai-lab fold /data/input.fasta /output --use-msa-server
```

### With MSA and Templates

```bash
docker run --gpus all \
  -v $(pwd)/data:/data \
  -v $(pwd)/output:/output \
  -v chai-cache:/cache \
  dxkb/chai:latest-gpu \
  chai-lab fold /data/input.fasta /output \
    --use-msa-server \
    --use-templates-server
```

### Persistent Cache

The Docker setup uses a named volume `chai-cache` to persist downloaded model weights between runs. This avoids re-downloading the ~5GB model files.

To clear the cache:
```bash
docker volume rm chai-cache
```

## Advanced Options

### Interactive Mode

Run an interactive shell inside the container:
```bash
docker run -it --gpus all \
  -v $(pwd)/data:/data \
  -v $(pwd)/output:/output \
  --entrypoint /bin/bash \
  dxkb/chai:latest-gpu
```

Then inside the container:
```bash
chai-lab fold /data/input.fasta /output --use-msa-server
```

### Multiple Samples

Generate multiple structure predictions:
```bash
docker run --gpus all \
  -v $(pwd)/data:/data \
  -v $(pwd)/output:/output \
  dxkb/chai:latest-gpu \
  chai-lab fold /data/input.fasta /output \
    --use-msa-server \
    --num-samples 5
```

## Volume Mounts

The Docker setup expects the following directories:

- `/data` - Input files (FASTA, constraints JSON)
- `/output` - Prediction outputs (CIF/PDB structures, scores)
- `/cache` - Model weights cache (persisted via volume)

## Resource Requirements

| GPU | Memory | Recommended For |
|-----|--------|-----------------|
| A100 80GB | 64GB+ | Large complexes, multiple chains |
| A100 40GB | 48GB+ | Medium complexes |
| A10/A30 | 32GB+ | Small proteins |
| RTX 4090 | 24GB | Single chains, small complexes |

## Resource Limits

Limit GPU and memory usage:

```bash
docker run --gpus '"device=0"' \
  --memory="64g" \
  --shm-size="16g" \
  -v $(pwd)/data:/data \
  -v $(pwd)/output:/output \
  dxkb/chai:latest-gpu \
  chai-lab fold /data/input.fasta /output
```

## Troubleshooting

### GPU Not Detected

Ensure NVIDIA Container Toolkit is installed:
```bash
sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker
```

Verify GPU access:
```bash
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
```

### Out of Memory

- Reduce number of samples: `--num-samples 1`
- Use smaller sequences
- Try a GPU with more memory

### Model Download Issues

If model weights fail to download:
```bash
# Pre-download weights to cache volume
docker run --gpus all \
  -v chai-cache:/cache \
  -e CHAI_DOWNLOADS_DIR=/cache \
  dxkb/chai:latest-gpu \
  python -c "from chai_lab.chai1 import run_inference; print('Weights ready')"
```

---

## BV-BRC Integration

The `dxkb/chai-bvbrc` image includes BV-BRC AppService integration for running Chai-Lab as a BV-BRC service.

### Building the BV-BRC Image

```bash
# From the repository root
docker build --platform linux/amd64 \
  -t dxkb/chai-bvbrc:latest-gpu \
  -f container/Dockerfile.chai-bvbrc .
```

### Using Docker Compose

```bash
docker-compose up chai-bvbrc
```

### Running as BV-BRC Service

```bash
# Run the App-ChaiLab service script
docker run --gpus all \
  -v $(pwd)/data:/data \
  -v $(pwd)/output:/output \
  -e P3_AUTH_TOKEN="your-token" \
  dxkb/chai-bvbrc:latest-gpu \
  App-ChaiLab params.json

# Or run chai-lab directly
docker run --gpus all \
  -v $(pwd)/data:/data \
  -v $(pwd)/output:/output \
  dxkb/chai-bvbrc:latest-gpu \
  chai-lab fold /data/input.fasta /output --use-msa-server
```

### BV-BRC Environment Variables

The BV-BRC image sets up the following environment:

| Variable | Value | Description |
|----------|-------|-------------|
| `PERL5LIB` | `/bvbrc/modules/...` | Perl library paths for BV-BRC modules |
| `KB_TOP` | `/kb/deployment` | BV-BRC deployment directory |
| `KB_MODULE_DIR` | `/kb/module` | Module directory containing service scripts |
| `IN_BVBRC_CONTAINER` | `1` | Indicator for BV-BRC container environment |
| `CHAI_DOWNLOADS_DIR` | `/cache` | Chai-Lab model weights directory |

### Included BV-BRC Modules

- `app_service` - AppScript framework
- `Workspace` - Workspace file operations
- `p3_core` - Core BV-BRC utilities
- `p3_auth` - Authentication handling
- `seed_core` - SEED framework utilities
- `seed_gjo` - GJO utilities

---

## Apptainer/Singularity

For HPC deployment, build an Apptainer image from the Docker image.

### Building the Apptainer Image

```bash
# From Docker image
singularity build chai-lab-bvbrc.sif docker://dxkb/chai-bvbrc:latest-gpu

# Or from definition file
singularity build chai-lab-bvbrc.sif chai-lab-bvbrc.def
```

### Running with Apptainer

```bash
# Run Chai-Lab prediction
singularity run --nv chai-lab-bvbrc.sif chai-lab fold input.fasta output/ --use-msa-server

# Run as BV-BRC service
singularity run --nv chai-lab-bvbrc.sif App-ChaiLab params.json

# Interactive shell
singularity shell --nv chai-lab-bvbrc.sif

# With bind mounts for data and cache persistence
singularity run --nv \
  --bind /path/to/data:/data \
  --bind /path/to/output:/output \
  --bind /path/to/cache:/cache \
  chai-lab-bvbrc.sif chai-lab fold /data/input.fasta /output
```

### HPC Batch Job Example (Slurm)

```bash
#!/bin/bash
#SBATCH --job-name=chailab
#SBATCH --gres=gpu:a100:1
#SBATCH --mem=80G
#SBATCH --time=4:00:00

module load singularity

singularity run --nv \
  --bind $PWD/data:/data \
  --bind $PWD/output:/output \
  --bind $PWD/cache:/cache \
  /path/to/chai-lab-bvbrc.sif \
  chai-lab fold /data/input.fasta /output --use-msa-server
```
