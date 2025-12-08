#!/usr/bin/env python3
"""
Generate test FASTA files with various sequence lengths and batch sizes for Chai-Lab benchmarking.
"""

import os
import random
import argparse

# Common protein sequences of known lengths for realistic testing
# These are fragments/domains that represent realistic protein sequences

AMINO_ACIDS = "ACDEFGHIKLMNPQRSTVWY"

def generate_random_sequence(length: int, seed: int = None) -> str:
    """Generate a random protein sequence of specified length."""
    if seed is not None:
        random.seed(seed)
    return ''.join(random.choices(AMINO_ACIDS, k=length))


def write_fasta(filename: str, sequences: list[tuple[str, str]]):
    """Write sequences to FASTA file.

    Args:
        filename: Output file path
        sequences: List of (header, sequence) tuples
    """
    with open(filename, 'w') as f:
        for header, seq in sequences:
            f.write(f">{header}\n")
            # Write sequence in 80-character lines
            for i in range(0, len(seq), 80):
                f.write(seq[i:i+80] + "\n")


def generate_test_cases(output_dir: str):
    """Generate test FASTA files for benchmarking."""
    os.makedirs(output_dir, exist_ok=True)

    # Define test cases: (name, [(length, count), ...])
    # Single sequences of varying lengths
    single_seq_lengths = [50, 100, 200, 300, 500, 750, 1000]

    # Multi-chain batches (protein complexes)
    batch_configs = [
        ("2chain_small", [(100, 2)]),      # 2 chains of 100aa each
        ("2chain_medium", [(200, 2)]),     # 2 chains of 200aa each
        ("2chain_large", [(300, 2)]),      # 2 chains of 300aa each
        ("3chain_small", [(100, 3)]),      # 3 chains of 100aa
        ("4chain_small", [(100, 4)]),      # 4 chains of 100aa
        ("5chain_small", [(80, 5)]),       # 5 chains of 80aa
        ("heterodimer", [(150, 1), (250, 1)]),  # Two different sized chains
        ("complex_3chain", [(100, 1), (200, 1), (150, 1)]),  # 3 different chains
    ]

    test_cases = []

    # Generate single sequence files
    for length in single_seq_lengths:
        filename = f"single_{length}aa.fasta"
        filepath = os.path.join(output_dir, filename)
        seq = generate_random_sequence(length, seed=length)
        write_fasta(filepath, [(f"protein|name=protein_{length}aa", seq)])

        total_residues = length
        test_cases.append({
            "name": f"single_{length}aa",
            "file": filename,
            "num_chains": 1,
            "total_residues": total_residues,
            "description": f"Single chain, {length} residues"
        })
        print(f"Generated: {filename} ({total_residues} total residues)")

    # Generate multi-chain files
    for name, chain_specs in batch_configs:
        filename = f"{name}.fasta"
        filepath = os.path.join(output_dir, filename)

        sequences = []
        total_residues = 0
        chain_idx = 0

        for length, count in chain_specs:
            for i in range(count):
                chain_id = chr(ord('A') + chain_idx)
                seq = generate_random_sequence(length, seed=length * 1000 + i)
                sequences.append((f"protein|name=chain_{chain_id}", seq))
                total_residues += length
                chain_idx += 1

        write_fasta(filepath, sequences)

        num_chains = sum(count for _, count in chain_specs)
        test_cases.append({
            "name": name,
            "file": filename,
            "num_chains": num_chains,
            "total_residues": total_residues,
            "description": f"{num_chains} chains, {total_residues} total residues"
        })
        print(f"Generated: {filename} ({num_chains} chains, {total_residues} total residues)")

    # Write manifest
    manifest_path = os.path.join(output_dir, "test_manifest.txt")
    with open(manifest_path, 'w') as f:
        f.write("# Chai-Lab Benchmark Test Cases\n")
        f.write("# name\tfile\tnum_chains\ttotal_residues\tdescription\n")
        for tc in test_cases:
            f.write(f"{tc['name']}\t{tc['file']}\t{tc['num_chains']}\t{tc['total_residues']}\t{tc['description']}\n")

    print(f"\nGenerated {len(test_cases)} test cases")
    print(f"Manifest written to: {manifest_path}")

    return test_cases


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate test sequences for Chai-Lab benchmarking")
    parser.add_argument("-o", "--output", default="./input", help="Output directory")
    args = parser.parse_args()

    generate_test_cases(args.output)
