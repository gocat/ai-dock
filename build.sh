#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mode="${1:-review}"
if [[ "$mode" != review && "$mode" != local-icons ]]; then
  echo 'Usage: bash build.sh [review|local-icons]' >&2
  exit 2
fi
app='build/AI Dock.app'
bundle_id="${AI_DOCK_BUNDLE_ID:-app.aidock.desktop}"
arch="$(uname -m)"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" build/module-cache
# Always start from a clean resource set so private preview assets cannot leak.
find "$app/Contents/Resources" -maxdepth 1 -type f -delete
bash scripts/generate-icon.sh
cp build/Companion.icns "$app/Contents/Resources/Companion.icns"
if [[ "$mode" == local-icons ]]; then
  cp Resources/CodexMono.svg Resources/ClashMono.svg "$app/Contents/Resources/"
fi
swiftc -swift-version 5 -O -target "${arch}-apple-macos14.0" -module-cache-path build/module-cache -framework AppKit Sources/main.swift Sources/Localization.swift -o "$app/Contents/MacOS/CodexCompanion"
python3 - "$app/Contents/Info.plist" "$bundle_id" <<'PY'
import plistlib,sys
info={'CFBundleExecutable':'CodexCompanion','CFBundleIdentifier':sys.argv[2],
      'CFBundleName':'AI Dock','CFBundleDisplayName':'AI Dock','CFBundleIconFile':'Companion',
      'CFBundlePackageType':'APPL','LSApplicationCategoryType':'public.app-category.utilities',
      'CFBundleVersion':'31','CFBundleShortVersionString':'1.0.0-rc.10','LSMinimumSystemVersion':'14.0',
      'LSUIElement':True,'NSHighResolutionCapable':True}
with open(sys.argv[1],'wb') as f:plistlib.dump(info,f)
PY
# Sign outside the repository. In synced or file-provider-managed folders the
# bundle metadata is re-added right after a clean-up, so codesign intermittently
# fails with "resource fork, Finder information, or similar detritus not allowed".
# Signing a copy in TMPDIR and copying the finished bundle back avoids the race.
sign_dir="$(mktemp -d "${TMPDIR:-/tmp}/aidock-sign.XXXXXX")"
trap 'rm -rf "$sign_dir"' EXIT
ditto "$app" "$sign_dir/AI Dock.app"
xattr -cr "$sign_dir/AI Dock.app"
codesign --force --sign - "$sign_dir/AI Dock.app"
codesign --verify --deep --strict "$sign_dir/AI Dock.app"
rm -rf "$app"
ditto "$sign_dir/AI Dock.app" "$app"
# The repository copy is not re-verified: this folder can regain provider metadata
# asynchronously, which makes `codesign --verify` flaky on it. The scratch copy
# above and the installer's staged copy are the ones that are checked.
"$app/Contents/MacOS/CodexCompanion" --self-test
