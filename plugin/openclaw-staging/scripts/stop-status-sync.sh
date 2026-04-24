#!/usr/bin/env bash

set -euo pipefail

if ! command -v switchbot >/dev/null 2>&1; then
  echo "switchbot CLI is not on PATH. Install @switchbot/openapi-cli 3.0.0+ first." >&2
  exit 1
fi

switchbot status-sync stop

