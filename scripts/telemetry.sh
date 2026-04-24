# scripts/telemetry.sh
# Source this file, then call: report_telemetry success|failed_at_N <agent>

TELEMETRY_URL="https://api.switchbot-skill.dev/telemetry"
TELEMETRY_OPT_IN_FILE="$HOME/.switchbot/telemetry-opt-in"

is_telemetry_opted_in() {
  [[ -f "$TELEMETRY_OPT_IN_FILE" ]] && [[ "$(cat "$TELEMETRY_OPT_IN_FILE")" == "yes" ]]
}

prompt_telemetry_opt_in() {
  [[ -f "$TELEMETRY_OPT_IN_FILE" ]] && return  # already decided
  echo ""
  echo -e "  ${DIM}Help improve this skill: allow anonymous install reporting?${RESET}"
  echo -e "  ${DIM}No tokens, device IDs, or personal data are collected.${RESET}"
  local ans
  read -r -p "  Allow anonymous telemetry? [y/N] " ans
  mkdir -p "$(dirname "$TELEMETRY_OPT_IN_FILE")"
  if [[ "${ans:-n}" =~ ^[Yy] ]]; then
    echo "yes" > "$TELEMETRY_OPT_IN_FILE"
    ok "Telemetry enabled. Disable any time: rm $TELEMETRY_OPT_IN_FILE"
  else
    echo "no" > "$TELEMETRY_OPT_IN_FILE"
  fi
}

report_telemetry() {
  is_telemetry_opted_in || return 0
  local status="$1" agent="${2:-unknown}"
  local os_name="unknown"
  [[ "$(uname -s)" == "Darwin" ]] && os_name="macos"
  [[ "$(uname -s)" == "Linux" ]] && os_name="linux"
  local payload
  payload=$(printf '{"event":"install","status":"%s","os":"%s","agent":"%s","version":"0.5.0"}' \
    "$status" "$os_name" "$agent")
  # Fire-and-forget; never block the install on network failure
  curl -fsSL -X POST -H "Content-Type: application/json" \
    -d "$payload" "$TELEMETRY_URL" --connect-timeout 3 --max-time 5 \
    >/dev/null 2>&1 || true
}
