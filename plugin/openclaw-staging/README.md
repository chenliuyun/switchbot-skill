# SwitchBot OpenClaw Preview Plugin

This directory is a preview plugin bundle for OpenClaw-style agents.

It does not depend on an unpublished plugin registry. Instead, it stages the
minimal files needed to wire a "status push sync" channel around the existing
CLI support in `@switchbot/openapi-cli`:

- `switchbot status-sync run`
- `channels/switchbot-status-sync.channel.json` — preview channel definition
- `scripts/run-status-sync.ps1` / `scripts/run-status-sync.sh` — foreground runner for agent supervisors
- `scripts/start-status-sync.*`, `scripts/stop-status-sync.*`, `scripts/status-status-sync.*` — manual lifecycle wrappers

## What it does

The launcher script subscribes to SwitchBot MQTT shadow events using the user's
existing CLI credentials and forwards each event to the OpenClaw gateway.
The plugin preview no longer owns PID/log logic itself; those lifecycle details
now live in the CLI's `status-sync` command family.

Equivalent raw command:

```bash
switchbot status-sync run --openclaw-token "$OPENCLAW_TOKEN" --openclaw-model "$OPENCLAW_MODEL"
```

## Required environment

- `OPENCLAW_TOKEN` — bearer token for the local OpenClaw gateway
- `OPENCLAW_MODEL` — agent model ID that should receive the pushed events

Optional environment:

- `OPENCLAW_URL` — gateway base URL, default `http://localhost:18789`
- `SWITCHBOT_MQTT_TOPIC` — custom MQTT topic filter

## Lifecycle scripts

Supervisor-facing runner:

- `scripts/run-status-sync.ps1`
- `scripts/run-status-sync.sh`

Manual lifecycle management:

- `scripts/start-status-sync.ps1` / `scripts/start-status-sync.sh`
- `scripts/stop-status-sync.ps1` / `scripts/stop-status-sync.sh`
- `scripts/status-status-sync.ps1` / `scripts/status-status-sync.sh`

The start script launches the sync process in the background and stores state
under the CLI-managed state directory. Set `SWITCHBOT_STATUS_SYNC_HOME` if you
need a different state directory.

## Manual verification

1. Ensure `switchbot config set-token` has already been run.
2. Export `OPENCLAW_TOKEN` and `OPENCLAW_MODEL`.
3. Run `start-status-sync` for your platform.
4. Run `status-status-sync` and confirm it reports `running: true`.
5. Trigger a real device state change.
6. Confirm the target agent receives or reacts to the pushed event.
7. Run `stop-status-sync` when finished.

## Preview status

This is a staging bundle, not a published plugin spec. The channel JSON is a
preview artifact so AI agents and future packaging tools have a concrete file
to point at today.

For a real-machine MQTT -> OpenClaw verification flow with actual credentials,
see [docs/openclaw-status-sync-e2e.md](../../docs/openclaw-status-sync-e2e.md).

