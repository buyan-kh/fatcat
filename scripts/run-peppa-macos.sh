#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

"$SCRIPT_DIR/prepare-peppa-web-assets.sh"
cd "$REPO_ROOT/macos/PeppaAnywhere"
swift run

