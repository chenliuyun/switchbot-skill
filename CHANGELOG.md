# Changelog

All notable changes to the OpenClaw SwitchBot skill are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project follows [Semantic Versioning](https://semver.org/).

## [0.3.0] - 2026-04-23

Alignment release — matches `@switchbot/openapi-cli` 2.9.0 (Phase 4
shipped: policy v0.2 schema, rules engine, keychain support) and
introduces the skill-side `autonomyLevel` dimension.

### Added — `autonomyLevel` dimension

- **`manifest.json` `roadmap` block** is now a reference that points
  to the CLI's authoritative phase table
  (`docs/design/roadmap.md`) and declares the skill's own autonomy
  level. This release is `autonomyLevel: "L1"` (manual orchestration,
  every mutation confirmed). L2 (semi-autonomous propose-then-approve)
  and L3 (fully autonomous inside the policy envelope) are reserved
  for future skill releases.
- **README "Roadmap" section** is rewritten around L1/L2/L3 instead of
  the previous Phase 1-4 mirror — the CLI owns phase numbering; the
  skill owns autonomy level.

### Added — `SKILL.md` coverage for CLI 2.9.0 capabilities

- **Rules-engine section** — how to author a rule in `automation:`
  (always starting with `dry_run: true`), what the three triggers
  (`mqtt` / `cron` / `webhook`) and two conditions (`time_between` /
  `device_state`) do, which kinds of rules the validator refuses, and
  when to recommend a rule vs. a shell loop. The engine shipped in
  CLI 2.9.0; the skill now knows how to drive it.
- **Keychain section** — how to talk about
  `switchbot auth keychain migrate` / `describe` without running
  credential operations on the user's behalf.
- **Authoritative command table** gains six rows:
  `rules list --json`, `rules lint`, `rules tail --follow`,
  `rules replay --since <dur> --dry-run`,
  `auth keychain describe --json`, and `auth keychain migrate`
  (flagged as user-runs-this, not agent-runs-this).

### Changed

- **`authority.cli`** bumped to `@switchbot/openapi-cli@>=2.9.0 <3.0.0`.
  The previous window (`>=2.8.0 <3.0.0`) is no longer valid — the
  skill's rules-engine guidance and policy-v0.2 assumptions require
  CLI 2.9.0+.
- **`policy.version`** in `manifest.json` bumped to `"0.2"`. The
  Quickstart now uses `switchbot policy new --version 0.2` and the
  expected `policy validate` output reads `schema v0.2`.
- **`examples/policy.schema.json`** updated to mirror the CLI's
  embedded `src/policy/schema/v0.2.json`. The CLI's CI diff job keeps
  this file in sync on every push.
- **Version-pinning block in `SKILL.md`** — target CLI is now 2.9.x;
  the reason-to-upgrade list is rewritten around `rules *` and
  `auth keychain *` instead of the 2.7.x command set.
- **README "What the skill does NOT do (yet)"** — drops the
  rules-engine row (shipped) and the keychain-credentials row
  (shipped); adds rows for L2 and L3 with the workaround being "run
  steps manually" / "user edits policy + `rules reload`".
- **README Quickstart step 1** — expected `switchbot --version`
  output is `2.9.0`.

### Removed

- Roadmap row for "Phase 3 / Phase 4 planned". The CLI roadmap owns
  the phase table now; this repo references it by URL rather than
  mirroring.



Phase 2 release — policy tooling lands in the CLI.

`@switchbot/openapi-cli` 2.8.0 ships a dedicated `switchbot policy` command group (`validate`, `new`, `migrate`) that replaces the manual "copy this template and hope the YAML parses" step in the Quickstart. What was a silent failure mode (bad YAML ⇒ skill falls back to defaults, user wonders why aliases don't work) is now a compiler-style error with a line number, caret, and fix hint.

### Added

- **`docs/agents/`** — install recipes for non-Claude-Code agents: `claude-code.md` (native), `cursor.md` (`.cursor/rules/*.mdc` or legacy `.cursorrules`), `copilot.md` (`.github/copilot-instructions.md`), and `other.md` (Gemini CLI `GEMINI.md`, Codex `AGENTS.md`, generic LLM system-prompt pattern, MCP clients). The skill body itself is unchanged — it's plain Markdown that any LLM-backed agent can consume; the new docs just explain where to paste it.
- **README "Using this skill with other agents" section** — links to the four recipe files and notes the shared prerequisite (the `switchbot` CLI on `PATH`).

### Changed

- **Quickstart (`README.md`, `SKILL.md`)** — Step 2 "create your policy" is now `switchbot policy new` (writes the starter template) + edit + `switchbot policy validate` (exit 0 or named errors). The "edit the YAML by hand" instruction is gone.
- **Compatibility window** — `authority.cli` bumped to `@switchbot/openapi-cli@>=2.8.0 <3.0.0`. The previous Phase-1 window (`>=2.7.0 <3.0.0`) is no longer valid: the skill's Quickstart now assumes the `policy` command group is present.
- **`examples/policy.schema.json`** — is now the published mirror of the CLI's embedded `src/policy/schema/v0.1.json`. A CI job in the CLI repo diffs the two on every push and fails the build on drift.
- **`troubleshooting.md`** — "my policy isn't taking effect" section now recommends `switchbot policy validate` as the first step (previously pointed to a hand-rolled `python -c "import yaml; ..."` snippet, which stays as a fallback for pre-2.8.0 installs).

### Removed

- **Known-limitation note about "no `validate` CLI yet"** removed from `SKILL.md` and the README — the limitation is resolved in CLI 2.8.0.

### Phase 2 → Phase 3

With policy tooling in place, the remaining Phase-1/2 manual step is credential bootstrap (`switchbot config set-token` in the user's shell). Phase 3 will remove that step via an install flow that drops credentials into the OS keychain. `SKILL.md` still lists credential setup as a prerequisite; that copy is unchanged in this release.

## [0.1.0] - 2026-04-22

Initial Phase 1 release — manual orchestration.

### Added

- `SKILL.md` — agent-facing authority chain, bootstrap sequence, safety
  tiers, name-resolution order, common pitfalls, and error-envelope guide
  for `@switchbot/openapi-cli` 2.7.x.
- `manifest.json` — metadata for Claude Code skills + forward-compatible
  hooks for the future ClawHub plugin (phase 3).
- `examples/policy.example.yaml` — copy-and-edit user policy covering
  aliases, confirmations, quiet hours, and audit log configuration.
- `examples/policy.schema.json` — JSON Schema draft 2020-12 for editor
  autocomplete and Phase-2 `switchbot policy validate` integration.
- `README.md` — 15-minute Quickstart, phase roadmap, safety model, and
  layout guide.
- `troubleshooting.md` — 6 concrete failure modes with exact fixes.

### Compatibility

- Requires `@switchbot/openapi-cli` ≥ 2.7.0 and < 3.0.0.
- Tested against CLI 2.7.2.
- Policy schema version `0.1` (forward-compatible: rules engine reserved
  for v0.2, which ships with Phase 4).

### Known limitations (by design for Phase 1)

- No `switchbot policy validate` CLI — use the JSON Schema manually with
  `ajv` or VS Code's `yaml.schemas` until Phase 2 ships.
- No one-command install — users follow the manual Quickstart. Phase 3
  bundles this into `openclaw plugins install clawhub:switchbot`.
- No rule engine — `automation.enabled` must stay `false`. Phase 4
  delivers the `when/then` runtime and dry-run replayer.
