#!/usr/bin/env bash

set -euo pipefail

openclaw_url="${OPENCLAW_URL:-http://localhost:18789}"
openclaw_model="${OPENCLAW_MODEL:-}"
openclaw_token="${OPENCLAW_TOKEN:-}"
topic="${SWITCHBOT_MQTT_TOPIC:-}"
force=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      force=true
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if ! command -v switchbot >/dev/null 2>&1; then
  echo "switchbot CLI is not on PATH. Install @switchbot/openapi-cli 3.0.0+ first." >&2
  exit 1
fi

cmd=(status-sync start --openclaw-url "$openclaw_url")

if [[ -n "$openclaw_token" ]]; then
  cmd+=(--openclaw-token "$openclaw_token")
fi

if [[ -n "$openclaw_model" ]]; then
  cmd+=(--openclaw-model "$openclaw_model")
fi

if [[ -n "$topic" ]]; then
  cmd+=(--topic "$topic")
fi

if [[ "$force" == true ]]; then
  cmd+=(--force)
fi

switchbot "${cmd[@]}"

