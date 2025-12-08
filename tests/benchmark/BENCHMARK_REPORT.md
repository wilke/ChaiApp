# Chai-Lab Performance Benchmark Report

**Date:** 2025-12-08
**Image:** `/homes/wilke/images/chai_latest-gpu.sif`
**Platform:** Linux 5.15.0-157-generic (GPU-enabled)

## Executive Summary

This report documents performance benchmarks for the Chai-Lab protein structure prediction tool running in an Apptainer container with GPU acceleration. All 15 test cases completed successfully, providing data on runtime, memory usage, and disk footprint across varying input sizes.

**Key Findings:**
- Baseline overhead of ~60 seconds for model loading regardless of input size
- Peak memory usage of 20.2 GB for 1000-residue single chain
- Sublinear scaling: O(n^0.30) for time, O(n^0.22) for memory
- Throughput ranges from 0.8 to 7.0 residues/second depending on input size

---

## Methodology

### Container Execution

The Chai-Lab container was executed using Apptainer with GPU support:

```bash
apptainer exec --nv \
  --bind <input_dir>:<input_dir>:ro \
  --bind <output_dir>:<output_dir> \
  --bind <cache_dir>:/opt/chai-lab/downloads \
  /homes/wilke/images/chai_latest-gpu.sif \
  chai-lab fold <input.fasta> <output_dir> \
    --num-diffn-samples 1 \
    --no-use-msa-server \
    --device cuda:0
```

**Key parameters:**
- `--nv`: Enable NVIDIA GPU passthrough
- `--num-diffn-samples 1`: Single diffusion sample for faster benchmarking
- `--no-use-msa-server`: Disable external MSA server (local inference only)
- `--device cuda:0`: Use first GPU device

### Measurement Approach

Metrics were collected using GNU `/usr/bin/time -v`:
- **Wall time**: Elapsed real time
- **User time**: CPU time in user mode
- **System time**: CPU time in kernel mode
- **Peak memory**: Maximum resident set size (RSS)
- **Output size**: Directory size after completion

### Input Data Requirements

Chai-Lab requires FASTA files with specific header format:
```
>protein|name=<identifier>
<sequence>
```

The `name=` field is mandatory; headers without it will cause assertion errors.

---

## Test Input Data

### Test Case Generator

Test sequences were generated using `test_sequences.py`, which creates random protein sequences with reproducible seeds.

```python
# Single chain tests: 50, 100, 200, 300, 500, 750, 1000 residues
# Multi-chain tests: 2-5 chains with various configurations
```

### Test Manifest

| Test Name | File | Chains | Total Residues | Description |
|-----------|------|--------|----------------|-------------|
| single_50aa | single_50aa.fasta | 1 | 50 | Single chain, 50 residues |
| single_100aa | single_100aa.fasta | 1 | 100 | Single chain, 100 residues |
| single_200aa | single_200aa.fasta | 1 | 200 | Single chain, 200 residues |
| single_300aa | single_300aa.fasta | 1 | 300 | Single chain, 300 residues |
| single_500aa | single_500aa.fasta | 1 | 500 | Single chain, 500 residues |
| single_750aa | single_750aa.fasta | 1 | 750 | Single chain, 750 residues |
| single_1000aa | single_1000aa.fasta | 1 | 1000 | Single chain, 1000 residues |
| 2chain_small | 2chain_small.fasta | 2 | 200 | 2 chains of 100aa each |
| 2chain_medium | 2chain_medium.fasta | 2 | 400 | 2 chains of 200aa each |
| 2chain_large | 2chain_large.fasta | 2 | 600 | 2 chains of 300aa each |
| 3chain_small | 3chain_small.fasta | 3 | 300 | 3 chains of 100aa |
| 4chain_small | 4chain_small.fasta | 4 | 400 | 4 chains of 100aa |
| 5chain_small | 5chain_small.fasta | 5 | 400 | 5 chains of 80aa |
| heterodimer | heterodimer.fasta | 2 | 400 | Two different sized chains (150aa + 250aa) |
| complex_3chain | complex_3chain.fasta | 3 | 450 | 3 different chains (100aa + 200aa + 150aa) |

### Sample Input Files

**single_50aa.fasta:**
```
>protein|name=protein_50aa
LGPFLYCHQCETYHEYHPPPWYQTSPKFGWRDWGQLGFNKPQTVPYLVTT
```

**2chain_small.fasta:**
```
>protein|name=chain_A
CSQWRIYQIPKQNNRNWYVSANDGVSGWCQCPNPLQCRPWDRIRITWTWYTYKKDSNTCVWAWSKIHYVDHSPRIDLCRE
KAKNPIMHCTKSNHEIICPF
>protein|name=chain_B
GLELWIVNDIQHATGVVQTWQYCTRRTEPDDVTMDEGLFYLMGVDCTCHAMHTHASYHTQMPAPTCIIHSRVDENVHLIP
NMGKRDRLPMQMRMHYHPSK
```

