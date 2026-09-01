#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NATIVE_ROOT="$REPO_ROOT/macos/FatCat"
APP_BUNDLE="$NATIVE_ROOT/.build/FatCat.app"
npm --prefix "$REPO_ROOT" run build:avatar
swift build --configuration release --package-path "$NATIVE_ROOT"
BIN_DIR="$(swift build --configuration release --package-path "$NATIVE_ROOT" --show-bin-path)"

running_app_pattern="$APP_BUNDLE/Contents/MacOS/FatCat"
running_agent_pattern="$APP_BUNDLE/Contents/Resources/FatCatAgent/runtime/bin/python3 -m fatcat_agent.server"
pkill -f "$running_app_pattern" 2>/dev/null || true
pkill -f "$running_agent_pattern" 2>/dev/null || true
sleep 1

if [[ -e "$APP_BUNDLE" ]]; then
  mv "$APP_BUNDLE" "$APP_BUNDLE.previous.$$.bundle"
fi
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BIN_DIR/FatCat" "$APP_BUNDLE/Contents/MacOS/FatCat"
cp "$NATIVE_ROOT/AppInfo.plist" "$APP_BUNDLE/Contents/Info.plist"
cp -R "$BIN_DIR/FatCat_FatCat.bundle" "$APP_BUNDLE/Contents/Resources/"
"$SCRIPT_DIR/build-fatcat-agent.sh" "$APP_BUNDLE/Contents/Resources/FatCatAgent"
mkdir -p "$APP_BUNDLE/Contents/Resources/protocol-schemas" "$APP_BUNDLE/Contents/Resources/default-skills"
cp "$REPO_ROOT/protocol/fatcat-events.schema.json" "$APP_BUNDLE/Contents/Resources/protocol-schemas/"
cp "$REPO_ROOT/agent/default-skills/README.md" "$APP_BUNDLE/Contents/Resources/default-skills/"

if security find-identity -v -p codesigning 2>/dev/null | rg -q '^[[:space:]]*[0-9]+\)'; then
  signing_identity="$(security find-identity -v -p codesigning | awk -F '"' '/^[[:space:]]*[0-9]+\)/ { print $2; exit }')"
  codesign --force --deep --sign "$signing_identity" "$APP_BUNDLE"
else
  codesign --force --deep --sign - "$APP_BUNDLE"
fi

"$SCRIPT_DIR/verify-fatcat-macos-app.sh" "$APP_BUNDLE"
"$SCRIPT_DIR/package-fatcat-dmg.sh" "$APP_BUNDLE"
FATCAT_AGENT_PATH="$APP_BUNDLE/Contents/Resources/FatCatAgent/FatCatAgent" \
  "$SCRIPT_DIR/install-fatcat-launch-agent.sh"
open -a "$APP_BUNDLE"
echo "Launched $APP_BUNDLE"
