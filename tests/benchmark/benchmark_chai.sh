#!/bin/bash
#
# Chai-Lab Performance Benchmark Script
#
# Measures runtime, peak memory, and disk usage for protein structure predictions
# across different input sizes (sequence length and number of chains).
#
# Usage:
#   ./benchmark_chai.sh [options]
#
# Options:
#   -i, --image PATH      Path to Chai Apptainer image (default: ~/images/chai_latest-gpu.sif)
#   -d, --data-dir PATH   Directory containing test FASTA files (default: ./input)
#   -o, --output PATH     Output directory for results (default: ./output)
#   -r, --results PATH    Results CSV file (default: ./benchmark_results.csv)
#   -s, --samples N       Number of diffusion samples (default: 1, for faster benchmarks)
#   -n, --dry-run         Show what would be run without executing
#   --gpu-id ID           GPU device ID to use (default: 0)
#   --skip-existing       Skip tests that already have output
#   --cache-dir PATH      Cache directory for model weights (default: ./cache)
#

set -euo pipefail

# Default configuration
CHAI_IMAGE="${CHAI_IMAGE:-/homes/wilke/images/chai_latest-gpu.sif}"
DATA_DIR="./input"
OUTPUT_DIR="./output"
RESULTS_FILE="./benchmark_results.csv"
NUM_SAMPLES=1
DRY_RUN=false
GPU_ID=0
SKIP_EXISTING=false
CACHE_DIR="./cache"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--image)
            CHAI_IMAGE="$2"
            shift 2
            ;;
        -d|--data-dir)
            DATA_DIR="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -r|--results)
            RESULTS_FILE="$2"
            shift 2
            ;;
        -s|--samples)
            NUM_SAMPLES="$2"
            shift 2
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --gpu-id)
            GPU_ID="$2"
            shift 2
            ;;
        --skip-existing)
            SKIP_EXISTING=true
            shift
            ;;
        --cache-dir)
            CACHE_DIR="$2"
            shift 2
            ;;
        -h|--help)
            head -30 "$0" | tail -n +2 | sed 's/^# //' | sed 's/^#//'
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate environment
if [[ ! -f "$CHAI_IMAGE" ]]; then
    echo "ERROR: Chai image not found: $CHAI_IMAGE"
    exit 1
fi

if [[ ! -d "$DATA_DIR" ]]; then
    echo "ERROR: Data directory not found: $DATA_DIR"
    echo "Run: python3 test_sequences.py -o $DATA_DIR"
    exit 1
fi

# Check for GPU
if ! command -v nvidia-smi &> /dev/null; then
    echo "WARNING: nvidia-smi not found. GPU metrics will not be available."
fi

# Create output directories
mkdir -p "$OUTPUT_DIR"
mkdir -p "$(dirname "$RESULTS_FILE")"
mkdir -p "$CACHE_DIR"

# Convert directories to absolute paths
CACHE_DIR=$(cd "$CACHE_DIR" && pwd)
DATA_DIR=$(cd "$DATA_DIR" && pwd)
OUTPUT_DIR=$(cd "$OUTPUT_DIR" && pwd)

# Initialize results file
if [[ ! -f "$RESULTS_FILE" ]]; then
    echo "test_name,fasta_file,num_chains,total_residues,num_samples,wall_time_sec,user_time_sec,sys_time_sec,peak_memory_kb,exit_code,output_size_kb,timestamp" > "$RESULTS_FILE"
fi

# Function to get file stats
get_fasta_stats() {
    local fasta_file="$1"
    local num_chains=$(grep -c "^>" "$fasta_file" 2>/dev/null || echo 0)
    local total_residues=$(grep -v "^>" "$fasta_file" | tr -d '\n\r ' | wc -c)
    echo "$num_chains,$total_residues"
}

# Function to get directory size in KB
get_dir_size() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        du -sk "$dir" 2>/dev/null | cut -f1
    else
        echo 0
    fi
}