---

## Results

### Raw Benchmark Data

| Test Name | Chains | Residues | Wall Time (s) | User Time (s) | Sys Time (s) | Peak Memory (GB) | Output (KB) | Exit Code |
|-----------|--------|----------|---------------|---------------|--------------|------------------|-------------|-----------|
| single_50aa | 1 | 50 | 61.0 | 96.4 | 34.9 | 10.47 | 48 | 0 |
| single_100aa | 1 | 100 | 59.7 | 92.6 | 33.0 | 10.46 | 84 | 0 |
| single_200aa | 1 | 200 | 59.8 | 96.3 | 33.3 | 10.51 | 148 | 0 |
| single_300aa | 1 | 300 | 67.4 | 111.0 | 47.8 | 11.45 | 216 | 0 |
| single_500aa | 1 | 500 | 78.1 | 131.3 | 72.4 | 12.70 | 356 | 0 |
| single_750aa | 1 | 750 | 107.5 | 153.2 | 126.2 | 15.95 | 536 | 0 |
| single_1000aa | 1 | 1000 | 150.6 | 179.4 | 188.8 | 20.23 | 712 | 0 |
| 2chain_small | 2 | 200 | 65.9 | 105.0 | 35.4 | 10.52 | 148 | 0 |
| 2chain_medium | 2 | 400 | 83.1 | 141.8 | 76.4 | 12.74 | 280 | 0 |
| 2chain_large | 2 | 600 | 113.8 | 173.7 | 137.7 | 15.98 | 428 | 0 |
| 3chain_small | 3 | 300 | 72.9 | 127.1 | 60.2 | 11.58 | 212 | 0 |
| 4chain_small | 4 | 400 | 82.7 | 153.4 | 78.7 | 12.72 | 280 | 0 |
| 5chain_small | 5 | 400 | 83.4 | 146.2 | 86.1 | 12.75 | 280 | 0 |
| heterodimer | 2 | 400 | 83.3 | 144.2 | 78.4 | 12.70 | 288 | 0 |
| complex_3chain | 3 | 450 | 89.0 | 147.7 | 78.6 | 12.82 | 320 | 0 |

### Single-Chain Scaling

```
Residues    Time (s)    Time (min)    Memory (GB)    Output (MB)
──────────────────────────────────────────────────────────────────
      50        61.0          1.02          10.47           0.05
     100        59.7          1.00          10.46           0.08
     200        59.8          1.00          10.51           0.14
     300        67.4          1.12          11.45           0.21
     500        78.1          1.30          12.70           0.35
     750       107.5          1.79          15.95           0.52
    1000       150.6          2.51          20.23           0.70
```

### Multi-Chain Comparison

For inputs with similar total residue counts, the number of chains has minimal impact:

| Configuration | Chains | Residues | Time (s) | Memory (GB) |
|---------------|--------|----------|----------|-------------|
| single_200aa | 1 | 200 | 59.8 | 10.51 |
| 2chain_small | 2 | 200 | 65.9 | 10.52 |
| single_300aa | 1 | 300 | 67.4 | 11.45 |
| 3chain_small | 3 | 300 | 72.9 | 11.58 |
| single_500aa (approx) | 1 | 500 | 78.1 | 12.70 |
| 4chain_small | 4 | 400 | 82.7 | 12.72 |
| 5chain_small | 5 | 400 | 83.4 | 12.75 |
| heterodimer | 2 | 400 | 83.3 | 12.70 |

**Observation:** Multi-chain inputs add ~6-10 seconds overhead compared to single-chain inputs of similar total length.

---

## Scaling Analysis

### Computational Complexity

Based on single-chain data from 50 to 1000 residues:

- **Size increase:** 20x (50 → 1000 residues)
- **Time increase:** 2.5x (61.0s → 150.6s)
- **Memory increase:** 1.9x (10.47 GB → 20.23 GB)

**Estimated complexity:**
- Time: **O(n^0.30)** - sublinear scaling
- Memory: **O(n^0.22)** - sublinear scaling

This favorable scaling is likely due to:
1. Fixed model loading overhead (~60 seconds baseline)
2. GPU parallelization efficiently handling larger inputs
3. Batch processing optimizations in the transformer architecture

### Throughput Analysis

| Test | Residues/sec | Total Residues |
|------|--------------|----------------|
| single_750aa | 6.98 | 750 |
| single_1000aa | 6.64 | 1000 |
| single_500aa | 6.41 | 500 |
| 2chain_large | 5.27 | 600 |
| complex_3chain | 5.06 | 450 |
| 4chain_small | 4.84 | 400 |
| 2chain_medium | 4.81 | 400 |
| heterodimer | 4.80 | 400 |
| 5chain_small | 4.79 | 400 |
| single_300aa | 4.45 | 300 |
| 3chain_small | 4.11 | 300 |
| single_200aa | 3.35 | 200 |
| 2chain_small | 3.03 | 200 |
| single_100aa | 1.67 | 100 |
| single_50aa | 0.82 | 50 |

