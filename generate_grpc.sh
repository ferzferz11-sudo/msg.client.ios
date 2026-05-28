#!/bin/bash
# generate_grpc.sh — Generate Swift gRPC code from messenger.proto
# Usage: ./generate_grpc.sh
#
# Prerequisites (install via Homebrew):
#   brew install swift-protobuf grpc-swift
#
# This script copies the .proto file from the server repo and generates
# Swift sources for both protobuf messages and gRPC service stubs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROTO_SRC="/Users/paveld/GolandProjects/LavenderMessenger/messenger.proto"
PROTO_GOOGLEAPIS="/Users/paveld/GolandProjects/LavenderMessenger/vendor/github.com/protocolbuffers/protobuf/src"
OUTPUT_DIR="${SCRIPT_DIR}/Sources/Generated"
PROTO_FILE="${SCRIPT_DIR}/messenger.proto"

mkdir -p "${OUTPUT_DIR}"

# Copy proto into project
cp "${PROTO_SRC}" "${PROTO_FILE}"

# Check tools
if ! command -v protoc-gen-swift &> /dev/null; then
    echo "ERROR: protoc-gen-swift not found. Install with: brew install swift-protobuf"
    exit 1
fi

if ! command -v protoc-gen-grpc-swift &> /dev/null; then
    echo "ERROR: protoc-gen-grpc-swift not found. Install with: brew install grpc-swift"
    exit 1
fi

# Check if proto exists
if [ ! -f "${PROTO_FILE}" ]; then
    echo "ERROR: ${PROTO_FILE} not found"
    exit 1
fi

echo "Generating Swift protobuf messages..."
protoc \
    --swift_out="${OUTPUT_DIR}" \
    --proto_path="$(dirname "${PROTO_FILE}")" \
    "${PROTO_FILE}"

echo "Generating Swift gRPC service stubs..."
protoc \
    --grpc-swift_out="${OUTPUT_DIR}" \
    --proto_path="$(dirname "${PROTO_FILE}")" \
    "${PROTO_FILE}"

echo "Done. Generated files:"
ls -la "${OUTPUT_DIR}/"
echo ""
echo "Add these files to your Xcode project (drag into Sources/Generated/)."
