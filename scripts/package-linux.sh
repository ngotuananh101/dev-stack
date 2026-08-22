#!/usr/bin/env bash
set -e

echo "Building DevStack for Linux..."
flutter build linux --release

echo "Packaging into tarball..."
mkdir -p dist
tar -czf dist/ponta-dev-stack-linux-x64.tar.gz -C build/linux/x64/release/bundle .

echo "Build complete: dist/ponta-dev-stack-linux-x64.tar.gz"
