# Changelog

All notable changes to the OpenClaw SwitchBot skill are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project follows [Semantic Versioning](https://semver.org/).

## [0.2.0] - 2026-04-22

Phase 2 release — policy tooling lands in the CLI.

`@switchbot/openapi-cli` 2.8.0 ships a dedicated `switchbot policy` command group (`validate`, `new`, `migrate`) that replaces the manual "copy this template and hope the YAML parses" step in the Quickstart. What was a silent failure mode (bad YAML ⇒ skill falls back to defaults, user wonders why aliases don't work) is now a compiler-style error with a line number, caret, and fix hint.

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
