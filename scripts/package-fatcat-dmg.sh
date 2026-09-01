#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_BUNDLE="${1:-$REPO_ROOT/macos/FatCat/.build/FatCat.app}"
OUTPUT="${2:-$REPO_ROOT/dist/FatCat.dmg}"
ELECTRON_APP_BUNDLE="${3:-$REPO_ROOT/macos/FatCat/.build/FatCat Electron.app}"

[[ -d "$APP_BUNDLE" ]] || { echo "FatCat.app not found: $APP_BUNDLE" >&2; exit 1; }
[[ -d "$ELECTRON_APP_BUNDLE" ]] || { echo "FatCat Electron.app not found: $ELECTRON_APP_BUNDLE" >&2; exit 1; }
"$SCRIPT_DIR/verify-fatcat-macos-app.sh" "$APP_BUNDLE"
mkdir -p "$(dirname "$OUTPUT")"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/fatcat-dmg.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP_BUNDLE" "$STAGING/FatCat.app"
cp -R "$ELECTRON_APP_BUNDLE" "$STAGING/FatCat Electron.app"
hdiutil create -volname FatCat -srcfolder "$STAGING" -ov -format UDZO "$OUTPUT" >/dev/null
echo "Created $OUTPUT"