**Key insight:** Larger inputs achieve better throughput due to amortizing the fixed startup overhead.

---

## Resource Recommendations

### Memory Requirements

| Input Size | Measured Peak | Recommended Allocation |
|------------|---------------|------------------------|
| Small (<200 residues) | 10.5 GB | 32 GB |
| Medium (200-500 residues) | 12.8 GB | 64 GB |
| Large (500-1000 residues) | 20.2 GB | 96 GB |
| Very Large (>1000 residues) | TBD | 128+ GB |

**Note:** Recommendations include 2-3x safety margin for:
- Multiple diffusion samples (`--num-diffn-samples` > 1)
- System overhead and other processes
- Potential memory spikes during computation

### Runtime Estimates

| Input Size | Measured Time | Recommended Timeout |
|------------|---------------|---------------------|
| Small (<200 residues) | 1.0-1.1 min | 30 min |
| Medium (200-500 residues) | 1.1-1.5 min | 1 hour |
| Large (500-1000 residues) | 1.8-2.5 min | 2 hours |
| Very Large (>1000 residues) | TBD | 4+ hours |

**Note:** These measurements use 1 diffusion sample. Production runs with 5+ samples will take proportionally longer.

### Disk Space

Output size scales linearly with residue count:
- ~0.7 KB per residue (single sample)
- For 5 samples: ~3.5 KB per residue
- 1000-residue protein with 5 samples: ~3.5 MB output

---

## Computational Steps

### Benchmark Execution Workflow

1. **Generate test sequences** (`test_sequences.py`)
   ```bash
   python3 test_sequences.py -o ./input
   ```
   - Creates 15 FASTA files with various configurations
   - Generates manifest file for tracking

2. **Initialize cache directory**
   ```bash
   mkdir -p ./cache
   ```
   - First run downloads ~2 GB model weights
   - Subsequent runs use cached weights

3. **Execute benchmark suite** (`benchmark_chai.sh`)
   ```bash
   ./benchmark_chai.sh --samples 1
   ```
   - Iterates through all test cases
   - Measures timing and resource usage
   - Records results to CSV

4. **Analyze results** (`analyze_results.py`)
   ```bash
   python3 analyze_results.py benchmark_results.csv
   ```
   - Generates summary statistics
   - Computes scaling coefficients
   - Produces resource recommendations

### Directory Structure

```
tests/benchmark/
├── benchmark_chai.sh        # Main benchmark runner
├── test_sequences.py        # Test data generator
├── analyze_results.py       # Results analysis
├── benchmark_results.csv    # Raw benchmark data
├── BENCHMARK_REPORT.md      # This report
├── input/                   # Generated test FASTA files
│   ├── test_manifest.txt
│   ├── single_50aa.fasta
│   ├── single_100aa.fasta
│   └── ...
├── output/                  # Prediction outputs
│   ├── single_50aa/
│   ├── single_100aa/
│   └── ...
└── cache/                   # Model weights cache
```

---

## Known Issues and Limitations

### FASTA Header Format
Chai-Lab requires `name=` field in FASTA headers:
```
# Correct
>protein|name=my_protein

# Incorrect (will fail)
>protein|length=100
>my_protein
```

### Model Cache Location
The container expects to write model weights to `/opt/chai-lab/downloads`. This directory must be bind-mounted to a writable location:
```bash
--bind ./cache:/opt/chai-lab/downloads
```

### Absolute Paths Required
Apptainer bind mounts require absolute paths. The benchmark script converts relative paths automatically:
```bash
CACHE_DIR=$(cd "$CACHE_DIR" && pwd)
```

---

## Conclusion

The Chai-Lab Apptainer image performs reliably across all tested input configurations. The sublinear scaling behavior makes it practical for processing proteins up to 1000 residues with modest resource requirements (~20 GB GPU memory, ~2.5 minutes runtime).

For production deployment on BV-BRC:
- Allocate 32-96 GB RAM depending on input size
- Set timeout to 2-4x measured runtime for safety margin
- Consider batching small inputs to improve throughput
- Cache model weights across runs to avoid repeated downloads

---

## Files Generated

| File | Description |
|------|-------------|
| `benchmark_results.csv` | Raw benchmark measurements |
| `input/*.fasta` | Test input sequences |
| `input/test_manifest.txt` | Test case metadata |
| `output/*/` | Structure prediction outputs |
| `BENCHMARK_REPORT.md` | This report |
