#!/usr/bin/env perl

=head1 NAME

App-ChaiLab - BV-BRC AppService script for Chai-1 molecular structure prediction

=head1 SYNOPSIS

    App-ChaiLab [--preflight] params.json

=head1 DESCRIPTION

This script implements the BV-BRC AppService interface for running Chai-1
molecular structure predictions. It handles:

- Input validation (FASTA format)
- Optional constraints file (JSON)
- Workspace file download/upload
- Resource estimation for job scheduling
- Execution of chai-lab fold command
- Result collection and workspace upload

=cut

use strict;
use warnings;
use Carp::Always;  # Stack traces on errors (production debugging)
use Data::Dumper;
use File::Basename;
use File::Path qw(make_path remove_tree);
use File::Slurp;
use File::Copy;
use JSON;
use Getopt::Long;
use Try::Tiny;
use POSIX qw(strftime);

# BV-BRC modules
use Bio::KBase::AppService::AppScript;

# Default log level for production
$ENV{P3_LOG_LEVEL} //= 'INFO';

# Initialize the AppScript with our callbacks
my $script = Bio::KBase::AppService::AppScript->new(\&run_chailab, \&preflight);
$script->run(\@ARGV);

=head2 preflight

Estimate resource requirements based on input parameters.

=cut

sub preflight {
    my ($app, $app_def, $raw_params, $params) = @_;

    # Default resource estimates for GPU-based structure prediction
    my $cpu = 8;
    my $memory = "64G";
    my $runtime = 7200;  # 2 hours default
    my $storage = "50G";

    # Adjust based on number of samples
    my $num_samples = $params->{num_samples} // 5;

    if ($num_samples > 10) {
        $runtime = 14400;  # 4 hours
        $memory = "96G";
    } elsif ($num_samples > 5) {
        $runtime = 10800;  # 3 hours
        $memory = "80G";
    }

    # MSA generation adds time
    if ($params->{use_msa_server}) {
        $runtime += 1800;  # +30 minutes for MSA
    }

    # Templates add time
    if ($params->{use_templates_server}) {
        $runtime += 1200;  # +20 minutes for templates
    }

    return {
        cpu => $cpu,
        memory => $memory,
        runtime => $runtime,
        storage => $storage,
        policy_data => {
            gpu_count => 1,
            partition => 'gpu2',
            constraint => 'A100|H100|H200'
        }
    };
}

=head2 run_chailab

Main execution function for Chai-1 structure prediction.

=cut

