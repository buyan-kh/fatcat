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

test_parent="$(mktemp -d /tmp/fatcat-hermes-bundle.XXXXXX)"
cleanup() { rm -rf "$test_parent"; }
trap cleanup EXIT
stage="$test_parent/PeppaAgent"
unset PEPPA_HERMES_SOURCE FATCAT_HERMES_PATH PEPPA_HERMES_BUILD_SOURCE
"$ROOT/scripts/build-peppa-agent.sh" "$stage"
require_file "$stage/PeppaAgent"
require_file "$stage/PEPPA_HERMES_COMMIT"
if find "$stage" -type f \( -name 'auth.json' -o -name '.env' -o -name '*.pyc' \) -print -quit | rg .; then
  echo "personal config or generated Python bytecode leaked into staged agent" >&2
  exit 1
fi
developer_path_matches="$(find "$stage" -type f ! -name '*.pyc' -print0 | xargs -0 rg -l '/Users/buyan/.hermes|/Users/buyan/.codex' || true)"
if [[ -n "$developer_path_matches" ]]; then
  echo "developer-specific absolute path leaked into staged agent" >&2
  echo "$developer_path_matches" >&2
  exit 1
fi
socket="$test_parent/agent.sock"
home="$test_parent/hermes-home"
"$stage/PeppaAgent" --socket "$socket" --hermes-home "$home" >/dev/null 2>&1 &
agent_pid=$!
for _ in $(seq 1 50); do
  [[ -S "$socket" ]] && break
  kill -0 "$agent_pid" 2>/dev/null || { wait "$agent_pid" || true; echo "bundled PeppaAgent exited before opening its socket" >&2; exit 1; }
  sleep 0.1
done
[[ -S "$socket" ]] || { kill "$agent_pid" 2>/dev/null || true; wait "$agent_pid" || true; echo "bundled PeppaAgent did not start" >&2; exit 1; }
"$stage/runtime/bin/python3" - "$socket" <<'PY'
import json
import socket
import sys

path = sys.argv[1]
client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
client.connect(path)
reader = client.makefile("r")

def request(payload):
    client.sendall((json.dumps(payload, separators=(",", ":")) + "\n").encode())
    return json.loads(reader.readline())

hello = request({"version": 1, "type": "hello", "client": "native_pet"})
assert hello["type"] == "hello_ack"
snapshot = json.loads(reader.readline())
assert snapshot["type"] == "conversation_snapshot"
inventory = request({"version": 1, "type": "provider_inventory", "request_id": "inventory"})
assert [row["slug"] for row in inventory["providers"]] == ["openai-codex", "openai-api", "anthropic"]
assert all("api_key" not in row and "secret" not in row for row in inventory["providers"])
selected = request({"version": 1, "type": "provider_set_default", "request_id": "default", "provider_id": "openai-codex", "model": "gpt-5"})
assert selected["type"] == "provider_configured"
invalid = request({"version": 1, "type": "provider_set_default", "request_id": "invalid", "provider_id": "not-supported", "model": "bad"})
assert invalid["type"] == "error"
after = request({"version": 1, "type": "provider_inventory", "request_id": "after"})
codex = next(row for row in after["providers"] if row["slug"] == "openai-codex")
assert codex["is_default"] == "true" and codex["default_model"] == "gpt-5"
shutdown = request({"version": 1, "type": "shutdown"})
assert shutdown["type"] == "shutdown_ack"
client.close()
PY
wait "$agent_pid" || true
echo "Vendored Hermes source contract passed"
