#!/usr/bin/env bash
set -euo pipefail

APP_BUNDLE="${FATCAT_ELECTRON_APP_PATH:-}"
if [[ -z "$APP_BUNDLE" ]]; then
  echo "SKIP: set FATCAT_ELECTRON_APP_PATH to a packaged Electron .app bundle" >&2
  exit 0
fi
if [[ "$(basename "$APP_BUNDLE")" != *.app || ! -d "$APP_BUNDLE" ]]; then
  echo "Electron launcher smoke requires a valid .app bundle: $APP_BUNDLE" >&2
  exit 2
fi

bundle_name="$(basename "$APP_BUNDLE" .app)"
process_pattern="$APP_BUNDLE/Contents/MacOS"
before="$(pgrep -f "$process_pattern" || true)"
open "$APP_BUNDLE"
for _ in {1..30}; do
  pids="$(pgrep -f "$process_pattern" || true)"
  [[ -n "$pids" ]] && break
  sleep 0.2
done
[[ -n "${pids:-}" ]] || { echo "Electron workspace did not launch: $bundle_name" >&2; exit 1; }

open "$APP_BUNDLE"
sleep 0.5
after="$(pgrep -f "$process_pattern" || true)"
before_count="$(printf '%s\n' "$before" | awk 'NF { count += 1 } END { print count + 0 }')"
after_count="$(printf '%s\n' "$after" | awk 'NF { count += 1 } END { print count + 0 }')"
if (( after_count > before_count + 1 )); then
  echo "Electron launcher started more than one matching app process: $after" >&2
  exit 1
fi
echo "Electron launcher smoke passed: one reusable app process ($after_count matching process(es))."
