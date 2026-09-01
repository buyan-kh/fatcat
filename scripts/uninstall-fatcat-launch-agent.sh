#!/usr/bin/env bash
set -euo pipefail

label="com.fatcat.agent"
domain="gui/$(id -u)"
plist_path="${HOME}/Library/LaunchAgents/${label}.plist"

launchctl bootout "${domain}/${label}" 2>/dev/null || true
rm -f "${plist_path}"

echo "FatCat Agent LaunchAgent removed. Conversations and Hermes data were preserved."
