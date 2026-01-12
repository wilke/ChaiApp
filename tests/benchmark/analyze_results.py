#!/usr/bin/env python3
"""
Analyze Chai-Lab benchmark results and generate performance report.

Produces:
- Summary statistics by input size
- Runtime scaling analysis
- Memory usage patterns
- Recommendations for resource allocation
"""

import argparse
import csv
import sys
from pathlib import Path
from dataclasses import dataclass
from typing import Optional


@dataclass
class BenchmarkResult:
    test_name: str
    fasta_file: str
    num_chains: int
    total_residues: int
    num_samples: int
    wall_time_sec: float
    user_time_sec: float
    sys_time_sec: float
    peak_memory_kb: int
    exit_code: int
    output_size_kb: int
    timestamp: str

    @property
    def success(self) -> bool:
        return self.exit_code == 0

    @property
    def peak_memory_gb(self) -> float:
        return self.peak_memory_kb / (1024 * 1024)

    @property
    def output_size_mb(self) -> float:
        return self.output_size_kb / 1024

    @property
    def wall_time_min(self) -> float:
        return self.wall_time_sec / 60

    @property
    def residues_per_second(self) -> float:
        if self.wall_time_sec > 0:
            return self.total_residues / self.wall_time_sec
        return 0


def load_results(csv_path: str) -> list[BenchmarkResult]:
    """Load benchmark results from CSV file."""
    results = []
    with open(csv_path, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                result = BenchmarkResult(
                    test_name=row['test_name'],
                    fasta_file=row['fasta_file'],
                    num_chains=int(row['num_chains']),
                    total_residues=int(row['total_residues']),
                    num_samples=int(row['num_samples']),
                    wall_time_sec=float(row['wall_time_sec']),
                    user_time_sec=float(row.get('user_time_sec', 0) or 0),
                    sys_time_sec=float(row.get('sys_time_sec', 0) or 0),
                    peak_memory_kb=int(row.get('peak_memory_kb', 0) or 0),
                    exit_code=int(row['exit_code']),
                    output_size_kb=int(row.get('output_size_kb', 0) or 0),
                    timestamp=row.get('timestamp', '')
                )
                results.append(result)
            except (KeyError, ValueError) as e:
                print(f"Warning: Skipping invalid row: {e}", file=sys.stderr)
    return results


def generate_report(results: list[BenchmarkResult], output_path: Optional[str] = None):
    """Generate performance analysis report."""
    lines = []

    def out(s=""):
        lines.append(s)

    out("=" * 70)
    out("Chai-Lab Performance Benchmark Report")
    out("=" * 70)
    out()

    # Summary
    successful = [r for r in results if r.success]
    failed = [r for r in results if not r.success]

    out(f"Total tests: {len(results)}")
    out(f"Successful: {len(successful)}")
    out(f"Failed: {len(failed)}")
    out()

    if not successful:
        out("No successful benchmarks to analyze.")
        report = "\n".join(lines)
        if output_path:
            Path(output_path).write_text(report)
        print(report)
        return

    # Performance by input size
    out("-" * 70)
    out("Performance by Input Size (Single Chain)")
    out("-" * 70)
    out(f"{'Residues':>10} {'Time (s)':>12} {'Time (min)':>12} {'Memory (GB)':>12} {'Output (MB)':>12}")
    out("-" * 70)

    single_chain = sorted([r for r in successful if r.num_chains == 1],
                          key=lambda x: x.total_residues)

    for r in single_chain:
        out(f"{r.total_residues:>10} {r.wall_time_sec:>12.1f} {r.wall_time_min:>12.2f} "
            f"{r.peak_memory_gb:>12.2f} {r.output_size_mb:>12.1f}")

    out()

    # Multi-chain performance
    multi_chain = sorted([r for r in successful if r.num_chains > 1],
                         key=lambda x: x.total_residues)

    if multi_chain:
        out("-" * 70)
        out("Performance by Input Size (Multi-Chain)")
        out("-" * 70)
        out(f"{'Test':>20} {'Chains':>8} {'Residues':>10} {'Time (s)':>12} {'Memory (GB)':>12}")
        out("-" * 70)

        for r in multi_chain:
            out(f"{r.test_name:>20} {r.num_chains:>8} {r.total_residues:>10} "
                f"{r.wall_time_sec:>12.1f} {r.peak_memory_gb:>12.2f}")

        out()

    # Scaling analysis
    out("-" * 70)
    out("Scaling Analysis")
    out("-" * 70)

    if len(single_chain) >= 2:
        # Fit approximate scaling
        residues = [r.total_residues for r in single_chain]
        times = [r.wall_time_sec for r in single_chain]
        memories = [r.peak_memory_gb for r in single_chain]

        # Simple ratio analysis
        if residues[-1] > residues[0]:
            size_ratio = residues[-1] / residues[0]
            time_ratio = times[-1] / times[0] if times[0] > 0 else 0
            mem_ratio = memories[-1] / memories[0] if memories[0] > 0 else 0

            out(f"Size increase: {size_ratio:.1f}x ({residues[0]} -> {residues[-1]} residues)")
            out(f"Time scaling: {time_ratio:.1f}x ({times[0]:.1f}s -> {times[-1]:.1f}s)")
            out(f"Memory scaling: {mem_ratio:.1f}x ({memories[0]:.2f}GB -> {memories[-1]:.2f}GB)")

            # Estimate scaling exponent
            import math
            if size_ratio > 1 and time_ratio > 0:
                time_exp = math.log(time_ratio) / math.log(size_ratio)
                out(f"Estimated time complexity: O(n^{time_exp:.2f})")
            if size_ratio > 1 and mem_ratio > 0:
                mem_exp = math.log(mem_ratio) / math.log(size_ratio)
                out(f"Estimated memory complexity: O(n^{mem_exp:.2f})")

    out()

    # Throughput analysis
    out("-" * 70)
    out("Throughput Analysis")
    out("-" * 70)

    throughputs = [(r.test_name, r.residues_per_second, r.total_residues) for r in successful]
    throughputs.sort(key=lambda x: x[1], reverse=True)

    out(f"{'Test':>25} {'Residues/sec':>15} {'Total residues':>15}")
    out("-" * 70)
    for name, tp, res in throughputs:
        out(f"{name:>25} {tp:>15.2f} {res:>15}")

    out()

    # Resource recommendations
    out("-" * 70)
    out("Resource Recommendations")
    out("-" * 70)

    # Find max memory usage and corresponding size
    max_mem_result = max(successful, key=lambda x: x.peak_memory_gb)
    max_time_result = max(successful, key=lambda x: x.wall_time_sec)

    out(f"Peak memory observed: {max_mem_result.peak_memory_gb:.2f} GB "
        f"({max_mem_result.test_name}, {max_mem_result.total_residues} residues)")
    out(f"Longest runtime: {max_time_result.wall_time_min:.1f} min "
        f"({max_time_result.test_name}, {max_time_result.total_residues} residues)")
    out()

    # Recommendations based on size categories
    out("Suggested resource allocation:")
    out()

    size_categories = [
        ("Small (<200 residues)", 200, "32 GB", "30 min"),
        ("Medium (200-500 residues)", 500, "64 GB", "1 hour"),
        ("Large (500-1000 residues)", 1000, "96 GB", "2 hours"),
        ("Very Large (>1000 residues)", float('inf'), "128+ GB", "4+ hours"),
    ]

    for category, threshold, mem, time in size_categories:
        relevant = [r for r in successful if r.total_residues <= threshold and
                   (threshold == 200 or r.total_residues > (threshold - 300 if threshold < float('inf') else 500))]
        if relevant:
            actual_max_mem = max(r.peak_memory_gb for r in relevant)
            actual_max_time = max(r.wall_time_min for r in relevant)
            out(f"  {category}:")
            out(f"    Measured: {actual_max_mem:.1f} GB RAM, {actual_max_time:.1f} min")
            out(f"    Recommended: {mem} RAM, {time} timeout")
        else:
            out(f"  {category}:")
            out(f"    No data - Recommended: {mem} RAM, {time} timeout")

    out()

    # Output
    report = "\n".join(lines)
    if output_path:
        Path(output_path).write_text(report)
        print(f"Report written to: {output_path}")
    print(report)


def main():
    parser = argparse.ArgumentParser(description="Analyze Chai-Lab benchmark results")
    parser.add_argument("results_csv", help="Path to benchmark results CSV")
    parser.add_argument("-o", "--output", help="Output file for report (optional)")
    args = parser.parse_args()

    results = load_results(args.results_csv)
    generate_report(results, args.output)


if __name__ == "__main__":
    main()
