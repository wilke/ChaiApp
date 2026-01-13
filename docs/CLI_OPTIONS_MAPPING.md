# Chai-Lab CLI Options Mapping

This document provides a comprehensive mapping between Chai-Lab CLI options and the BV-BRC App Spec parameters.

## Chai-Lab CLI Reference

### Required Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `fasta_file` | PATH | Input FASTA file describing the molecular complex |
| `output_dir` | PATH | Directory for prediction outputs |

### Optional Flags

| CLI Option | Type | Default | Description |
|------------|------|---------|-------------|
| `--use-esm-embeddings` / `--no-use-esm-embeddings` | bool | true | Use ESM language model embeddings |
| `--use-msa-server` / `--no-use-msa-server` | bool | false | Use ColabFold MMseqs2 server for MSA generation |
| `--msa-server-url` | TEXT | https://api.colabfold.com | URL of the MSA server |
| `--msa-directory` | PATH | - | Directory containing pre-computed MSA files |
| `--constraint-path` | PATH | - | JSON file with distance/contact constraints |
| `--use-templates-server` / `--no-use-templates-server` | bool | false | Search for structural templates |
| `--template-hits-path` | PATH | - | M8 file with template hits |
| `--recycle-msa-subsample` | INTEGER | 0 | MSA subsampling during recycling |
| `--num-trunk-recycles` | INTEGER | 3 | Number of trunk recycling iterations |
| `--num-diffn-timesteps` | INTEGER | 200 | Number of diffusion timesteps |
| `--num-diffn-samples` | INTEGER | 5 | Number of structure samples to generate |
| `--num-trunk-samples` | INTEGER | 1 | Number of trunk samples |
| `--seed` | INTEGER | - | Random seed for reproducibility |
| `--device` | TEXT | - | Compute device (e.g., cuda:0) |
| `--low-memory` / `--no-low-memory` | bool | true | Enable low memory mode |
| `--fasta-names-as-cif-chains` / `--no-fasta-names-as-cif-chains` | bool | false | Use FASTA names as CIF chain IDs |

## BV-BRC App Spec Parameters

The following parameters are defined in `app_specs/ChaiLab.json`:

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `input_file` | wsfile | Yes | - | Input FASTA file from workspace |
| `output_path` | folder | Yes | - | Output folder in workspace |
| `constraints_file` | wsfile | No | - | Constraints JSON file |
| `use_msa_server` | bool | No | true | Enable MSA server |
| `use_templates_server` | bool | No | false | Enable templates server |
| `num_samples` | int | No | 5 | Number of structure samples |
| `msa_file` | wsfile | No | - | Pre-computed MSA file |
| `template_hits_file` | wsfile | No | - | Template hits M8 file |

## Parameter Mapping

### Current Mappings (App-ChaiLab.pl)

| App Spec Parameter | CLI Option | Status |
|--------------------|------------|--------|
| `input_file` | `fasta_file` (positional) | Implemented |
| `output_path` | `output_dir` (positional) | Implemented |
| `constraints_file` | `--constraint-path` | Implemented |
| `use_msa_server` | `--use-msa-server` | Implemented |
| `use_templates_server` | `--use-templates-server` | Implemented |
| `num_samples` | `--num-diffn-samples` | Implemented |
| `msa_file` | `--msa-directory` | Implemented |
| `template_hits_file` | `--template-hits-path` | Implemented |

### CLI Options Not Exposed in App Spec

The following CLI options are available but not currently exposed through the BV-BRC interface:

#### High Priority (Recommended for Addition)

| CLI Option | Rationale |
|------------|-----------|
| `--seed` | Enables reproducible predictions for scientific workflows |

#### Medium Priority (Consider for Advanced Users)

| CLI Option | Rationale |
|------------|-----------|
| `--num-trunk-recycles` | Quality vs speed tradeoff |
| `--num-diffn-timesteps` | Quality vs speed tradeoff |
| `--num-trunk-samples` | Additional sampling diversity |
| `--low-memory` | Memory optimization for large complexes |

#### Low Priority (Rarely Needed)

| CLI Option | Rationale |
|------------|-----------|
| `--use-esm-embeddings` | Default is optimal for most cases |
| `--msa-server-url` | Only needed for alternative servers |
| `--recycle-msa-subsample` | Advanced MSA control |
| `--device` | Auto-detected in most environments |
| `--fasta-names-as-cif-chains` | Output formatting preference |

## Implementation Notes

### Service Script Location

The parameter-to-CLI mapping is implemented in:
- `service-scripts/App-ChaiLab.pl` (lines 134-166)

### Command Construction

```perl
# Build chai-lab command
my @cmd = ("chai-lab", "fold", $local_input, $output_dir);

# MSA server option
if ($params->{use_msa_server} // 1) {
    push @cmd, "--use-msa-server";
}

# Templates server option
if ($params->{use_templates_server}) {
    push @cmd, "--use-templates-server";
}

# Number of samples (diffusion samples)
if (my $samples = $params->{num_samples}) {
    push @cmd, "--num-diffn-samples", $samples;
}

# Constraints file
if ($local_constraints) {
    push @cmd, "--constraint-path", $local_constraints;
}

# Pre-computed MSA directory
if ($local_msa) {
    push @cmd, "--msa-directory", $local_msa;
}

# Template hits file
if (my $template_file = $params->{template_hits_file}) {
    my $local_template = download_workspace_file($app, $template_file, $input_dir);
    push @cmd, "--template-hits-path", $local_template;
}
```

## Version History

| Date | Version | Changes |
|------|---------|---------|
| 2026-01-13 | 1.0 | Initial documentation |

## Related Issues

- [#6](https://github.com/wilke/ChaiApp/issues/6) - CLI option `--num-samples` changed to `--num-diffn-samples`
- [#7](https://github.com/wilke/ChaiApp/issues/7) - Multiple CLI option mismatches fixed
