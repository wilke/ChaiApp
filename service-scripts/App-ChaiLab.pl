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
use Data::Dumper;
use File::Basename;
use File::Path qw(make_path);
use File::Slurp;
use File::Copy;
use JSON;
use Getopt::Long;
use Try::Tiny;

# BV-BRC modules
use Bio::KBase::AppService::AppScript;

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
        policy => {
            gpu => 1,
            gpu_type => "a100"
        }
    };
}

=head2 run_chailab

Main execution function for Chai-1 structure prediction.

=cut

sub run_chailab {
    my ($app, $app_def, $raw_params, $params) = @_;

    print "Starting Chai-1 structure prediction\n";
    print "Parameters: " . Dumper($params) . "\n";

    # Create working directories
    my $work_dir = $ENV{TMPDIR} // "/tmp";
    my $input_dir = "$work_dir/input";
    my $output_dir = "$work_dir/output";

    make_path($input_dir, $output_dir);

    # Download input FASTA file from workspace
    my $input_file = $params->{input_file};
    die "Input file is required\n" unless $input_file;

    print "Downloading input file: $input_file\n";
    my $local_input = download_workspace_file($app, $input_file, $input_dir);

    # Validate input is FASTA
    validate_fasta($local_input);

    # Download optional constraints file
    my $local_constraints;
    if (my $constraints_file = $params->{constraints_file}) {
        print "Downloading constraints file: $constraints_file\n";
        $local_constraints = download_workspace_file($app, $constraints_file, $input_dir);
    }

    # Download optional MSA file
    my $local_msa;
    if (my $msa_file = $params->{msa_file}) {
        print "Downloading MSA file: $msa_file\n";
        $local_msa = download_workspace_file($app, $msa_file, $input_dir);
    }

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

    # Number of samples
    if (my $samples = $params->{num_samples}) {
        push @cmd, "--num-samples", $samples;
    }

    # Constraints file
    if ($local_constraints) {
        push @cmd, "--constraints", $local_constraints;
    }

    # Pre-computed MSA
    if ($local_msa) {
        push @cmd, "--msa-file", $local_msa;
    }

    # Template hits file
    if (my $template_file = $params->{template_hits_file}) {
        my $local_template = download_workspace_file($app, $template_file, $input_dir);
        push @cmd, "--template-hits", $local_template;
    }

    # Execute chai-lab
    print "Executing: " . join(" ", @cmd) . "\n";

    my $rc = system(@cmd);
    if ($rc != 0) {
        die "Chai-lab prediction failed with exit code: $rc\n";
    }

    print "Chai-lab prediction completed successfully\n";

    # Upload results to workspace
    my $output_path = $params->{output_path};
    die "Output path is required\n" unless $output_path;

    print "Uploading results to workspace: $output_path\n";
    upload_results($app, $output_dir, $output_path);

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
            $app->workspace->download_file($ws_path, $local_path);
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

=head2 upload_results

Upload prediction results to the BV-BRC workspace.

=cut

sub upload_results {
    my ($app, $local_dir, $ws_path) = @_;

    # Find all output files
    my @files;
    find_files($local_dir, \@files);

    for my $file (@files) {
        my $rel_path = $file;
        $rel_path =~ s/^\Q$local_dir\E\/?//;

        my $ws_file = "$ws_path/$rel_path";
        print "Uploading: $file -> $ws_file\n";

        if ($app && $app->can('workspace')) {
            try {
                # Determine file type for workspace
                my $type = "txt";
                if ($file =~ /\.cif$/i) {
                    $type = "structure";
                } elsif ($file =~ /\.pdb$/i) {
                    $type = "structure";
                } elsif ($file =~ /\.json$/i) {
                    $type = "json";
                }

                $app->workspace->save_file_to_file($file, {}, $ws_file);
            } catch {
                warn "Failed to upload $file: $_\n";
            };
        }
    }
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

__END__

=head1 AUTHOR

BV-BRC Team

=head1 LICENSE

Apache 2.0 License (following Chai-Lab licensing)

=cut
