# Changelog

All notable changes to the OpenClaw SwitchBot skill are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project follows [Semantic Versioning](https://semver.org/).

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
