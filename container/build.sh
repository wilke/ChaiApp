#!/bin/bash
#
# Build script for Chai-Lab BV-BRC container
# Automatically captures git metadata and build timestamp
#
# Usage:
#   ./build.sh              # Build with default tag (test)
#   ./build.sh latest-gpu   # Build with specific tag
#   ./build.sh --push       # Build and push to DockerHub
#

set -e

# Configuration
IMAGE_NAME="dxkb/chai-bvbrc"
DEFAULT_TAG="test"
DOCKERFILE="Dockerfile.chai-bvbrc"

# Parse arguments
TAG="${1:-$DEFAULT_TAG}"
PUSH=false

if [[ "$1" == "--push" ]]; then
    TAG="${2:-latest-gpu}"
    PUSH=true
elif [[ "$2" == "--push" ]]; then
    PUSH=true
fi

# Change to repository root (parent of container/)
cd "$(dirname "$0")/.."

# Capture build metadata
BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
GIT_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
GIT_COMMIT_SHORT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
VERSION="2.1.0"

# Generate date-based tag
DATE_TAG=$(date +%Y%m%d)-${GIT_COMMIT_SHORT}

echo "=============================================="
echo "Building ${IMAGE_NAME}:${TAG}"
echo "=============================================="
echo "Build Date:  ${BUILD_DATE}"
echo "Git Commit:  ${GIT_COMMIT}"
echo "Git Branch:  ${GIT_BRANCH}"
echo "Version:     ${VERSION}"
echo "Date Tag:    ${DATE_TAG}"
echo "=============================================="

# Build the image
docker build --platform linux/amd64 \
    --build-arg BUILD_DATE="${BUILD_DATE}" \
    --build-arg GIT_COMMIT="${GIT_COMMIT}" \
    --build-arg GIT_BRANCH="${GIT_BRANCH}" \
    --build-arg VERSION="${VERSION}" \
    -t "${IMAGE_NAME}:${TAG}" \
    -t "${IMAGE_NAME}:${DATE_TAG}" \
    -f container/${DOCKERFILE} \
    .

echo ""
echo "=============================================="
echo "Build complete!"
echo "=============================================="
echo "Images created:"
echo "  ${IMAGE_NAME}:${TAG}"
echo "  ${IMAGE_NAME}:${DATE_TAG}"
echo ""

# Verify build metadata
echo "Verifying build metadata..."
docker inspect "${IMAGE_NAME}:${TAG}" --format='
Labels:
  build.date:       {{index .Config.Labels "build.date"}}
  build.git.commit: {{index .Config.Labels "build.git.commit"}}
  build.git.branch: {{index .Config.Labels "build.git.branch"}}
  app.version:      {{index .Config.Labels "app.version"}}
'

# Show BUILD_INFO file
echo "BUILD_INFO contents:"
docker run --rm "${IMAGE_NAME}:${TAG}" cat /kb/module/BUILD_INFO

# Push if requested
if [[ "$PUSH" == "true" ]]; then
    echo ""
    echo "Pushing to DockerHub..."
    docker push "${IMAGE_NAME}:${TAG}"
    docker push "${IMAGE_NAME}:${DATE_TAG}"
    echo "Push complete!"
fi

echo ""
echo "To test locally:"
echo "  docker run --rm ${IMAGE_NAME}:${TAG} chai-lab --help"
echo "  docker run --rm ${IMAGE_NAME}:${TAG} cat /kb/module/BUILD_INFO"
echo ""
echo "To push manually:"
echo "  docker push ${IMAGE_NAME}:${TAG}"
echo "  docker push ${IMAGE_NAME}:${DATE_TAG}"
