# Codex Bootstrap Prompt — Design Spec

**Date:** 2026-05-22
**Status:** Approved

---

## Problem

Installing the SwitchBot Codex plugin currently requires three manual steps:

1. `codex plugin marketplace add /path/to/switchbot-skill`
2. `codex plugin add switchbot@switchbot-skill`
3. `switchbot auth login` (browser login)

Step 3 is inherently interactive and cannot be automated. Steps 1–2 can and should be automated. There is no single "paste this and go" path for new users or machines.

---

## Goal

Reduce first-time setup to: **paste one prompt into Codex → only auth requires human interaction.**

Two distribution paths:

- **GitHub Clone path** — works immediately, no publishing required
- **npm path** — cleaner distribution after publishing `@cly-org/switchbot-codex-plugin`

---

## Architecture

### GitHub Clone path

```
User pastes bootstrap prompt into Codex chat
  → Codex AI runs: npm install -g @switchbot/openapi-cli@latest
  → Codex AI runs: git clone https://github.com/chenliuyun/switchbot-skill.git ~/switchbot-skill
  → Codex AI runs: codex plugin marketplace add ~/switchbot-skill
  → Codex AI runs: codex plugin add switchbot@switchbot-skill
  → onInstall hook → bin/auth.js → switchbot auth login (human opens browser)
```

### npm path (after publishing)

```
User pastes bootstrap prompt into Codex chat
  → Codex AI runs: npm install -g @cly-org/switchbot-codex-plugin
  → Codex AI runs: switchbot-codex-install
      → checkCli() → npm install -g @switchbot/openapi-cli@latest (if missing)
      → codex plugin marketplace add <own-package-root>
      → codex plugin add switchbot@<dir-name>
      → onInstall hook → bin/auth.js → switchbot auth login (human opens browser)
```

---

## File Changes

### New Files

| Path | Purpose |
|---|---|
| `packages/codex-plugin/bin/install.js` | `switchbot-codex-install` binary — CLI install + marketplace register + plugin add |
| `packages/codex-plugin/tests/install.test.js` | Unit tests for `makeInstall` (5 cases) |
| `BOOTSTRAP.md` | Standalone copyable snippet for both install paths |

### Modified Files

| Path | Change |
|---|---|
| `packages/codex-plugin/package.json` | Add `switchbot-codex-install` to `bin` |
| `README.md` | Add "Section 0: One-Paste Install" above existing install sections |

---

## `bin/install.js` Design

Exports `makeInstall({ checkCli, runInherit })` for testability (same pattern as `makeRunAuth`).

### Steps

1. **CLI check** — call `checkCli()`; if not found, run `npm install -g @switchbot/openapi-cli@latest`
2. **Marketplace register** — `codex plugin marketplace add <packageRoot>` where `packageRoot` is derived from `fileURLToPath(import.meta.url)` → parent directory (no hardcoded paths)
3. **Plugin add** — `codex plugin add switchbot@<basename(packageRoot)>`; this triggers the `onInstall` hook which calls `bin/auth.js`

### Failure handling

| Step | Failure | Behaviour |
|---|---|---|
| npm install CLI | non-zero exit | Print manual instruction, `process.exit(code)` |
| marketplace add | non-zero exit | Print error, `process.exit(code)` |
| plugin add | any exit | Transparently pass exit code through |

`runInherit` uses `{ shell: true }` so `.cmd` files resolve on Windows.

### `package.json` bin entry

```json
"bin": {
  "switchbot-codex-auth": "./bin/auth.js",
  "switchbot-codex-install": "./bin/install.js"
}
```

---

## Bootstrap Prompt Content

### GitHub Clone path (paste into Codex chat)

```
请帮我安装 SwitchBot Codex 插件，按顺序执行以下命令：
1. npm install -g @switchbot/openapi-cli@latest
2. git clone https://github.com/chenliuyun/switchbot-skill.git ~/switchbot-skill
3. codex plugin marketplace add ~/switchbot-skill
4. codex plugin add switchbot@switchbot-skill

全部成功后，提示我在终端运行 `switchbot auth login` 完成浏览器授权。
```

### npm path (paste into Codex chat, after publishing)

```
请帮我安装 SwitchBot Codex 插件：
1. npm install -g @cly-org/switchbot-codex-plugin
2. switchbot-codex-install

完成后提示我运行 `switchbot auth login`。
```

---

## Testing

`tests/install.test.js` — five cases using injected `checkCli` and `runInherit` stubs:

1. CLI already present → skip npm install, proceed to marketplace add
2. CLI missing → run `npm install -g @switchbot/openapi-cli@latest`, then continue
3. `npm install` fails (non-zero) → exit with that code, no further steps
4. `codex plugin marketplace add` fails → exit with that code, no further steps
5. All steps succeed → three commands called in order, exit 0

---

## README Structure After Change

```
## Install

### 0. One-Paste Install（最快）   ← NEW, placed first
### A. Codex（推荐）               ← existing, kept as manual fallback
### B. OpenClaw / ClawHub          ← unchanged
### C. File-based install          ← unchanged
```

`Section 0` contains two copyable code blocks: GitHub Clone path prompt and npm path prompt.

---

## Implementation Notes

- `<dir-name>` passed to `codex plugin add` is `path.basename(packageRoot)`. **Verify** during implementation that Codex uses the directory name as the marketplace entry key (consistent with how `codex plugin marketplace add` registers entries).
- `bin/install.js` is not called by the `onInstall` hook — it is a standalone CLI command for first-time setup. The `onInstall` hook continues to call `bin/auth.js` as before.
- No changes to `bin/auth.js`, `setup/`, or `.codex-plugin/`.
