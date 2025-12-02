# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ChaiApp is a BV-BRC module that integrates Chai Lab (protein structure prediction) into the BV-BRC ecosystem. It follows the `dev_container` infrastructure pattern used across BV-BRC components.

## Build Commands

```bash
# Build binaries (compiles Perl scripts from scripts/ and service-scripts/)
make all

# Deploy client components (libs, scripts, docs)
make deploy-client

# Deploy service components (includes app_specs)
make deploy-service

# Full deployment
make deploy
```

The build system expects `TOP_DIR` to point to the dev_container root (defaults to `../..`) and uses common rules from `$(TOP_DIR)/tools/Makefile.common`.

## Architecture

- **app_specs/**: Application specification files for the BV-BRC app service
- **scripts/**: Client-side Perl scripts (`.pl` files compiled to `$(BIN_DIR)`)
- **service-scripts/**: Backend/server-side Perl and Python scripts
- **lib/**: Perl modules
- **container/**: Docker build files for Chai Lab environment
  - `Dockerfile.chailab`: Ubuntu 22.04 base with Python 3.10 and Chai Lab dependencies
  - `Dockerfile.cuda`: NVIDIA CUDA 12.1 variant for GPU support

## Container Build

```bash
# Build GPU-enabled container
docker build --platform linux/amd64 -f container/Dockerfile.cuda -t dxkb/chai-lab:latest-gpu container/
```

Containers use `uv` for Python package management with dependencies from `requirements.in`.

## Testing

Test files follow BV-BRC conventions:
- `t/client-tests/*.t` - Client-side tests
- `t/server-tests/*.t` - Server-side tests
- `t/prod-tests/*.t` - Production tests

## Deployment Paths

- Runtime: `/kb/runtime` (configurable via `DEPLOY_RUNTIME`)
- Target: `/kb/deployment` (configurable via `TARGET`)
- App specs deploy to: `$(TARGET)/services/app_service/app_specs`
