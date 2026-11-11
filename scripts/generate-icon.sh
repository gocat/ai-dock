#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/module-cache
swiftc -module-cache-path build/module-cache -framework AppKit Resources/GenerateIcon.swift -o build/generate-icon
build/generate-icon build/Companion.iconset
iconutil -c icns build/Companion.iconset -o build/Companion.icns