sub run_chailab {
    my ($app, $app_def, $raw_params, $params) = @_;

    print "Starting Chai-1 structure prediction\n";
    print STDERR "Parameters: " . Dumper($params) . "\n" if $ENV{P3_DEBUG};

    # Create working directories
    my $work_dir = $ENV{P3_WORKDIR} // $ENV{TMPDIR} // "/tmp";
    my $input_dir = "$work_dir/input";
    my $output_dir = "$work_dir/output";

    # Ensure output directory is empty (chai-lab requirement)
    if (-d $output_dir && !is_dir_empty($output_dir)) {
        warn "Output directory $output_dir is not empty, cleaning...\n";
        remove_tree($output_dir);
    }

    make_path($input_dir) unless -d $input_dir;
    make_path($output_dir) unless -d $output_dir;

    # Download input FASTA file from workspace
    my $input_file = $params->{input_file};
    die "Input file is required\n" unless $input_file;

    print "Downloading input file: $input_file\n";
    my $local_input = download_workspace_file($app, $input_file, $input_dir);

    # Validate and rewrite FASTA for Chai-Lab compatibility
    validate_fasta($local_input);
    print "Rewriting FASTA identifiers for Chai-Lab...\n";
    my ($chai_input, $mapping_file) = rewrite_fasta_for_chai($local_input, $input_dir);

    # Download optional constraints file
    my $local_constraints;
    if (my $constraints_file = $params->{constraints_file}) {
        print "Downloading constraints file: $constraints_file\n";
        $local_constraints = download_workspace_file($app, $constraints_file, $input_dir);
    }

    # Download optional MSA files into msa subdirectory
    my $msa_dir;
    if (my $msa_files = $params->{msa_files}) {
        $msa_dir = "$input_dir/msa";
        make_path($msa_dir) unless -d $msa_dir;

        my @files = ref($msa_files) eq 'ARRAY' ? @$msa_files : ($msa_files);
        for my $msa_file (@files) {
            print "Downloading MSA file: $msa_file\n";
            download_workspace_file($app, $msa_file, $msa_dir);
        }
    }

    # Download optional MSA directory (workspace folder)
    if (my $ws_msa_dir = $params->{msa_directory}) {
        $msa_dir //= "$input_dir/msa";
        make_path($msa_dir) unless -d $msa_dir;

        print "Downloading MSA directory: $ws_msa_dir\n";
        download_workspace_folder($app, $ws_msa_dir, $msa_dir);
    }

    # Find chai-lab binary: check PATH first, then P3_CHAI_PATH, then default
    my $chai_bin = find_chai_binary();
    print "Using chai-lab binary: $chai_bin\n";

    # Set CHAI_DOWNLOADS_DIR to a writable location for conformer cache files
    # Chai-Lab tries to download cache files on first run; this must be writable
    #
    # In the container environment, CHAI_DOWNLOADS_DIR will have been set by the
    # container build to a preloaded directory of data.
    #
    if (!$ENV{CHAI_DOWNLOADS_DIR})
    {
	my $chai_cache_dir = "$work_dir/chai_cache";
	make_path($chai_cache_dir) unless -d $chai_cache_dir;
	$ENV{CHAI_DOWNLOADS_DIR} = $chai_cache_dir;
	print "Chai cache directory: $chai_cache_dir\n";
    }

    # Build chai-lab command
    my @cmd = ($chai_bin, "fold", $chai_input, $output_dir);

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
    if ($msa_dir) {
        push @cmd, "--msa-directory", $msa_dir;
    }

    # Template hits file
    if (my $template_file = $params->{template_hits_file}) {
        my $local_template = download_workspace_file($app, $template_file, $input_dir);
        push @cmd, "--template-hits-path", $local_template;
    }

    # Dry run mode - skip execution
    if ($params->{dry_run}) {
        print "DRY RUN MODE - skipping chai-lab execution\n";
        print "Command would be: " . join(" ", @cmd) . "\n";
        print "Input directory contents:\n";
        list_directory($input_dir);
        if ($msa_dir && -d $msa_dir) {
            print "MSA directory contents:\n";
            list_directory($msa_dir);
        }
        print "Dry run completed successfully\n";
        return 0;
    }

    # Execute chai-lab
    print "Executing: " . join(" ", @cmd) . "\n";

    my $rc = system(@cmd);
    if ($rc != 0) {
        die "Chai-lab prediction failed with exit code: $rc\n";
    }

    print "Chai-lab prediction completed successfully\n";

    # Get output folder from app framework
    my $output_folder = $app->result_folder();
    die "Could not get result folder from app framework\n" unless $output_folder;

    # Clean up trailing slashes/dots
    $output_folder =~ s/\/+$//;
    $output_folder =~ s/\/\.$//;

    # Use output_file parameter as base name, create unique subfolder
    my $output_base = $params->{output_file} // "chailab_result";
    my $timestamp = POSIX::strftime("%Y%m%d_%H%M%S", localtime);
    my $task_id = $app->{task_id} // "unknown";
    my $run_folder = "${output_base}_${timestamp}_${task_id}";
    $output_folder = "$output_folder/$run_folder";

    print "Uploading results to workspace: $output_folder\n";
    upload_results($app, $output_dir, $output_folder);

    # Also upload the sequence ID mapping file
    if (-f $mapping_file) {
        print "Uploading sequence ID mapping: $mapping_file\n";
        if ($app && $app->can('workspace')) {
            try {
                $app->workspace->save_file_to_file($mapping_file, {}, "$output_folder/sequence_id_mapping.json", "json", 1, 1);
            } catch {
                warn "Failed to upload mapping file: $_\n";
            };
        }
    }

    print "Chai-lab job completed\n";
    return 0;
}

=head2 validate_fasta

Validate that input file is in FASTA format.

=cut

sub validate_fasta {
    my ($file) = @_;

    my $content = read_file($file, { binmode => ':raw' });

    # Check for FASTA header
    unless ($content =~ /^>/m) {
        die "Input file does not appear to be in FASTA format. Expected '>' header.\n";
    }

    # Basic validation of sequences
    my @headers = ($content =~ /^>(.*)$/mg);
    if (@headers == 0) {
        die "No sequences found in FASTA file.\n";
    }

    print "Found " . scalar(@headers) . " sequence(s) in input file\n";

    # List the chains/sequences
    for my $header (@headers) {
        print "  - $header\n";
    }

    return 1;
}

=head2 rewrite_fasta_for_chai

Rewrite FASTA file to use Chai-Lab compatible identifiers.

Chai-Lab expects headers in format: >entity_type|chain_id
For example: >protein|A, >protein|B, >smiles|L, >dna|D

This function:
1. Reads the input FASTA
2. Assigns chain IDs (A, B, C, ...) to each sequence
3. Detects entity type (protein, dna, rna, smiles)
4. Writes a new FASTA with Chai-compatible headers
5. Creates a mapping file to track original IDs

Returns: ($new_fasta_path, $mapping_file_path)

=cut

