# Chai-Lab Performance Benchmark

This directory contains scripts for benchmarking the Chai-Lab Apptainer image to measure runtime, memory, and disk usage across different input sizes.

## Quick Start

```bash
# 1. Generate test sequences
python3 test_sequences.py -o ./input

# 2. Run benchmarks (requires GPU)
chmod +x benchmark_chai.sh
./benchmark_chai.sh

# 3. Analyze results
python3 analyze_results.py benchmark_results.csv
```

## Files

- `test_sequences.py` - Generates FASTA test files with various sequence lengths and batch sizes
- `benchmark_chai.sh` - Main benchmark script that runs Chai-Lab and collects metrics
- `analyze_results.py` - Analyzes benchmark results and generates performance report

## Test Cases

### Single Chain Tests
| Test Name | Residues | Description |
|-----------|----------|-------------|
| single_50aa | 50 | Small peptide |
| single_100aa | 100 | Small protein domain |
| single_200aa | 200 | Typical domain |
| single_300aa | 300 | Medium protein |
| single_500aa | 500 | Large protein |
| single_750aa | 750 | Very large protein |
| single_1000aa | 1000 | Maximum single chain |

### Multi-Chain Tests
| Test Name | Chains | Total Residues | Description |
|-----------|--------|----------------|-------------|
| 2chain_small | 2 | 200 | Small homodimer |
| 2chain_medium | 2 | 400 | Medium homodimer |
| 2chain_large | 2 | 600 | Large homodimer |
| 3chain_small | 3 | 300 | Trimer |
| 4chain_small | 4 | 400 | Tetramer |
| 5chain_small | 5 | 400 | Pentamer |
| heterodimer | 2 | 400 | Different sized chains |
| complex_3chain | 3 | 450 | Heterotrimeric complex |

## Benchmark Options

```bash
./benchmark_chai.sh --help

Options:
  -i, --image PATH      Path to Chai Apptainer image
  -d, --data-dir PATH   Directory containing test FASTA files
  -o, --output PATH     Output directory for results
  -r, --results PATH    Results CSV file
  -s, --samples N       Number of diffusion samples (default: 1)
  -n, --dry-run         Show commands without executing
  --gpu-id ID           GPU device to use
  --skip-existing       Skip tests with existing output
```

## Metrics Collected

| Metric | Description | Source |
|--------|-------------|--------|
| wall_time_sec | Total elapsed time | Measured |
| user_time_sec | CPU time in user mode | GNU time |
| sys_time_sec | CPU time in kernel mode | GNU time |
| peak_memory_kb | Maximum resident set size | GNU time |
| output_size_kb | Disk space used by output | du |

## Output Format

Results are saved in CSV format with columns:
```
test_name,fasta_file,num_chains,total_residues,num_samples,wall_time_sec,user_time_sec,sys_time_sec,peak_memory_kb,exit_code,output_size_kb,timestamp
```

## Resource Estimation

Based on benchmarks, expected resource requirements:

| Input Size | Memory (GB) | Runtime | GPU |
|------------|-------------|---------|-----|
| <200 residues | 32 | 30 min | A10/RTX 4090 |
| 200-500 residues | 64 | 1 hour | A100 40GB |
| 500-1000 residues | 96 | 2 hours | A100 80GB |
| >1000 residues | 128+ | 4+ hours | A100 80GB |

Note: These are estimates. Actual requirements depend on sequence composition, MSA/template usage, and number of diffusion samples.
