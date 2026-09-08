#!/usr/bin/env bash
set -eo pipefail

IMAGE_NAME="localhost/platform-os:latest"
OUTPUT_DIR="$(pwd)/output"

echo "Building the bootc container image..."
podman build -t "${IMAGE_NAME}" -f Containerfile .

echo "Generating qcow2 disk image from the container image..."
mkdir -p "${OUTPUT_DIR}"

# Run bootc-image-builder to generate the qcow2 image
podman run --rm -it --privileged --pull=newer \
  --security-opt label=type:unconfined_t \
  -v "${OUTPUT_DIR}:/output" \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type qcow2 \
  --local \
  "${IMAGE_NAME}"

echo "Build complete. Check ${OUTPUT_DIR} for the qcow2 image."