sub rewrite_fasta_for_chai {
    my ($input_file, $output_dir) = @_;

    my $content = read_file($input_file, { binmode => ':raw' });

    # Parse sequences - split on header lines
    my @entries;
    my @blocks = split(/(?=^>)/m, $content);

    for my $block (@blocks) {
        next unless $block =~ /\S/;  # Skip empty blocks
        next unless $block =~ /^>/;  # Must start with >

        # Split header from sequence
        my ($header_line, @seq_lines) = split(/\n/, $block);

        # Extract header (remove leading >)
        my $header = $header_line;
        $header =~ s/^>//;
        $header =~ s/\s+$//;  # Trim trailing whitespace

        # Join sequence lines and remove all whitespace
        my $seq = join('', @seq_lines);
        $seq =~ s/\s+//g;

        if (length($seq) > 0) {
            push @entries, {
                original_header => $header,
                sequence => $seq,
            };
        } else {
            warn "Warning: Empty sequence for header: $header\n";
        }
    }

    die "No sequences found in FASTA file\n" unless @entries;

    # Assign chain IDs and detect entity types
    my @chain_ids = ('A'..'Z', 'a'..'z');  # Up to 52 chains
    my @mapping;
    my @new_fasta_lines;

    for my $i (0 .. $#entries) {
        my $entry = $entries[$i];
        my $chain_id = $chain_ids[$i] // die "Too many sequences (max 52 supported)\n";

        # Detect entity type from sequence content
        my $entity_type = detect_entity_type($entry->{sequence}, $entry->{original_header});

        # Build new header
        my $new_header = "$entity_type|$chain_id";

        push @new_fasta_lines, ">$new_header\n$entry->{sequence}\n";

        push @mapping, {
            chain_id => $chain_id,
            entity_type => $entity_type,
            original_id => $entry->{original_header},
        };

        print "  Chain $chain_id ($entity_type): $entry->{original_header}\n";
    }

    # Write new FASTA
    my $new_fasta = "$output_dir/chai_input.fasta";
    write_file($new_fasta, join('', @new_fasta_lines));

    # Write mapping file (JSON)
    my $mapping_file = "$output_dir/sequence_id_mapping.json";
    write_file($mapping_file, encode_json(\@mapping));

    print "Rewrote FASTA for Chai-Lab: $new_fasta\n";
    print "ID mapping saved to: $mapping_file\n";

    return ($new_fasta, $mapping_file);
}

=head2 detect_entity_type

Detect the entity type (protein, dna, rna, smiles) from sequence content.

=cut

