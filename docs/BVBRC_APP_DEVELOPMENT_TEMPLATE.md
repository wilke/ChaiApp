# BV-BRC App Development Template

**Based on:** ChaiApp (Chai-1 Molecular Structure Prediction)
**Version:** 1.0
**Date:** 2026-01-21

This template documents the complete process for developing, testing, and handing off a BV-BRC application. Follow these steps to ensure consistent, high-quality app delivery.

---

## Table of Contents

1. [Project Initialization](#1-project-initialization)
2. [Phase 1: Research & Planning](#2-phase-1-research--planning)
3. [Phase 2: Container Development](#3-phase-2-container-development)
4. [Phase 3: Service Script Development](#4-phase-3-service-script-development)
5. [Phase 4: Testing](#5-phase-4-testing)
6. [Phase 5: Documentation](#6-phase-5-documentation)
7. [Phase 6: Hand-off](#7-phase-6-hand-off)
8. [Issue Tracking](#8-issue-tracking)
9. [Checklist](#9-checklist)

---

## 1. Project Initialization

### 1.1 Create Repository Structure

```bash
mkdir -p MyApp/{app_specs,container,cwl,docs,lib,reports,scripts,service-scripts,t,test_data,tests}
cd MyApp
git init
```

### 1.2 Standard Directory Layout

```
MyApp/
├── CLAUDE.md                    # Claude Code instructions
├── Makefile                     # BV-BRC build system
├── app_specs/
│   └── MyApp.json              # App specification
├── container/
│   ├── Dockerfile.myapp        # Base tool container
│   ├── Dockerfile.myapp-bvbrc  # BV-BRC runtime layer
│   ├── myapp-bvbrc.def         # Apptainer definition
│   └── build.sh                # Build script with metadata
├── cwl/
│   ├── myapp.cwl               # CWL workflow definition
│   └── myapp-job.yml           # Example job file
├── docs/
│   ├── INPUT_FORMATS.md        # Input file specifications
│   ├── RUNTIME_METRICS.md      # Resource requirements
│   ├── ACCEPTANCE_TESTING.md   # Test procedures
│   ├── HANDOFF_UI_TEAM.md      # UI integration guide
│   └── HANDOFF_DEPLOYMENT_TEAM.md  # Deployment guide
├── service-scripts/
│   └── App-MyApp.pl            # BV-BRC service script
├── test_data/
│   └── (sample input files)
└── tests/
    ├── params.json             # Test parameters
    └── validate_output.sh      # Output validation
```

### 1.3 Create CLAUDE.md

```markdown
# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Project Overview

[Brief description of the app and its purpose]

## Build Commands

```bash
# Build and deploy
make all
make deploy-client
make deploy-service
```

## Container Build

```bash
cd container
./build.sh [tag]
./build.sh --push [tag]
```

## Testing

```bash
# Local smoke test
docker run --rm myimage:tag tool --help

# GPU test
docker run --gpus all -v $(pwd)/test_data:/data myimage:tag ...
```

## Key Files

- `app_specs/MyApp.json` - Application specification
- `service-scripts/App-MyApp.pl` - Service script
- `container/Dockerfile.myapp-bvbrc` - Container definition
```

### 1.4 Create GitHub Issues for Tracking

Create a master checklist issue (#1) with this template:

```markdown
## Target software for App development:
- [ ] Git repository for the original tool/software/pipeline
- [ ] Snapshot of the software, specified release or git tag
- [ ] Tested Dockerfile or Apptainer definition
- [ ] Documentation exists and command line options are documented
- [ ] Test data is available
- [ ] Runtime metrics captured for Memory, Disk, CPU and GPU usage
- [ ] CWL tool specification

## App-Service-Script:
- [ ] Containerized runtime for tool with BV-BRC Perl
- [ ] App spec
- [ ] Service Script
- [ ] Test locally
- [ ] Workspace integration

## Hand-off:
- [ ] Service integration and UI development (hand over to UI team)
- [ ] Deployment for testing (hand over to deployment team)
```

---

## 2. Phase 1: Research & Planning

### 2.1 Tool Analysis

**Objective:** Understand the target tool's requirements and capabilities.

```bash
# Clone and explore the original tool
git clone <original-tool-repo>

# Document CLI options
tool --help > docs/CLI_OPTIONS.txt

# Identify dependencies
pip freeze > requirements.txt  # Python
# or equivalent for other languages
```

**Deliverables:**
- [ ] Tool repository URL documented
- [ ] Version/tag identified
- [ ] CLI options documented
- [ ] Dependencies listed
- [ ] Input/output formats documented

### 2.2 Create Input Format Documentation

**File:** `docs/INPUT_FORMATS.md`

Document all supported input formats with:
- File format specifications
- Example files
- Validation rules
- Common errors

### 2.3 Create Test Data

**Directory:** `test_data/`

Create representative test files covering:

| Test Case | File | Description |
|-----------|------|-------------|
| Minimal | `simple_input.ext` | Smallest valid input |
| Standard | `standard_input.ext` | Typical use case |
| Complex | `complex_input.ext` | Edge cases, large input |
| Error | `invalid_input.ext` | Invalid input for error testing |

---

## 3. Phase 2: Container Development

### 3.1 Base Container (Tool Only)

**File:** `container/Dockerfile.myapp`

```dockerfile
# Base image with required runtime (CUDA for GPU, etc.)
FROM nvidia/cuda:12.1-runtime-ubuntu22.04

# Install tool dependencies
RUN apt-get update && apt-get install -y \
    python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install tool
RUN pip install mytool==X.Y.Z

# Verify installation
RUN mytool --version

ENTRYPOINT ["mytool"]
CMD ["--help"]
```

**Build and test:**

```bash
docker build -t myorg/mytool:latest-gpu -f container/Dockerfile.myapp .
docker run --rm myorg/mytool:latest-gpu --help
docker push myorg/mytool:latest-gpu
```

### 3.2 BV-BRC Runtime Layer

**File:** `container/Dockerfile.myapp-bvbrc`

```dockerfile
# Start from base tool image
FROM --platform=linux/amd64 myorg/mytool:latest-gpu

# Build arguments for metadata
ARG BUILD_DATE=unknown
ARG GIT_COMMIT=unknown
ARG GIT_BRANCH=unknown
ARG VERSION=1.0.0

# OCI standard labels
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${GIT_COMMIT}"
LABEL org.opencontainers.image.source="https://github.com/org/MyApp"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.title="MyApp BV-BRC"
LABEL org.opencontainers.image.description="Description here"

# Application-specific labels
LABEL app.name="MyApp"
LABEL app.version="${VERSION}"
LABEL build.date="${BUILD_DATE}"
LABEL build.git.commit="${GIT_COMMIT}"
LABEL build.git.branch="${GIT_BRANCH}"

# Copy BV-BRC runtime from dev_container
# This provides Perl 5.40.2 + 200 CPAN modules + BV-BRC libraries
COPY --from=dxkb/dev_container:cuda12-ubuntu22.04 /opt/patric-common /opt/patric-common
COPY --from=dxkb/dev_container:cuda12-ubuntu22.04 /build/dev_container /build/dev_container

# Standard BV-BRC Environment Variables
ENV RT=/opt/patric-common/runtime
ENV KB_DEPLOYMENT=/opt/patric-common/deployment
ENV KB_TOP=/opt/patric-common/deployment
ENV PERL5LIB=$KB_DEPLOYMENT/lib:$RT/lib/perl5
ENV PATH=$KB_DEPLOYMENT/bin:$RT/bin:$PATH

# App-specific environment
ENV KB_MODULE_DIR=/kb/module

# Install additional CPAN modules if needed
RUN $RT/bin/cpanm --notest Module::Name Another::Module

# Create service directories
RUN mkdir -p /kb/module/service-scripts \
             /kb/module/app_specs \
             /cache

# Copy app components
COPY app_specs/ /kb/module/app_specs/
COPY service-scripts/ /kb/module/service-scripts/

# Make scripts executable
RUN chmod +x /kb/module/service-scripts/*.pl

# Write build info
RUN echo "BUILD_DATE=${BUILD_DATE}" > /kb/module/BUILD_INFO && \
    echo "GIT_COMMIT=${GIT_COMMIT}" >> /kb/module/BUILD_INFO && \
    echo "GIT_BRANCH=${GIT_BRANCH}" >> /kb/module/BUILD_INFO && \
    echo "VERSION=${VERSION}" >> /kb/module/BUILD_INFO

WORKDIR /data

# Create entrypoint
RUN echo '#!/bin/bash\n\
case "$1" in\n\
    App-MyApp*)\n\
        exec $RT/bin/perl /kb/module/service-scripts/App-MyApp.pl "${@:2}"\n\
        ;;\n\
    mytool)\n\
        shift\n\
        exec mytool "$@"\n\
        ;;\n\
    *)\n\
        exec "$@"\n\
        ;;\n\
esac' > /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["mytool", "--help"]
```

### 3.3 Build Script with Metadata

**File:** `container/build.sh`

```bash
#!/bin/bash
set -e

IMAGE_NAME="myorg/myapp-bvbrc"
DEFAULT_TAG="test"
DOCKERFILE="Dockerfile.myapp-bvbrc"

TAG="${1:-$DEFAULT_TAG}"
PUSH=false
[[ "$1" == "--push" ]] && { TAG="${2:-latest-gpu}"; PUSH=true; }
[[ "$2" == "--push" ]] && PUSH=true

cd "$(dirname "$0")/.."

BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
GIT_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
GIT_COMMIT_SHORT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
VERSION="1.0.0"
DATE_TAG=$(date +%Y%m%d)-${GIT_COMMIT_SHORT}

echo "Building ${IMAGE_NAME}:${TAG}"
echo "  Build Date: ${BUILD_DATE}"
echo "  Git Commit: ${GIT_COMMIT}"
echo "  Version:    ${VERSION}"

docker build --platform linux/amd64 \
    --build-arg BUILD_DATE="${BUILD_DATE}" \
    --build-arg GIT_COMMIT="${GIT_COMMIT}" \
    --build-arg GIT_BRANCH="${GIT_BRANCH}" \
    --build-arg VERSION="${VERSION}" \
    -t "${IMAGE_NAME}:${TAG}" \
    -t "${IMAGE_NAME}:${DATE_TAG}" \
    -f container/${DOCKERFILE} \
    .

echo "Build complete: ${IMAGE_NAME}:${TAG}"

# Verify
docker run --rm "${IMAGE_NAME}:${TAG}" cat /kb/module/BUILD_INFO

[[ "$PUSH" == "true" ]] && {
    docker push "${IMAGE_NAME}:${TAG}"
    docker push "${IMAGE_NAME}:${DATE_TAG}"
    echo "Pushed to DockerHub"
}
```

### 3.4 Apptainer Definition

**File:** `container/myapp-bvbrc.def`

```singularity
Bootstrap: docker
From: myorg/myapp-bvbrc:latest-gpu

%labels
    Author BV-BRC Team
    Version 1.0.0
    Application MyApp

%environment
    export RT=/opt/patric-common/runtime
    export KB_DEPLOYMENT=/opt/patric-common/deployment
    export PERL5LIB=$KB_DEPLOYMENT/lib:$RT/lib/perl5
    export PATH=$KB_DEPLOYMENT/bin:$RT/bin:$PATH

%test
    /opt/patric-common/runtime/bin/perl -e 'print "Perl OK\n"'
    /opt/patric-common/runtime/bin/perl -c /kb/module/service-scripts/App-MyApp.pl
    mytool --help > /dev/null && echo "mytool OK"

%runscript
    exec /entrypoint.sh "$@"
```

---

## 4. Phase 3: Service Script Development

### 4.1 App Specification

**File:** `app_specs/MyApp.json`

```json
{
    "id": "MyApp",
    "script": "App-MyApp",
    "label": "My Application Name",
    "description": "Description of what the app does.",
    "default_memory": "64G",
    "default_cpu": 8,
    "default_runtime": 7200,
    "parameters": [
        {
            "id": "input_file",
            "type": "wsfile",
            "required": 1,
            "label": "Input File",
            "desc": "Description of the input file format and requirements."
        },
        {
            "id": "option_file",
            "type": "wsfile",
            "required": 0,
            "label": "Optional File",
            "desc": "Description of optional file."
        },
        {
            "id": "boolean_option",
            "type": "bool",
            "default": true,
            "required": 0,
            "label": "Enable Feature",
            "desc": "Description of what this enables."
        },
        {
            "id": "numeric_option",
            "type": "int",
            "default": 5,
            "required": 0,
            "label": "Number of Items",
            "desc": "Description of numeric parameter."
        },
        {
            "id": "output_path",
            "type": "folder",
            "required": 1,
            "label": "Output Folder",
            "desc": "Workspace folder for results."
        }
    ],
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

### 4.2 Service Script Template

**File:** `service-scripts/App-MyApp.pl`

```perl
#!/usr/bin/env perl

=head1 NAME

App-MyApp - BV-BRC AppService script for MyApp

=head1 SYNOPSIS

    App-MyApp [--preflight] params.json

=head1 DESCRIPTION

This script implements the BV-BRC AppService interface for MyApp.

=cut

use strict;
use warnings;
use Data::Dumper;
use File::Basename;
use File::Path qw(make_path remove_tree);
use File::Slurp;
use File::Copy;
use JSON;
use Getopt::Long;
use Try::Tiny;

use Bio::KBase::AppService::AppScript;

my $script = Bio::KBase::AppService::AppScript->new(\&run_app, \&preflight);
$script->run(\@ARGV);

=head2 preflight

Estimate resource requirements based on input parameters.

=cut

sub preflight {
    my ($app, $app_def, $raw_params, $params) = @_;

    # Default resources
    my $cpu = 8;
    my $memory = "64G";
    my $runtime = 7200;
    my $storage = "50G";

    # Adjust based on parameters
    if (my $count = $params->{numeric_option}) {
        $runtime = $runtime * ($count / 5);  # Scale with count
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

=head2 run_app

Main execution function.

=cut

sub run_app {
    my ($app, $app_def, $raw_params, $params) = @_;

    print "Starting MyApp\n";
    print "Parameters: " . Dumper($params) . "\n";

    # Create working directories
    my $work_dir = $ENV{TMPDIR} // "/tmp";
    my $input_dir = "$work_dir/input";
    my $output_dir = "$work_dir/output";

    # Clean output directory if not empty
    if (-d $output_dir && !is_dir_empty($output_dir)) {
        warn "Output directory not empty, cleaning...\n";
        remove_tree($output_dir);
    }

    make_path($input_dir) unless -d $input_dir;
    make_path($output_dir) unless -d $output_dir;

    # Download input file
    my $input_file = $params->{input_file};
    die "Input file is required\n" unless $input_file;

    print "Downloading input: $input_file\n";
    my $local_input = download_workspace_file($app, $input_file, $input_dir);

    # Validate input
    validate_input($local_input);

    # Download optional files
    my $local_option;
    if (my $option_file = $params->{option_file}) {
        print "Downloading optional file: $option_file\n";
        $local_option = download_workspace_file($app, $option_file, $input_dir);
    }

    # Build command
    my @cmd = ("mytool", "run", $local_input, $output_dir);

    # Add options
    push @cmd, "--enable-feature" if $params->{boolean_option};
    push @cmd, "--count", $params->{numeric_option} if $params->{numeric_option};
    push @cmd, "--option-file", $local_option if $local_option;

    # Execute
    print "Executing: " . join(" ", @cmd) . "\n";

    my $rc = system(@cmd);
    die "MyApp failed with exit code: $rc\n" if $rc != 0;

    print "MyApp completed successfully\n";

    # Upload results
    my $output_path = $params->{output_path};
    die "Output path is required\n" unless $output_path;

    print "Uploading results to: $output_path\n";
    upload_results($app, $output_dir, $output_path);

    print "Job completed\n";
    return 0;
}

=head2 validate_input

Validate input file format.

=cut

sub validate_input {
    my ($file) = @_;

    my $content = read_file($file, { binmode => ':raw' });

    # Add format-specific validation
    # Example: Check for required header
    unless ($content =~ /^expected_header/m) {
        die "Input file format invalid\n";
    }

    return 1;
}

=head2 download_workspace_file

Download a file from BV-BRC workspace.

=cut

sub download_workspace_file {
    my ($app, $ws_path, $local_dir) = @_;

    my $basename = basename($ws_path);
    my $local_path = "$local_dir/$basename";

    if ($app && $app->can('workspace')) {
        try {
            $app->workspace->download_file($ws_path, $local_path);
        } catch {
            die "Failed to download $ws_path: $_\n";
        };
    } else {
        # Fallback for local testing
        if (-f $ws_path) {
            copy($ws_path, $local_path) or die "Copy failed: $!\n";
        } else {
            die "File not found: $ws_path\n";
        }
    }

    return $local_path;
}

=head2 upload_results

Upload results to BV-BRC workspace.

=cut

sub upload_results {
    my ($app, $local_dir, $ws_path) = @_;

    my @files;
    find_files($local_dir, \@files);

    for my $file (@files) {
        my $rel_path = $file;
        $rel_path =~ s/^\Q$local_dir\E\/?//;

        my $ws_file = "$ws_path/$rel_path";
        print "Uploading: $file -> $ws_file\n";

        if ($app && $app->can('workspace')) {
            try {
                $app->workspace->save_file_to_file($file, {}, $ws_file);
            } catch {
                warn "Failed to upload $file: $_\n";
            };
        }
    }
}

=head2 is_dir_empty

Check if directory is empty.

=cut

sub is_dir_empty {
    my ($dir) = @_;
    opendir(my $dh, $dir) or return 1;
    my @entries = grep { $_ ne '.' && $_ ne '..' } readdir($dh);
    closedir($dh);
    return @entries == 0;
}

=head2 find_files

Recursively find all files.

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

=cut
```

---

## 5. Phase 4: Testing

### 5.1 Test Parameter Files

**File:** `tests/params.json` (local testing)

```json
{
    "input_file": "/data/simple_input.ext",
    "output_path": "/output",
    "boolean_option": true,
    "numeric_option": 1
}
```

**File:** `tests/params_ws.json` (workspace testing)

```json
{
    "input_file": "/user@bvbrc/home/TestFolder/input.ext",
    "output_path": "/user@bvbrc/home/TestFolder/output",
    "boolean_option": true,
    "numeric_option": 5
}
```

### 5.2 Output Validation Script

**File:** `tests/validate_output.sh`

```bash
#!/bin/bash
set -e

OUTPUT_DIR="${1:-.}"
echo "Validating output in: $OUTPUT_DIR"

ERRORS=0

# Check for expected output files
if ls "$OUTPUT_DIR"/*.expected_ext 1>/dev/null 2>&1; then
    echo "[OK] Expected output files found"
else
    echo "[FAIL] No expected output files"
    ERRORS=$((ERRORS + 1))
fi

# Add more validation checks...

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "Validation PASSED"
    exit 0
else
    echo "Validation FAILED ($ERRORS errors)"
    exit 1
fi
```

### 5.3 Acceptance Test Suite

**File:** `docs/ACCEPTANCE_TESTING.md`

```markdown
# Acceptance Testing

## Test Matrix

| Test | Description | Expected |
|:----:|-------------|:--------:|
| 1 | Syntax check | PASS |
| 2 | Simple input | Output files |
| 3 | Complex input | Output files |
| 4 | Error handling | Error message |
| 5 | Workspace integration | Upload success |

## Test 1: Syntax Check

```bash
docker run --rm myorg/myapp-bvbrc:test \
  perl -c /kb/module/service-scripts/App-MyApp.pl
```

## Test 2: Simple Input

```bash
docker run --gpus all \
  -v $(pwd)/test_data:/data \
  -v $(pwd)/output:/output \
  myorg/myapp-bvbrc:test \
  App-MyApp /tests/params.json

./tests/validate_output.sh output/
```

## Test 3: Complex Input

[Similar structure...]

## Test 4: Error Handling

```bash
docker run --gpus all \
  -v $(pwd)/test_data:/data \
  -v $(pwd)/output:/output \
  myorg/myapp-bvbrc:test \
  App-MyApp /tests/params_error.json
# Should exit with error about invalid input
```

## Test 5: Workspace Integration

```bash
export P3_AUTH_TOKEN=$(cat ~/.patric_token)
docker run --gpus all \
  -e P3_AUTH_TOKEN="$P3_AUTH_TOKEN" \
  myorg/myapp-bvbrc:test \
  perl -e '
use Bio::P3::Workspace::WorkspaceClientExt;
my $ws = Bio::P3::Workspace::WorkspaceClientExt->new();
my $result = $ws->ls({paths => [q{/user@bvbrc/home}]});
print "Workspace connection: OK\n";
'
```
```

### 5.4 Test Execution Workflow

```bash
# 1. Build test image
./container/build.sh test

# 2. Run smoke tests (no GPU)
docker run --rm myorg/myapp-bvbrc:test mytool --help
docker run --rm myorg/myapp-bvbrc:test \
  perl -c /kb/module/service-scripts/App-MyApp.pl

# 3. Run GPU tests
mkdir -p output
docker run --gpus all \
  -v $(pwd)/test_data:/data \
  -v $(pwd)/output:/output \
  -v $(pwd)/tests:/tests \
  myorg/myapp-bvbrc:test \
  App-MyApp /tests/params.json

# 4. Validate output
./tests/validate_output.sh output/

# 5. Test workspace (requires P3_AUTH_TOKEN)
export P3_AUTH_TOKEN=$(cat ~/.patric_token)
docker run --rm \
  -e P3_AUTH_TOKEN="$P3_AUTH_TOKEN" \
  myorg/myapp-bvbrc:test \
  perl -e 'use Bio::P3::Workspace::WorkspaceClient; print "OK\n"'

# 6. Push if all tests pass
./container/build.sh --push latest-gpu
```

---

## 6. Phase 5: Documentation

### 6.1 Required Documentation

| Document | Purpose | Audience |
|----------|---------|----------|
| `INPUT_FORMATS.md` | Input specifications | Users, UI team |
| `RUNTIME_METRICS.md` | Resource requirements | Deployment team |
| `ACCEPTANCE_TESTING.md` | Test procedures | QA, developers |
| `HANDOFF_UI_TEAM.md` | UI integration | UI team |
| `HANDOFF_DEPLOYMENT_TEAM.md` | Deployment guide | DevOps |

### 6.2 Runtime Metrics Template

**File:** `docs/RUNTIME_METRICS.md`

```markdown
# Runtime Metrics

## Resource Requirements by Input Size

### Small Input
| Resource | Value |
|----------|-------|
| Memory | 32GB |
| CPU | 4 cores |
| GPU Memory | 20GB |
| Runtime | 15-30 min |

### Medium Input
| Resource | Value |
|----------|-------|
| Memory | 64GB |
| CPU | 8 cores |
| GPU Memory | 40GB |
| Runtime | 30-60 min |

### Large Input
| Resource | Value |
|----------|-------|
| Memory | 96GB |
| CPU | 8 cores |
| GPU Memory | 80GB |
| Runtime | 1-2 hours |

## Preflight Estimation

The service script estimates resources based on:
- Input size
- Selected options
- Number of samples/iterations

## Test Data Reference

| File | Size | Use Case |
|------|------|----------|
| `test_data/simple.ext` | X KB | Small test |
| `test_data/standard.ext` | X KB | Standard test |
| `test_data/large.ext` | X MB | Large test |
```

### 6.3 Hand-off Document Templates

See ChaiApp examples:
- `docs/HANDOFF_UI_TEAM.md`
- `docs/HANDOFF_DEPLOYMENT_TEAM.md`

---

## 7. Phase 6: Hand-off

### 7.1 Pre-Hand-off Checklist

- [ ] All acceptance tests pass
- [ ] Docker image pushed to registry
- [ ] Documentation complete
- [ ] GitHub issues updated
- [ ] Test data available

### 7.2 UI Team Hand-off

Provide:
1. Complete `app_specs/MyApp.json`
2. `docs/HANDOFF_UI_TEAM.md` with:
   - Parameter descriptions
   - UI element recommendations
   - Validation rules
   - Example layouts
3. Test data for development

### 7.3 Deployment Team Hand-off

Provide:
1. `docs/HANDOFF_DEPLOYMENT_TEAM.md` with:
   - Container image details
   - Infrastructure requirements
   - Environment variables
   - Test procedures
   - Monitoring guidance
2. Apptainer definition file
3. Test scripts

### 7.4 Close-out

1. Update GitHub issue #1 with completion status
2. Create hand-off issues for tracking
3. Archive or close development issues

---

## 8. Issue Tracking

### 8.1 Issue Labels

| Label | Purpose |
|-------|---------|
| `enhancement` | New feature |
| `bug` | Bug fix |
| `documentation` | Documentation |
| `testing` | Testing related |
| `blocked` | Waiting on external |

### 8.2 Standard Issues

Create these issues at project start:

1. **#1 App Development Checklist** (master tracker)
2. **#2 Phase 2: Base Container**
3. **#3 Phase 3: App Spec & Service Script**
4. **#4 Phase 4: Testing**
5. **#5 Phase 5: Documentation**

### 8.3 Issue Templates

**Bug Report:**
```markdown
## Problem
[Description]

## Reproduction Steps
1. Step 1
2. Step 2

## Expected Behavior
[What should happen]

## Actual Behavior
[What actually happens]

## Environment
- Container: `image:tag`
- Platform: [OS/version]
```

---

## 9. Checklist

### Project Setup
- [ ] Repository created with standard structure
- [ ] CLAUDE.md created
- [ ] GitHub issues created (#1 master checklist)
- [ ] Test data prepared

### Container Development
- [ ] Base Dockerfile created and tested
- [ ] BV-BRC layer Dockerfile created
- [ ] Build script with metadata created
- [ ] Apptainer definition created
- [ ] Image pushed to registry

### Service Script
- [ ] App spec created
- [ ] Service script implemented
- [ ] Preflight function implemented
- [ ] Workspace integration working

### Testing
- [ ] Test parameter files created
- [ ] Validation script created
- [ ] Acceptance tests documented
- [ ] All tests passing
- [ ] Workspace integration tested

### Documentation
- [ ] INPUT_FORMATS.md
- [ ] RUNTIME_METRICS.md
- [ ] ACCEPTANCE_TESTING.md
- [ ] HANDOFF_UI_TEAM.md
- [ ] HANDOFF_DEPLOYMENT_TEAM.md

### Hand-off
- [ ] UI team hand-off complete
- [ ] Deployment team hand-off complete
- [ ] Issues closed/transferred
- [ ] Master checklist updated

---

## Appendix: Common Pitfalls

### Perl String Interpolation

**Problem:** `@` in strings is interpolated as array.

```perl
# BAD - @bvbrc becomes empty array
my $path = "/user@bvbrc/home";

# GOOD - escape or use single quotes
my $path = "/user\@bvbrc/home";
my $path = '/user@bvbrc/home';
my $path = q{/user@bvbrc/home};
```

### Workspace Authentication

**Problem:** Workspace calls fail with permission errors.

**Solution:** Ensure `P3_AUTH_TOKEN` is passed to container:

```bash
export P3_AUTH_TOKEN=$(cat ~/.patric_token)
docker run -e P3_AUTH_TOKEN="$P3_AUTH_TOKEN" ...
```

### Non-Empty Output Directory

**Problem:** Tool fails if output directory contains files.

**Solution:** Clean directory in service script:

```perl
if (-d $output_dir && !is_dir_empty($output_dir)) {
    remove_tree($output_dir);
}
make_path($output_dir);
```

### Platform Mismatch

**Problem:** Container built for wrong platform.

**Solution:** Always build for linux/amd64:

```bash
docker build --platform linux/amd64 ...
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-21 | Initial template based on ChaiApp |
