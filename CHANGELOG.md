# Changelog

All notable changes to the OpenClaw SwitchBot skill are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

_No changes yet._

## [0.6.1] - 2026-04-26

CI + packaging fix release. Gets the plugin onto npm for the first time.

### Changed

- **npm scope renamed**: `@chenliuyun/switchbot-openclaw-skill` →
  `@cly-org/switchbot-openclaw-skill`. The publish-token's owning npm
  account is `cly-org`, not `chenliuyun`, and a scope belongs to exactly
  one user/org. Old install commands in README / docs / examples all
  updated. The GitHub repository stays at `chenliuyun/switchbot-skill`;
  only the npm package name moves. v0.6.0 never reached the npm registry
  (CI aborted before publish), so no downstream pinning breaks.

### Fixed

- **`plugin/openclaw/package.json` `test` script**: `node --test tests/**/*.test.js`
  → `node --test tests/*.test.js`. Node's `--test` doesn't glob on its own,
  and Linux bash (used by GitHub Actions runners) doesn't expand `**`
  without `shopt -s globstar`, so the publish CI saw "Could not find
  tests/**/*.test.js" and aborted before `npm publish`. The flat shell
  glob works on all runners. Three tests (13 cases total) pass unchanged.

### Shipped alongside

- **`.github/workflows/publish-npm.yml`** — triggers on `release: published`
  or `workflow_dispatch`, verifies tag matches `package.json.version`, runs
  `npm ci` + `npm test`, then `npm publish --access public --provenance`.
  First successful publish of `@cly-org/switchbot-openclaw-skill` to
  npm lands on this version (0.6.0 never made it past the CI test gate).

## [0.6.0] - 2026-04-26

First release of the **OpenClaw / ClawHub plugin**. The same skill is now
installable as a one-command plugin from ClawHub (or npm, or a pinned
GitHub tag) — no symlinks, no manual file copy, no per-agent setup.

The file-based path stays available for agents that don't run OpenClaw.

### Added

- **`plugin/openclaw/` — Claude-bundle plugin published to npm** as
  `@cly-org/switchbot-openclaw-skill`. Ships a `.claude-plugin/plugin.json`
  + `.mcp.json` pair that OpenClaw auto-detects, registering the stdio MCP
  server and the 6 SwitchBot tools (`devices_list`, `devices_status`,
  `devices_describe`, `devices_command`, `scenes_list`, `scenes_run`).
- **Plugin-level `--no-cache` absorption**: the three read tools
  (`devices_list`, `devices_status`, `devices_describe`) and `scenes_list`
  always pass `--no-cache` to the underlying CLI, paper-covering the
  documented cache bug without the agent needing to remember. Mutations
  (`devices_command`, `scenes_run`) deliberately don't pass the flag — they
  don't hit the cache.
- **`plugin/openclaw/cli.js` — `buildCliArgs` as single source of truth**
  for argv shape. All 6 tool handlers route through it, which makes the
  `--no-cache` policy and the `--audit-log` policy for mutations
  centrally enforced.
- **`plugin/openclaw/tests/cli-args.test.js`** — 8 tests covering
  `--no-cache` on reads, absence on mutations, audit-log on mutations,
  params forwarding, and the "unknown tool throws" edge. Plus the
  migrated `server.test.js` from the policy editor. Node `--test`, zero
  new runtime deps.
- **`docs/openclaw-plugin-install.md`** — canonical install guide for
  the plugin path (ClawHub, GitHub tag, local clone), verification
  spot-checks, uninstall, and plugin-specific troubleshooting.
- **README `Quickstart` lead-in** — ClawHub install block at the top of
  Quickstart with pointer to the install doc.
- **`manifest.json` — `companionPlugin`** gains `name`, `npm`, and
  `install` fields; `status` flipped from `not-yet-published` to
  `published`.

### Changed

- **`plugin/openclaw/package.json`** switched to scoped name
  `@cly-org/switchbot-openclaw-skill` with `publishConfig.access: public`,
  `files` allowlist (12 files, 6.6 kB tarball), `engines.node: ">=18"`,
  and `peerDependencies["@switchbot/openapi-cli"]: ">=3.3.0"`.
- **`plugin/openclaw/channels/switchbot.channel.json`** — **removed**.
  OpenClaw's "channels" concept refers to messaging platforms
  (Slack/Discord/Teams), not MCP wiring. The file was never a valid
  channel manifest; its job is now done by the `.claude-plugin/plugin.json`
  + `.mcp.json` pair that OpenClaw actually reads.

