#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Rebuild in the default brand-free mode; never package stale local-icons output.
bash build.sh review
mkdir -p dist
ditto -c -k --keepParent 'build/AI Dock.app' 'dist/AI-Dock-review-macos.zip'
python3 scripts/source-package.py
shasum -a 256 dist/*.zip > dist/SHA256SUMS.txt
