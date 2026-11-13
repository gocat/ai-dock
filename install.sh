#!/bin/bash
# Build from source on your own Mac. No sudo, account tokens or network changes.
set -euo pipefail
launch=1
check_only=0
source_dir=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-open) launch=0 ;;
    --check) check_only=1 ;;
    --source) shift; [[ $# -gt 0 ]] || { echo 'Missing --source path' >&2; exit 2; }; source_dir="$1" ;;
    --help) echo 'Usage: bash install.sh [--check] [--no-open] [--source PATH]'; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
fail() { printf 'AI Dock: %s\n' "$*" >&2; exit 1; }
[[ "$(uname -s)" == Darwin ]] || fail 'macOS is required / 仅支持 macOS。'
version="$(sw_vers -productVersion)"
[[ "${version%%.*}" -ge 14 ]] || fail 'macOS 14 or later is required / 需要 macOS 14 或更新系统。'
if ! xcode-select -p >/dev/null 2>&1 || ! xcrun --find swiftc >/dev/null 2>&1; then
  fail 'Install Apple Command Line Tools with: xcode-select --install ; then rerun. / 请先运行该命令安装苹果编译工具，再重试。'
fi
for tool in python3 curl tar ditto codesign iconutil; do
  command -v "$tool" >/dev/null 2>&1 || fail "Missing tool: $tool / 缺少工具：$tool"
done
if [[ ! -x /Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex ]]; then
  printf '%s\n' 'Note: this version reads quota through the Codex CLI bundled in ChatGPT.app. Without it, quota is unavailable; network checks still work.' '提示：此版本依赖 ChatGPT.app 内置 Codex CLI 读取额度；缺少时额度不可用，网络检测仍可用。'
fi
[[ "$check_only" == 0 ]] || { echo 'Build prerequisites passed / 编译环境检查通过。'; exit 0; }
if [[ -z "$source_dir" && -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  candidate="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  [[ ! -f "$candidate/build.sh" ]] || source_dir="$candidate"
fi
install_dir="${AI_DOCK_INSTALL_DIR:-$HOME/Applications}"
if [[ -z "${AI_DOCK_INSTALL_DIR:-}" && -d '/Applications/AI Dock.app' ]]; then
  [[ ! -d "$HOME/Applications/AI Dock.app" ]] || fail 'Two installations found; choose one with AI_DOCK_INSTALL_DIR. / 发现两个安装位置，请指定更新位置。'
  install_dir='/Applications'
fi
if [[ "$launch" == 1 ]] && pgrep -x CodexCompanion >/dev/null 2>&1; then
  fail 'Quit AI Dock, then rerun to update. / 请先退出 AI Dock，再运行以更新。'
fi
mkdir -p "$install_dir"
[[ -w "$install_dir" ]] || fail "Install folder is not writable: $install_dir"
target="$install_dir/AI Dock.app"
bundle_id=app.aidock.desktop
if [[ -e "$target" || -L "$target" ]]; then
  if pgrep -x CodexCompanion >/dev/null 2>&1; then
    fail 'Quit AI Dock before replacing an existing installation. / 更新已安装版本前请先退出 AI Dock。'
  fi
  [[ -d "$target" && ! -L "$target" ]] || fail 'Destination is not a regular app folder; leaving it unchanged.'
  executable=$(/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$target/Contents/Info.plist" 2>/dev/null) || fail 'Cannot identify existing app; leaving it unchanged.'
  [[ "$executable" == CodexCompanion ]] || fail 'Destination belongs to another application; leaving it unchanged.'
  bundle_id=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$target/Contents/Info.plist")
fi
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/ai-dock-install.XXXXXX")"
stage=""
cleanup() {
  [[ -z "$stage" || ! -d "$stage" ]] || rm -rf -- "$stage"
  rm -rf -- "$work_dir"
}
trap cleanup EXIT
if [[ -z "$source_dir" ]]; then
  echo 'Downloading source from gocat/ai-dock… / 正在下载源码…'
  curl --fail --location --proto '=https' --tlsv1.2 --connect-timeout 20 --max-time 180 \
    'https://github.com/gocat/ai-dock/archive/refs/heads/main.tar.gz' --output "$work_dir/source.tar.gz"
  mkdir "$work_dir/source"
  tar -xzf "$work_dir/source.tar.gz" --strip-components=1 -C "$work_dir/source"
  source_dir="$work_dir/source"
fi
[[ -f "$source_dir/build.sh" && -f "$source_dir/Sources/main.swift" ]] || fail 'Source folder is incomplete.'
echo 'Building and testing locally… / 正在本机构建和自测…'
(cd "$source_dir" && AI_DOCK_BUNDLE_ID="$bundle_id" bash build.sh review)
stage="$(mktemp -d "$install_dir/.ai-dock-stage.XXXXXX")"
ditto "$source_dir/build/AI Dock.app" "$stage/AI Dock.app"
# Verify the copy that is about to be installed. Synced source folders can regain
# provider metadata, so the source copy is not the right place to check.
xattr -cr "$stage/AI Dock.app"
codesign --verify --deep --strict "$stage/AI Dock.app"
if [[ -d "$target" ]]; then
  backup_dir="$(mktemp -d "$install_dir/.ai-dock-backup.XXXXXX")"
  mv "$target" "$backup_dir/AI Dock.app"
  if ! mv "$stage/AI Dock.app" "$target"; then
    mv "$backup_dir/AI Dock.app" "$target"
    fail 'Install failed; previous application restored.'
  fi
  printf 'Previous app backup / 旧版备份: %s\n' "$backup_dir/AI Dock.app"
else
  mv "$stage/AI Dock.app" "$target"
fi
printf 'Installed / 已安装: %s\n' "$target"
[[ "$launch" == 0 ]] || open "$target"
