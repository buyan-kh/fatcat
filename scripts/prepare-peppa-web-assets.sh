#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WEB_ROOT="$REPO_ROOT/macos/PeppaAnywhere/Sources/PeppaAnywhere/Resources/WebApp"

cd "$REPO_ROOT"
npm run build
mkdir -p "$WEB_ROOT"
rsync -a --delete --exclude README.md "$REPO_ROOT/dist/" "$WEB_ROOT/"
echo "Prepared bundled Peppa web assets in $WEB_ROOT"