# Function to run benchmark
run_benchmark() {
    local test_name="$1"
    local fasta_file="$2"
    local output_subdir="$OUTPUT_DIR/$test_name"

    # Get FASTA stats
    local stats=$(get_fasta_stats "$fasta_file")
    local num_chains=$(echo "$stats" | cut -d, -f1)
    local total_residues=$(echo "$stats" | cut -d, -f2)

    echo "========================================"
    echo "Test: $test_name"
    echo "  File: $fasta_file"
    echo "  Chains: $num_chains, Residues: $total_residues"
    echo "  Samples: $NUM_SAMPLES"
    echo "========================================"

    # Check if we should skip
    if [[ "$SKIP_EXISTING" == "true" && -d "$output_subdir" ]]; then
        echo "  Skipping (output exists)"
        return 0
    fi

    # Create output directory
    rm -rf "$output_subdir"
    mkdir -p "$output_subdir"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [DRY RUN] Would execute:"
        echo "    apptainer exec --nv $CHAI_IMAGE chai-lab fold $fasta_file $output_subdir --num-diffn-samples $NUM_SAMPLES"
        return 0
    fi

    # Build command
    local cmd="apptainer exec --nv"
    cmd+=" --bind $(dirname "$fasta_file"):$(dirname "$fasta_file"):ro"
    cmd+=" --bind $output_subdir:$output_subdir"
    cmd+=" --bind $CACHE_DIR:/opt/chai-lab/downloads"
    cmd+=" $CHAI_IMAGE"
    cmd+=" chai-lab fold"
    cmd+=" $fasta_file"
    cmd+=" $output_subdir"
    cmd+=" --num-diffn-samples $NUM_SAMPLES"
    cmd+=" --no-use-msa-server"
    cmd+=" --device cuda:$GPU_ID"

    echo "  Command: $cmd"

    # Run with time measurement
    local time_output
    local exit_code=0
    local start_time=$(date +%s.%N)

    # Use GNU time for detailed metrics
    time_output=$(/usr/bin/time -v bash -c "$cmd" 2>&1) || exit_code=$?

    local end_time=$(date +%s.%N)
    local wall_time=$(echo "$end_time - $start_time" | bc)

    # Parse time output
    local user_time=$(echo "$time_output" | grep "User time" | awk '{print $NF}')
    local sys_time=$(echo "$time_output" | grep "System time" | awk '{print $NF}')
    local peak_memory=$(echo "$time_output" | grep "Maximum resident set size" | awk '{print $NF}')

    # Get output size
    local output_size=$(get_dir_size "$output_subdir")

    # Get timestamp
    local timestamp=$(date -Iseconds)

    # Log results
    echo "  Results:"
    echo "    Exit code: $exit_code"
    echo "    Wall time: ${wall_time}s"
    echo "    User time: ${user_time}s"
    echo "    Sys time: ${sys_time}s"
    echo "    Peak memory: ${peak_memory} KB"
    echo "    Output size: ${output_size} KB"

    # Append to CSV
    echo "$test_name,$(basename "$fasta_file"),$num_chains,$total_residues,$NUM_SAMPLES,$wall_time,$user_time,$sys_time,$peak_memory,$exit_code,$output_size,$timestamp" >> "$RESULTS_FILE"

    return $exit_code
}

# Main benchmark loop
echo "Chai-Lab Performance Benchmark"
echo "=============================="
echo "Image: $CHAI_IMAGE"
echo "Data directory: $DATA_DIR"
echo "Output directory: $OUTPUT_DIR"
echo "Results file: $RESULTS_FILE"
echo "Samples per prediction: $NUM_SAMPLES"
echo "Cache directory: $CACHE_DIR"
echo ""

# Check for manifest or find FASTA files
if [[ -f "$DATA_DIR/test_manifest.txt" ]]; then
    echo "Using test manifest..."
    while IFS=$'\t' read -r name file num_chains total_residues description; do
        # Skip comments and header
        [[ "$name" =~ ^# ]] && continue
        [[ "$name" == "name" ]] && continue

        fasta_path="$DATA_DIR/$file"
        if [[ -f "$fasta_path" ]]; then
            run_benchmark "$name" "$fasta_path" || true
        else
            echo "WARNING: File not found: $fasta_path"
        fi
    done < "$DATA_DIR/test_manifest.txt"
else
    echo "No manifest found, processing all FASTA files..."
    for fasta in "$DATA_DIR"/*.fasta "$DATA_DIR"/*.fa; do
        [[ -f "$fasta" ]] || continue
        test_name=$(basename "$fasta" | sed 's/\.\(fasta\|fa\)$//')
        run_benchmark "$test_name" "$fasta" || true
    done
fi

echo ""
echo "=============================="
echo "Benchmark complete!"
echo "Results saved to: $RESULTS_FILE"

# Summary statistics
echo ""
echo "Summary:"
if command -v column &> /dev/null; then
    tail -n +2 "$RESULTS_FILE" | column -t -s,
else
    cat "$RESULTS_FILE"
fi
