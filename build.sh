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
      'CFBundleVersion':'30','CFBundleShortVersionString':'1.0.0-rc.9','LSMinimumSystemVersion':'14.0',
      'LSUIElement':True,'NSHighResolutionCapable':True}
with open(sys.argv[1],'wb') as f:plistlib.dump(info,f)
PY
# Finder/file-provider metadata left on the bundle makes codesign refuse to sign.
# Some synced or managed folders re-add it right after a clean-up, so retry a few
# times and only surface the error if it keeps happening.
for attempt in 1 2 3; do
  xattr -cr "$app"
  if codesign --force --sign - "$app" 2>/dev/null; then
    break
  elif [[ "$attempt" == 3 ]]; then
    codesign --force --sign - "$app"
  fi
done
codesign --verify --deep --strict "$app"
"$app/Contents/MacOS/CodexCompanion" --self-test