### Publish path

`npm publish` from `plugin/openclaw/`, then
`clawhub package publish .` from the same directory (requires
`clawhub login` / GitHub OAuth). ClawHub auto-populates source
attribution from the git remote; no separate metadata file needed.

## [0.5.1] - 2026-04-26

Hardening release. Tightens the supported `@switchbot/openapi-cli` floor to
`>=3.3.0` (the first version where the envelope, cache, idempotency, and
policy-validate behaviors documented in `SKILL.md` are stable), removes the
duplicate root `policy-editor/` tree, and anchors the `(temporary)`
workarounds with TODO comments so they get revisited when upstream ships
fixes. No runtime behavior change for users already on CLI 3.3.0+.

### Changed

- **`manifest.json` — `authority.cli`**: `>=3.0.0 <4.0.0` →
  `>=3.3.0 <4.0.0`. All four pitfalls documented in `SKILL.md` §5–§9 rely
  on 3.3.0 behavior (envelope shape, cache invalidation, idempotency
  semantics, policy schema v0.2 strictness). CLI 3.0.0–3.2.x silently hit
  the documented footguns.
- **`SKILL.md` — Common pitfalls §5** rewritten as "`--json` envelope —
  read `.data`, check `.error` first." Flags the breaking envelope change
  explicitly so downstream parsers that reached for top-level fields
  notice the silent `undefined` path.
- **`SKILL.md` — If the CLI returns an error**: new paragraph on
  idempotency for `mutation` retries. Marked *(temporary — revisit when
  CLI idempotency is documented as reliable)*. Retries must use a local
  fingerprint (`{deviceId, command, args, minute-bucket}`) + short TTL;
  `--idempotency-key` is not a substitute.
- **`SKILL.md` — Version pinning section**: expanded explanation of why
  3.0.0–3.2.x are unsupported; added a fallback for users on pinned
  corporate builds (pin skill to 0.5.0).
- **Section headings across `SKILL.md` / `README.md` / docs**: all `CLI
  ≥ 3.0.0` references bumped to `CLI ≥ 3.3.0`.
- **`plugin/openclaw/package.json`**: peerDependency
  `@switchbot/openapi-cli` floor `>=3.0.0` → `>=3.3.0`;
  `package-lock.json` regenerated.

### Added

- **`SKILL.md` — Common pitfalls §8** *(temporary)*: force `--no-cache`
  on batch/long-lived reads until the upstream CLI cache bug is fixed.
  Cross-links to `troubleshooting.md`. Anchored with a TODO comment so
  the section can be removed when `@switchbot/openapi-cli@3.3.1+` ships
  the fix.
- **`SKILL.md` — Common pitfalls §9**: validate deviceId shape yourself
  before writing rules. The policy schema patterns only the `aliases`
  map, so `device:` on triggers/conditions/actions passes
  `switchbot policy validate` and fails at runtime.
- **`troubleshooting.md` — new section** "`switchbot --version` is below
  3.3.0" explaining the four footguns and directing users to
  `npm install -g @switchbot/openapi-cli@latest`.
- **`troubleshooting.md` — new section** "Batch or long-lived calls
  return stale device state" (marked temporary workaround; anchored with
  a TODO comment).
- **`scripts/bootstrap.sh` + `scripts/bootstrap.ps1`**: pre-flight CLI
  version guard. Bootstrap refuses to proceed if
  `switchbot --version` < 3.3.0 and prints the upgrade command. Bash
  uses `sort -V`; PowerShell uses the native `[version]` cast.

### Removed

- **Root `./policy-editor/` directory**: byte-identical duplicate of
  `plugin/openclaw/policy-editor/`. Test coverage migrated into the
  plugin tree as `plugin/openclaw/tests/policy-editor.test.js` before
  deletion, so the editor server keeps its test suite.

## [0.5.0] - 2026-04-24

Feature release — L3 fully autonomous rule authoring. Requires CLI ≥ 2.13.0.

### Added

- **SKILL.md — L3 · Proactive rule authoring section**: when to suggest a
  rule, the full `rules suggest` → `policy add-rule --dry-run` → user
  approval → inject + reload workflow, dry-run → arm transition guidance.
