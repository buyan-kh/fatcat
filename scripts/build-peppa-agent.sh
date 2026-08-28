#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HERMES_SOURCE="${PEPPA_HERMES_SOURCE:-/Users/$(id -un)/.hermes/hermes-agent}"
EXPECTED_COMMIT="533886c8b8eb67ff8b389b7f48e7d5e5d9c575b9"
STAGE_DIR="${1:?usage: build-peppa-agent.sh <stage-dir>}"

if [[ ! -d "$HERMES_SOURCE" || ! -f "$HERMES_SOURCE/run_agent.py" ]]; then
  echo "Hermes source not found at $HERMES_SOURCE" >&2
  exit 1
fi
actual_commit="$(git -C "$HERMES_SOURCE" rev-parse HEAD)"
if [[ "$actual_commit" != "$EXPECTED_COMMIT" && "${PEPPA_ALLOW_HERMES_COMMIT_MISMATCH:-0}" != "1" ]]; then
  echo "Hermes source is $actual_commit; expected pinned commit $EXPECTED_COMMIT" >&2
  exit 1
fi

PYTHON_RUNTIME="$(find "$HERMES_SOURCE/.hermes-runtime/python" -maxdepth 2 -type d -name 'cpython-3.11.*-macos-aarch64-none' -print -quit)"
[[ -n "$PYTHON_RUNTIME" ]] || { echo "Bundled CPython 3.11 runtime not found" >&2; exit 1; }
[[ -d "$HERMES_SOURCE/venv/lib/python3.11/site-packages" ]] || { echo "Hermes Python dependencies are not installed" >&2; exit 1; }

if [[ -e "$STAGE_DIR" ]]; then
  echo "Refusing to overwrite existing PeppaAgent staging directory: $STAGE_DIR" >&2
  exit 1
fi
mkdir -p "$STAGE_DIR"
rsync -a --exclude '.git' --exclude 'node_modules' --exclude 'tests' --exclude 'tests-js' --exclude '__pycache__' --exclude '*.pyc' --exclude '.hermes-runtime' --exclude 'venv' --exclude 'apps/desktop' --exclude 'apps/bootstrap-installer' --exclude 'website' --exclude 'web' --exclude 'ui-tui' "$HERMES_SOURCE/" "$STAGE_DIR/"
mkdir -p "$STAGE_DIR/runtime" "$STAGE_DIR/venv"
rsync -aL "$PYTHON_RUNTIME/" "$STAGE_DIR/runtime/"
rsync -a --exclude 'bin' "$HERMES_SOURCE/venv/" "$STAGE_DIR/venv/"
rsync -a "$REPO_ROOT/agent/peppa_agent" "$STAGE_DIR/"
cp "$REPO_ROOT/agent/peppa_agent/PeppaAgent" "$STAGE_DIR/PeppaAgent"
chmod 755 "$STAGE_DIR/PeppaAgent"
cp "$REPO_ROOT/agent/README.md" "$STAGE_DIR/PEPPA_AGENT.md"
echo "$actual_commit" > "$STAGE_DIR/PEPPA_HERMES_COMMIT"
echo "Staged PeppaAgent with Hermes commit $actual_commit"
