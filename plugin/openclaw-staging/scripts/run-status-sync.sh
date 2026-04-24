#!/usr/bin/env bash

set -euo pipefail

openclaw_url="${OPENCLAW_URL:-http://localhost:18789}"
openclaw_model="${OPENCLAW_MODEL:-}"
openclaw_token="${OPENCLAW_TOKEN:-}"
topic="${SWITCHBOT_MQTT_TOPIC:-}"

if ! command -v switchbot >/dev/null 2>&1; then
  echo "switchbot CLI is not on PATH. Install @switchbot/openapi-cli 3.0.0+ first." >&2
  exit 1
fi

args=(status-sync run --openclaw-url "$openclaw_url")

if [[ -n "$openclaw_token" ]]; then
  args+=(--openclaw-token "$openclaw_token")
fi

if [[ -n "$openclaw_model" ]]; then
  args+=(--openclaw-model "$openclaw_model")
fi

if [[ -n "$topic" ]]; then
  args+=(--topic "$topic")
fi

switchbot "${args[@]}"
