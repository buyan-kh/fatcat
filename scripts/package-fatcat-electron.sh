#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ELECTRON_ROOT="$REPO_ROOT/electron"
NATIVE_ROOT="$REPO_ROOT/macos/FatCat"
RUNTIME_APP="$ELECTRON_ROOT/node_modules/electron/dist/Electron.app"
APP_BUNDLE="$NATIVE_ROOT/.build/FatCat Electron.app"
APP_RESOURCES="$APP_BUNDLE/Contents/Resources"

npm --prefix "$ELECTRON_ROOT" run build
[[ -d "$RUNTIME_APP" ]] || { echo "Electron runtime app not found at $RUNTIME_APP" >&2; exit 1; }
[[ -f "$ELECTRON_ROOT/out/main/index.js" ]] || { echo "Electron main bundle was not built" >&2; exit 1; }
[[ -f "$ELECTRON_ROOT/out/renderer/index.html" ]] || { echo "Electron renderer bundle was not built" >&2; exit 1; }

if [[ -e "$APP_BUNDLE" ]]; then
  mv "$APP_BUNDLE" "$APP_BUNDLE.previous.$$.bundle"
fi
cp -R "$RUNTIME_APP" "$APP_BUNDLE"
mkdir -p "$APP_RESOURCES/app"
cp "$ELECTRON_ROOT/package.json" "$APP_RESOURCES/app/package.json"
cp -R "$ELECTRON_ROOT/out" "$APP_RESOURCES/app/"

codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null
echo "Packaged Electron workspace at $APP_BUNDLE"
