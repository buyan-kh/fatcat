#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_BUNDLE="${1:-$REPO_ROOT/macos/PeppaAnywhere/.build/FatCat.app}"
OUTPUT="${2:-$REPO_ROOT/dist/FatCat.dmg}"

[[ -d "$APP_BUNDLE" ]] || { echo "FatCat.app not found: $APP_BUNDLE" >&2; exit 1; }
"$SCRIPT_DIR/verify-peppa-macos-app.sh" "$APP_BUNDLE"
mkdir -p "$(dirname "$OUTPUT")"
hdiutil create -volname FatCat -srcfolder "$APP_BUNDLE" -ov -format UDZO "$OUTPUT" >/dev/null
echo "Created $OUTPUT"
