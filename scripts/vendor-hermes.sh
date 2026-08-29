#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE="${PEPPA_HERMES_SOURCE:-$HOME/.hermes/hermes-agent}"
VENDOR="$REPO_ROOT/vendor/hermes"
EXPECTED_COMMIT="533886c8b8eb67ff8b389b7f48e7d5e5d9c575b9"

fail() { echo "Hermes vendor sync failed: $1" >&2; exit 1; }

[[ -d "$SOURCE/.git" ]] || fail "Hermes source is not a git checkout: $SOURCE"
[[ -f "$SOURCE/run_agent.py" ]] || fail "Hermes source is missing run_agent.py: $SOURCE"

actual_commit="$(git -C "$SOURCE" rev-parse HEAD)"
if [[ "$actual_commit" != "$EXPECTED_COMMIT" && "${PEPPA_ALLOW_HERMES_COMMIT_MISMATCH:-0}" != "1" ]]; then
  fail "source is $actual_commit; expected $EXPECTED_COMMIT"
fi

if [[ "${PEPPA_ALLOW_DIRTY_HERMES_SOURCE:-0}" != "1" ]]; then
  [[ -z "$(git -C "$SOURCE" status --porcelain)" ]] || fail "source checkout is dirty; set PEPPA_ALLOW_DIRTY_HERMES_SOURCE=1 only for a deliberate snapshot"
fi

if [[ -e "$VENDOR" ]]; then
  [[ "${PEPPA_ALLOW_VENDOR_OVERWRITE:-0}" == "1" ]] || fail "vendor tree already exists; set PEPPA_ALLOW_VENDOR_OVERWRITE=1 to replace it"
  rm -rf "$VENDOR"
fi

mkdir -p "$VENDOR"
rsync -a \
  --exclude '.git/' \
  --exclude 'node_modules/' \
  --exclude 'venv/' \
  --exclude '.hermes-runtime/' \
  --exclude 'tests/' \
  --exclude 'tests-js/' \
  --exclude 'apps/' \
  --exclude 'website/' \
  --exclude 'web/' \
  --exclude 'ui-tui/' \
  --exclude '.github/' \
  --exclude 'docs/' \
  --exclude 'evals/' \
  --exclude 'optional-mcps/' \
  --exclude 'mcp-research-data/' \
  --exclude 'docker/' \
  --exclude 'nix/' \
  --exclude 'contributors/' \
  --exclude 'datagen-config-examples/' \
  --exclude 'cron/' \
  --exclude 'tui_gateway/' \
  --exclude 'hermes_agent.egg-info/' \
  --exclude '__pycache__/' \
  --exclude '*.pyc' \
  --exclude '.env' \
  --exclude 'auth.json' \
  "$SOURCE/" "$VENDOR/"

cp "$SOURCE/LICENSE" "$VENDOR/LICENSE"
printf '%s\n' "$actual_commit" > "$VENDOR/FATCAT_HERMES_COMMIT"
echo "Vendored Hermes source at $actual_commit into $VENDOR"
