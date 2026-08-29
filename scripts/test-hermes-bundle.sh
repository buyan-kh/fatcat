#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/vendor/hermes"

require_dir() { if [[ ! -d "$1" ]]; then echo "missing directory: $1" >&2; exit 1; fi; }
require_file() { if [[ ! -f "$1" ]]; then echo "missing file: $1" >&2; exit 1; fi; }

require_dir "$VENDOR"
require_file "$VENDOR/run_agent.py"
require_file "$VENDOR/hermes_cli/auth.py"
require_file "$VENDOR/hermes_cli/models.py"
require_file "$VENDOR/acp_adapter/server.py"
require_file "$VENDOR/plugins/model-providers/openai-codex/__init__.py"
require_file "$VENDOR/LICENSE"
commit_file="$VENDOR/FATCAT_HERMES_COMMIT"
require_file "$commit_file"
if [[ "$(<"$commit_file")" != "533886c8b8eb67ff8b389b7f48e7d5e5d9c575b9" ]]; then
  echo "unexpected Hermes commit" >&2
  exit 1
fi
if [[ -d "$VENDOR/.git" || -d "$VENDOR/node_modules" || -d "$VENDOR/venv" || -d "$VENDOR/.hermes-runtime" ]]; then
  echo "build artifacts leaked into vendored Hermes source" >&2
  exit 1
fi
! find "$VENDOR" -type f \( -name 'auth.json' -o -name '.env' \) -print -quit | rg .
echo "Vendored Hermes source contract passed"
