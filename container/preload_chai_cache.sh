#!/bin/bash
#
# preload_chai_cache.sh - Download all Chai-Lab model weights and cache files
#
# Usage: ./preload_chai_cache.sh [CACHE_DIR]
#        CACHE_DIR defaults to /cache or $CHAI_DOWNLOADS_DIR
#
# This script downloads all required Chai-Lab artifacts so they don't need
# to be downloaded at runtime. Useful for:
#   - Building containers with pre-cached weights
#   - Air-gapped environments
#   - Faster job startup times

set -e

CACHE_DIR="${1:-${CHAI_DOWNLOADS_DIR:-/cache}}"
BASE_URL="https://chaiassets.com/chai1-inference-depencencies"

echo "Preloading Chai-Lab cache to: $CACHE_DIR"

# Create directory structure
mkdir -p "$CACHE_DIR/models_v2"
mkdir -p "$CACHE_DIR/esm"

# Conformer cache file
echo "Downloading conformers_v1.apkl..."
curl -fSL "$BASE_URL/conformers_v1.apkl" -o "$CACHE_DIR/conformers_v1.apkl"

# Model weight files
MODEL_FILES=(
    "feature_embedding.pt"
    "bond_loss_input_proj.pt"
    "token_embedder.pt"
    "trunk.pt"
    "diffusion_module.pt"
    "confidence_head.pt"
)

for model in "${MODEL_FILES[@]}"; do
    echo "Downloading models_v2/$model..."
    curl -fSL "$BASE_URL/models_v2/$model" -o "$CACHE_DIR/models_v2/$model"
done

# ESM2 embedding model (~6GB, required for protein embeddings)
echo "Downloading ESM2 model (this is large, ~6GB)..."
curl -fSL "$BASE_URL/esm2/traced_sdpa_esm2_t36_3B_UR50D_fp16.pt" -o "$CACHE_DIR/esm/traced_sdpa_esm2_t36_3B_UR50D_fp16.pt"

echo ""
echo "Chai-Lab cache preloaded successfully!"
echo "Total files: $((${#MODEL_FILES[@]} + 2))"  # +2 for conformers and ESM
du -sh "$CACHE_DIR"