- **Authority chain**: two new rows for `rules suggest` and `policy add-rule`.
- **Things to never do**: three new hard limits (no destructive commands in
  rules, never arm on first author, never enable automation without telling
  the user).
- **Version pinning table**: new row for CLI 2.13.0 features.

### Changed

- `manifest.json`: version 0.4.0 → 0.5.0; `authority.cli` ≥ 2.13.0;
  `autonomyLevel` L2 → L3.
- `README.md`: roadmap table L3 Planned → ✅ Shipped (v0.5); "You are at L3";
  "What skill does NOT do (yet)" rewritten to remove the L3 placeholder.
- Quickstart: CLI version 2.12.0 → 2.13.0.

## [0.4.0] - 2026-04-24

Alignment release — matches `@switchbot/openapi-cli` 2.12.0 (Track δ:
`plan suggest` + `plan run --require-approval`) and 2.11.0 (Track γ:
`days` weekday filter, `all`/`any`/`not` conditions). Promotes skill to
`autonomyLevel: "L2"`.

### Added — L2 semi-autonomous workflow

- **`SKILL.md` — Semi-autonomous workflow section** covers the L2
  propose-then-approve loop: `plan suggest --intent "..." --device <id>…`
  drafts a plan from keyword heuristics (on/off/press/lock/open/close/pause);
  `plan run --require-approval` prompts per destructive step — non-destructive
  steps run without interruption. Non-TTY environments auto-reject destructive
  steps. Mutually exclusive with `--json`; `--yes` overrides.
- **`SKILL.md` — authority chain** gains two rows: draft a plan from intent
  (`plan suggest`) and run with per-step approval (`plan run --require-approval`).
- **`SKILL.md` — credentials section** adds `switchbot install` /
  `switchbot uninstall` (CLI 2.10.0) as the recommended first-time setup path.

### Added — rules engine capability updates (CLI 2.11.0)

- **`SKILL.md` — cron trigger** documents the optional `days: [mon, wed, fri]`
  weekday filter: firings on unlisted days are suppressed without writing
  throttle or audit entries.
- **`SKILL.md` — conditions** expanded from 2 to 5 shapes: `time_between`,
  `{ device, field, op, value }` device-state compare (with operator list),
  `all` (AND sub-list), `any` (OR sub-list), `not` (invert). Composites nest
  via `$ref`; the top-level `conditions[]` array remains AND-joined.
- **`examples/policy.schema.json`** — `triggerCron` gains an optional `days`
  array; `condition` `oneOf` expands from 2 to 5 branches with the three new
  composite shapes using recursive `$ref: "#/$defs/condition"`.
- **`examples/policy.example.yaml`** — `version` 0.1 → 0.2; automation block
  rewritten with two annotated rule examples (mqtt trigger + `any` condition
  composition; cron trigger + `days` weekday filter).

### Changed

- **`manifest.json`** — `version` 0.3.0 → 0.4.0; `autonomyLevel` L1 → L2;
  `authority.cli` lower bound tightened to `>=2.12.0 <3.0.0`; `roadmap.notes`
  updated to describe L2 semantics and note L3 remains out of scope.
- **`SKILL.md` — version pinning** rewritten as a per-feature minimum version
  table (`rules *` → 2.9.0; `install/uninstall` → 2.10.0;
  `days`/`all`/`any`/`not` → 2.11.0; `plan suggest`/`--require-approval` →
  2.12.0). Upgrade instruction changed from "stop and tell the user" to
  `npm update -g @switchbot/openapi-cli`.
- **`SKILL.md` — credentials section** corrects Windows keychain backend
  description from `cmdkey` to "PowerShell + Win32 `CredRead`/`CredWrite`".
- **README roadmap table** — L2 status Planned → ✅ Shipped (v0.4); L2
  description corrects "one Y/N approves the whole batch" to per-step approval;
  L3 description updated to note prerequisites met and remaining gap (proactive
  authoring UX); column header "CLI phase it needs" → "CLI version it needs".
- **README paragraph after roadmap table** — "You are currently at L1" →
  "You are at L2" with context on what shipped and what L3 requires.
- **README "What the skill does NOT do"** — removes shipped rows (one-command
  install; L2 multi-step plans); retains only L3 proactive-authoring row;
  section heading updated from "deliberate L1 omissions" to "deliberate L3
  omission".
- **README Quickstart step 1** — expected `switchbot --version` output updated
  to `2.12.0`.



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