sub detect_entity_type {
    my ($sequence, $header) = @_;

    # Check header for explicit type hints
    if ($header =~ /\|\s*(protein|dna|rna|smiles)\s*(\||$)/i) {
        return lc($1);
    }

    # Check if it's a SMILES string (contains special characters)
    if ($sequence =~ /[=#@\[\]\(\)\+\-]/ && $sequence =~ /^[A-Za-z0-9=#@\[\]\(\)\+\-\.\\\/%]+$/) {
        return 'smiles';
    }

    # Normalize sequence for analysis
    my $upper_seq = uc($sequence);

    # Count nucleotide vs amino acid characters
    my $dna_chars = ($upper_seq =~ tr/ATCG//);
    my $rna_chars = ($upper_seq =~ tr/AUCG//);
    my $protein_chars = ($upper_seq =~ tr/ACDEFGHIKLMNPQRSTVWY//);

    my $seq_len = length($sequence);
    return 'protein' if $seq_len == 0;  # Default for empty

    # If >90% DNA nucleotides (ATCG only), it's DNA
    if ($dna_chars / $seq_len > 0.9 && $upper_seq !~ /U/) {
        return 'dna';
    }

    # If contains U and >90% RNA nucleotides, it's RNA
    if ($upper_seq =~ /U/ && $rna_chars / $seq_len > 0.9) {
        return 'rna';
    }

    # Default to protein
    return 'protein';
}

=head2 download_workspace_file

Download a file from the BV-BRC workspace.

=cut

sub download_workspace_file {
    my ($app, $ws_path, $local_dir) = @_;

    my $basename = basename($ws_path);
    my $local_path = "$local_dir/$basename";

    # Use workspace API to download
    if ($app && $app->can('workspace')) {
        try {
            # use_shock=1 required for files > 1KB (stored in Shock automatically)
            $app->workspace->download_file($ws_path, $local_path, 1);
        } catch {
            die "Failed to download $ws_path: $_\n";
        };
    } else {
        # Fallback for testing without workspace
        if (-f $ws_path) {
            copy($ws_path, $local_path) or die "Copy failed: $!\n";
        } else {
            die "File not found: $ws_path\n";
        }
    }

    return $local_path;
}

=head2 download_workspace_folder

Download a folder from the BV-BRC workspace.

=cut

sub download_workspace_folder {
    my ($app, $ws_path, $local_dir) = @_;

    # Use workspace API to list and download folder contents
    if ($app && $app->can('workspace')) {
        try {
            my $files = $app->workspace->ls({paths => [$ws_path]});
            if ($files && $files->{$ws_path}) {
                for my $entry (@{$files->{$ws_path}}) {
                    my ($name, $type) = @$entry;
                    my $ws_file = "$ws_path/$name";
                    if ($type eq 'file') {
                        print "  Downloading: $name\n";
                        # use_shock=1 required for files > 1KB
                        $app->workspace->download_file($ws_file, "$local_dir/$name", 1);
                    }
                }
            }
        } catch {
            die "Failed to download folder $ws_path: $_\n";
        };
    } else {
        # Fallback for testing without workspace
        if (-d $ws_path) {
            opendir(my $dh, $ws_path) or die "Cannot open $ws_path: $!\n";
            while (my $entry = readdir($dh)) {
                next if $entry =~ /^\./;
                my $src = "$ws_path/$entry";
                if (-f $src) {
                    copy($src, "$local_dir/$entry") or die "Copy failed: $!\n";
                }
            }
            closedir($dh);
        } else {
            die "Directory not found: $ws_path\n";
        }
    }
}

=head2 upload_results

Upload prediction results to the BV-BRC workspace.

=cut

sub upload_results {
    my ($app, $local_dir, $ws_path) = @_;

    # Find all output files
    my @files;
    find_files($local_dir, \@files);

    my @mapping = ('--map-suffix' => "txt=txt",
		   '--map-suffix' => "pdb=pdb",
		   '--map-suffix' => "cif=cif",
		   '--map-suffix' => "mmcif=mmcif",
		   '--map-suffix' => "fasta=protein_feature_fasta",
		   '--map-suffix' => "fa=protein_feature_fasta",
		   '--map-suffix' => "faa=protein_feature_fasta");

    my @cmd = ("p3-cp", "--overwrite", "-r", @mapping, $local_dir, "ws:$ws_path");
    print "@cmd=n";
    my $rc = system(@cmd);
    $rc == 0 or die "Error copying data to workspace\n";
}

=head2 list_directory

List contents of a directory for dry run output.

=cut

sub list_directory {
    my ($dir) = @_;
    opendir(my $dh, $dir) or return;
    while (my $entry = readdir($dh)) {
        next if $entry =~ /^\./;
        my $path = "$dir/$entry";
        my $type = -d $path ? "dir" : "file";
        my $size = -f $path ? -s $path : 0;
        print "  [$type] $entry";
        print " ($size bytes)" if $type eq 'file';
        print "\n";
    }
    closedir($dh);
}

=head2 is_dir_empty

Check if a directory is empty.

=cut

sub is_dir_empty {
    my ($dir) = @_;
    opendir(my $dh, $dir) or return 1;
    my @entries = grep { $_ ne '.' && $_ ne '..' } readdir($dh);
    closedir($dh);
    return @entries == 0;
}

=head2 find_files

Recursively find all files in a directory.

=cut

sub find_files {
    my ($dir, $files) = @_;

    opendir(my $dh, $dir) or return;
    while (my $entry = readdir($dh)) {
        next if $entry =~ /^\./;
        my $path = "$dir/$entry";
        if (-d $path) {
            find_files($path, $files);
        } else {
            push @$files, $path;
        }
    }
    closedir($dh);
}

=head2 find_chai_binary

Find the chai-lab binary. Checks in order:
1. chai-lab in PATH
2. P3_CHAI_PATH environment variable
3. Default path /opt/conda-chai/bin

=cut

sub find_chai_binary {
    my $binary = "chai-lab";

    # Check if chai-lab is in PATH by iterating PATH entries
    if (my $path_env = $ENV{PATH}) {
        my @path_dirs = split(/:/, $path_env);
        for my $dir (@path_dirs) {
            next unless $dir;  # Skip empty entries
            my $full_path = "$dir/$binary";
            if (-x $full_path && !-d $full_path) {
                return $full_path;
            }
        }
    }

    # Check P3_CHAI_PATH environment variable
    if (my $chai_path = $ENV{P3_CHAI_PATH}) {
        my $bin_path = "$chai_path/$binary";
        if (-x $bin_path) {
            return $bin_path;
        }
    }

    # Default to /opt/conda-chai/bin
    $ENV{P3_CHAI_PATH} //= "/opt/conda-chai/bin";
    return "$ENV{P3_CHAI_PATH}/$binary";
}

__END__

=head1 AUTHOR

BV-BRC Team

=head1 LICENSE

Apache 2.0 License (following Chai-Lab licensing)

=cut
