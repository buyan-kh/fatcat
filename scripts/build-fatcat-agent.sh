#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HERMES_SOURCE="${FATCAT_HERMES_SOURCE:-$REPO_ROOT/vendor/hermes}"
HERMES_BUILD_SOURCE="${FATCAT_HERMES_BUILD_SOURCE:-/Users/$(id -un)/.hermes/hermes-agent}"
EXPECTED_COMMIT="533886c8b8eb67ff8b389b7f48e7d5e5d9c575b9"
STAGE_DIR="${1:?usage: build-fatcat-agent.sh <stage-dir>}"

if [[ ! -d "$HERMES_SOURCE" || ! -f "$HERMES_SOURCE/run_agent.py" ]]; then
  echo "Hermes source not found at $HERMES_SOURCE" >&2
  exit 1
fi
if [[ -f "$HERMES_SOURCE/FATCAT_HERMES_COMMIT" ]]; then
  actual_commit="$(<"$HERMES_SOURCE/FATCAT_HERMES_COMMIT")"
else
  actual_commit="$(git -C "$HERMES_SOURCE" rev-parse HEAD)"
fi
if [[ "$actual_commit" != "$EXPECTED_COMMIT" && "${FATCAT_ALLOW_HERMES_COMMIT_MISMATCH:-0}" != "1" ]]; then
  echo "Hermes source is $actual_commit; expected pinned commit $EXPECTED_COMMIT" >&2
  exit 1
fi

[[ -d "$HERMES_BUILD_SOURCE" ]] || { echo "Hermes runtime source is not available at $HERMES_BUILD_SOURCE; set FATCAT_HERMES_BUILD_SOURCE on the build machine" >&2; exit 1; }
PYTHON_RUNTIME="$(find "$HERMES_BUILD_SOURCE/.hermes-runtime/python" -maxdepth 2 -type d -name 'cpython-3.11.*-macos-aarch64-none' -print -quit)"
[[ -n "$PYTHON_RUNTIME" ]] || { echo "Bundled CPython 3.11 runtime not found" >&2; exit 1; }
[[ -d "$HERMES_BUILD_SOURCE/venv/lib/python3.11/site-packages" ]] || { echo "Hermes Python dependencies are not installed" >&2; exit 1; }

if [[ -e "$STAGE_DIR" ]]; then
  echo "Refusing to overwrite existing FatCatAgent staging directory: $STAGE_DIR" >&2
  exit 1
fi
mkdir -p "$STAGE_DIR"
rsync -a --exclude '.git' --exclude 'node_modules' --exclude 'tests' --exclude 'tests-js' --exclude '__pycache__' --exclude '*.pyc' --exclude '.hermes-runtime' --exclude 'venv' --exclude 'apps' --exclude 'website' --exclude 'web' --exclude 'ui-tui' "$HERMES_SOURCE/" "$STAGE_DIR/"
mkdir -p "$STAGE_DIR/runtime" "$STAGE_DIR/venv"
rsync -aL --exclude '__pycache__/' --exclude '*.pyc' "$PYTHON_RUNTIME/" "$STAGE_DIR/runtime/"
rsync -a --exclude 'bin' --exclude 'pyvenv.cfg' --exclude '__pycache__/' --exclude '*.pyc' --exclude '__editable__*' --exclude 'hermes_agent-*.dist-info/' "$HERMES_BUILD_SOURCE/venv/" "$STAGE_DIR/venv/"
sysconfig_data="$(find "$STAGE_DIR/runtime/lib/python3.11" -maxdepth 1 -name '_sysconfigdata_*.py' -print -quit)"
if [[ -n "$sysconfig_data" ]]; then
  sed -i '' "s|$PYTHON_RUNTIME|$STAGE_DIR/runtime|g" "$sysconfig_data"
fi
if command -v install_name_tool >/dev/null 2>&1 && [[ -f "$STAGE_DIR/runtime/lib/libpython3.11.dylib" ]]; then
  install_name_tool -id '@rpath/libpython3.11.dylib' "$STAGE_DIR/runtime/lib/libpython3.11.dylib"
fi
rsync -a --exclude '__pycache__/' --exclude '*.pyc' "$REPO_ROOT/agent/fatcat_agent" "$STAGE_DIR/"
cp "$REPO_ROOT/agent/fatcat_agent/FatCatAgent" "$STAGE_DIR/FatCatAgent"
chmod 755 "$STAGE_DIR/FatCatAgent"
cp "$REPO_ROOT/agent/README.md" "$STAGE_DIR/FATCAT_AGENT.md"
echo "$actual_commit" > "$STAGE_DIR/FATCAT_HERMES_COMMIT"
echo "Staged FatCatAgent with Hermes commit $actual_commit"
