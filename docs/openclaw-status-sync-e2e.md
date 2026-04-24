# OpenClaw Status-Sync End-to-End Checklist

Use this checklist on a real machine with valid credentials when you want to
verify the full path:

SwitchBot MQTT -> `switchbot status-sync` -> OpenClaw gateway -> target agent

This is an operator checklist, not a mocked smoke test. It assumes:

- `@switchbot/openapi-cli` `3.0.0+` is installed and on `PATH`
- the local machine already has valid SwitchBot credentials
- the OpenClaw gateway is reachable and already has a valid token + model ID
- you are testing against real device state changes

## 1. CLI Preflight

Run these first and stop if any step fails:

```bash
switchbot --version
switchbot doctor
switchbot devices list
```

Success criteria:

- `switchbot --version` prints `3.0.0` or newer
- `switchbot doctor` ends with `0 fail`
- `switchbot devices list` returns the expected device set

If credentials are not configured yet, run:

```bash
switchbot config set-token
```

## 2. Export OpenClaw Inputs

Required:

- `OPENCLAW_TOKEN` — bearer token accepted by the gateway
- `OPENCLAW_MODEL` — model / agent ID that should receive pushed events

Optional:

- `OPENCLAW_URL` — defaults to `http://localhost:18789`
- `SWITCHBOT_MQTT_TOPIC` — topic override if you need narrower routing

Windows PowerShell:

```powershell
$env:OPENCLAW_URL = 'http://localhost:18789'
$env:OPENCLAW_TOKEN = '<your-token>'
$env:OPENCLAW_MODEL = '<your-model-id>'
```

macOS / Linux:

```bash
export OPENCLAW_URL='http://localhost:18789'
export OPENCLAW_TOKEN='<your-token>'
export OPENCLAW_MODEL='<your-model-id>'
```

Optional topic override:

```bash
export SWITCHBOT_MQTT_TOPIC='switchbot/#'
```

## 3. Check The OpenClaw Gateway

The sink posts to `OPENCLAW_URL/v1/chat/completions`, so verify the gateway is
reachable before starting the bridge.

PowerShell:

```powershell
$body = @{
  model = $env:OPENCLAW_MODEL
  messages = @(@{ role = 'user'; content = 'switchbot status-sync smoke test' })
} | ConvertTo-Json -Depth 4

Invoke-WebRequest -Uri "$env:OPENCLAW_URL/v1/chat/completions" `
  -Method Post `
  -Headers @{ Authorization = "Bearer $env:OPENCLAW_TOKEN" } `
  -ContentType 'application/json' `
  -Body $body
```

Bash:

```bash
curl -i "$OPENCLAW_URL/v1/chat/completions" \
  -H "Authorization: Bearer $OPENCLAW_TOKEN" \
  -H 'Content-Type: application/json' \
  -d @- <<EOF
{"model":"$OPENCLAW_MODEL","messages":[{"role":"user","content":"switchbot status-sync smoke test"}]}
EOF
```

Success criteria:

- the gateway responds on the configured URL
- the token is accepted
- the model ID is valid for that gateway

## 4. Start The Bridge

Foreground mode is best for first-time debugging because you see failures
immediately:

```bash
switchbot status-sync run --openclaw-model "$OPENCLAW_MODEL"
```

If you want background mode instead:

```bash
switchbot status-sync start --openclaw-model "$OPENCLAW_MODEL"
switchbot status-sync status --json
```

If you installed the `openclaw-staging` preview plugin, the wrapper scripts are
equivalent entrypoints:

- PowerShell: `.openclaw/staging/plugins/switchbot/scripts/start-status-sync.ps1`
- Bash: `.openclaw/staging/plugins/switchbot/scripts/start-status-sync.sh`

## 5. Trigger A Real Device Change

Pick a device with an obvious state transition. Examples:

- press a SwitchBot Bot
- toggle a Plug Mini on/off
- open or close a curtain
- change a meter-adjacent sensor state that emits a shadow update

Then verify both sides:

- the CLI stays running without immediate auth / MQTT errors
- the target OpenClaw agent receives or reacts to the pushed event

If the agent has logs or a local UI, capture the exact timestamp of the device
change so you can correlate it with the CLI logs.

## 6. Inspect Runtime State

Background mode:

```bash
switchbot status-sync status --json
```

Check:

- `running: true`
- expected `openclawUrl`
- expected `openclawModel`
- expected `topic` when overridden
- usable `stdoutLog` / `stderrLog` paths

If needed, inspect the logs directly:

```bash
type ~/.switchbot/status-sync/stdout.log
type ~/.switchbot/status-sync/stderr.log
```

On macOS / Linux replace `type` with `cat` or `tail -f`.

## 7. Stop And Re-Check

```bash
switchbot status-sync stop
switchbot status-sync status --json
```

Success criteria:

- stop returns without error
- the second status call reports `running: false`

## 8. Failure Triage

If the end-to-end check fails, narrow it in this order:

1. `switchbot doctor` — credential / MQTT readiness
2. direct gateway POST from Step 3 — token / model / URL validity
3. `switchbot status-sync run ...` foreground mode — process-visible errors
4. `switchbot status-sync status --json` — state/log paths
5. device event timing — confirm the chosen device actually emitted a new shadow update

## 9. Capture For Bug Reports

When reporting a failure, capture:

- CLI version from `switchbot --version`
- `switchbot doctor` output
- `switchbot status-sync status --json`
- the relevant lines from `stdout.log` and `stderr.log`
- the device type and exact action you triggered
- whether the direct Step 3 gateway POST succeeded
