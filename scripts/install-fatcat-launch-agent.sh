#!/usr/bin/env bash
set -euo pipefail

label="com.fatcat.agent"
user_id="$(id -u)"
domain="gui/${user_id}"
script_dir="$(cd "$(dirname "$0")" && pwd -P)"
agent_path="${FATCAT_AGENT_PATH:-${script_dir}/../agent/fatcat_agent/FatCatAgent}"
launch_agents_dir="${HOME}/Library/LaunchAgents"
plist_path="${launch_agents_dir}/${label}.plist"
socket_path="${HOME}/Library/Application Support/FatCat/runtime/fatcat-agent.sock"
hermes_home="${HOME}/Library/Application Support/FatCat/Hermes"
log_dir="${HOME}/Library/Logs/FatCat"

if [[ ! -x "${agent_path}" ]]; then
  echo "FatCat Agent is not executable: ${agent_path}" >&2
  exit 1
fi

xml_escape() {
  local value="$1"
  value="${value//&/&amp;}"
  value="${value//</&lt;}"
  value="${value//>/&gt;}"
  value="${value//\"/&quot;}"
  printf '%s' "${value}"
}

mkdir -p "${launch_agents_dir}" "$(dirname "${socket_path}")" "${hermes_home}" "${log_dir}"
temporary_plist="$(mktemp "${plist_path}.XXXXXX")"
trap 'rm -f "${temporary_plist}"' EXIT

escaped_agent="$(xml_escape "${agent_path}")"
escaped_socket="$(xml_escape "${socket_path}")"
escaped_hermes="$(xml_escape "${hermes_home}")"
escaped_stdout="$(xml_escape "${log_dir}/agent.log")"
escaped_stderr="$(xml_escape "${log_dir}/agent-error.log")"

cat >"${temporary_plist}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${label}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${escaped_agent}</string>
    <string>--socket</string>
    <string>${escaped_socket}</string>
    <string>--hermes-home</string>
    <string>${escaped_hermes}</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>ProcessType</key>
  <string>Background</string>
  <key>StandardOutPath</key>
  <string>${escaped_stdout}</string>
  <key>StandardErrorPath</key>
  <string>${escaped_stderr}</string>
</dict>
</plist>
PLIST

plutil -lint "${temporary_plist}" >/dev/null
chmod 600 "${temporary_plist}"
mv "${temporary_plist}" "${plist_path}"
trap - EXIT

launchctl bootout "${domain}/${label}" 2>/dev/null || true
bootstrapped=0
for attempt in 1 2 3 4 5; do
  if launchctl bootstrap "${domain}" "${plist_path}" 2>/dev/null; then
    bootstrapped=1
    break
  fi
  sleep 0.25
done
if [[ "${bootstrapped}" -ne 1 ]]; then
  echo "FatCat Agent could not be registered with launchd." >&2
  exit 1
fi
launchctl kickstart -k "${domain}/${label}"

echo "FatCat Agent is running at ${socket_path}"
