# Error Handling & Auth Recovery Design

**Date:** 2026-05-22  
**Scope:** All three platforms — Linux/macOS (Bash), Windows (PowerShell), MCP plugin runtime  
**Goal:** Centralized, self-help error messages (reason + fix command) covering: install-without-login, login failure, token expiry, thorough uninstall + verification, re-login flow.

---

## 1. Architecture

```
packages/openclaw-skill/
  lib/
    error-messages.js        ← NEW: unified error registry
  bin/
    start.js                 ← CHANGE: use error-messages
    setup-flow.js            ← CHANGE: use error-messages
  setup/
    check-credentials.js     ← CHANGE: use error-messages
  cli.js                     ← CHANGE: use error-messages

packages/codex-plugin/
  lib/
    error-messages.js        ← NEW: same scenario set
  bin/
    auth.js                  ← CHANGE: use error-messages
  setup/
    check-credentials.js     ← CHANGE: use error-messages

scripts/
  bootstrap.sh               ← CHANGE: add post-install auth check with fix hint
  bootstrap.ps1              ← CHANGE: same (PowerShell)
  uninstall.sh               ← CHANGE: add clean-uninstall verification output
  uninstall.ps1              ← CHANGE: same (PowerShell)

troubleshooting.md           ← CHANGE: add 3 new sections
```

**Core principle:** Every error scenario maps to a named key in `error-messages.js`. The key carries `{ reason, fix, hint }`. Callers never build error strings themselves — they call `formatError(key)`.

---

## 2. `error-messages.js` Module

**Location:** `packages/openclaw-skill/lib/error-messages.js`  
`packages/codex-plugin` has an identical copy (or re-exports the same file).

```js
const ERRORS = {
  'auth-not-configured': {
    reason: 'SwitchBot credentials are not configured.',
    fix:    'switchbot auth login',
    hint:   'Run the fix command, then restart your MCP client.',
  },
  'auth-login-failed': {
    reason: 'Login failed — the CLI returned a non-zero exit code.',
    fix:    'switchbot auth login',
    hint:   'Check your network connection and try again.',
  },
  'token-expired': {
    reason: 'Credentials exist but doctor check failed — token may be expired.',
    fix:    'switchbot auth logout && switchbot auth login',
    hint:   'After re-login, run `switchbot doctor` to verify.',
  },
  'cli-not-installed': {
    reason: 'switchbot CLI is not installed or not in PATH.',
    fix:    'npm install -g @switchbot/openapi-cli',
    hint:   'After install, run `switchbot doctor` to confirm.',
  },
  'cli-version-too-low': {
    reason: 'switchbot CLI version is below the required minimum (3.7.1).',
    fix:    'npm install -g @switchbot/openapi-cli@latest',
    hint:   'After upgrade, re-run setup.',
  },
};

function formatError(key) {
  const e = ERRORS[key];
  return [
    `Error: ${e.reason}`,
    `  Fix:  ${e.fix}`,
    `  Hint: ${e.hint}`,
  ].join('\n');
}

module.exports = { ERRORS, formatError };
```

**Terminal output example:**
```
Error: SwitchBot credentials are not configured.
  Fix:  switchbot auth login
  Hint: Run the fix command, then restart your MCP client.
```

---

## 3. Changes to Existing Files

### `packages/openclaw-skill/bin/start.js`
- **Before:** `setupRequired(message)` builds string inline  
- **After:** `setupRequired(formatError('auth-not-configured'))` when credentials check returns `ok: false`

### `packages/openclaw-skill/bin/setup-flow.js`
| Failure point | Key used |
|---|---|
| `hasCli()` returns false | `cli-not-installed` |
| Version below 3.7.1 | `cli-version-too-low` |
| `doctor` exits non-zero | `token-expired` |

### `packages/openclaw-skill/setup/check-credentials.js` (and `codex-plugin` equivalent)
- Both `tryDoctor()` and `tryKeychainDescribe()` return falsy → `{ ok: false, message: formatError('auth-not-configured') }`  
- `doctor` present but exits non-zero → `{ ok: false, message: formatError('token-expired') }`

### `packages/openclaw-skill/cli.js`
- `AUTH_ERROR_PATTERNS` match → `setupRequired(formatError('auth-not-configured'))` (replaces inline string concatenation)

### `packages/codex-plugin/bin/auth.js`
- `switchbot auth login` exits non-zero → write `formatError('auth-login-failed')` to stderr before returning exit code

### `scripts/bootstrap.sh` and `bootstrap.ps1`
- After install completes, add a verification step that runs `switchbot doctor`
- If doctor fails: print the Bash/PS equivalent of `formatError('auth-not-configured')` (reason + fix command), do not silently exit

### `scripts/uninstall.sh` and `uninstall.ps1`
- After removal steps complete, print a "Verify clean uninstall" block (see §5 below)

---

## 4. Re-login Flow

Triggered when: `auth-not-configured` or `token-expired` is detected.

```
switchbot auth logout           # clear existing token
switchbot auth login            # open browser to re-authenticate
switchbot doctor                # verify credentials are valid
```

Then restart the MCP client (Claude / Copilot / Codex).

The `token-expired` error key's `fix` field already encodes `logout && login` so users see both commands in one message.

---

## 5. Thorough Uninstall + Verification

### Uninstall command

**macOS / Linux:**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/chenliuyun/switchbot-skill/main/scripts/uninstall.sh) \
  --agent claude-global --remove-cli --remove-policy --remove-credentials
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/chenliuyun/switchbot-skill/main/scripts/uninstall.ps1 | iex
# Then:
Uninstall-SwitchBotSkill -Agent claude-global -RemoveCli -RemovePolicy -RemoveCredentials
```

### Post-uninstall verification (4 checks)

Run these — all should return "not found" or empty:

```bash
switchbot --version      # expected: command not found
ls ~/.switchbot/         # expected: no such file or directory
ls ~/.config/openclaw/   # expected: no such file or directory
switchbot doctor         # expected: command not found
```

The uninstall scripts will print these four commands automatically after completion.

---

## 6. `troubleshooting.md` Additions

Three new sections appended to the existing file:

### § Uninstalling
Documents the `uninstall.sh` / `uninstall.ps1` commands with `--remove-cli --remove-policy --remove-credentials` flags.

### § Verifying a Clean Uninstall
The four check commands above.

### § Re-authenticating (Re-login)
```
switchbot auth logout
switchbot auth login
switchbot doctor
→ restart MCP client
```

---

## 7. Error Handling Decision Matrix

| Scenario | Detected by | Key | Severity |
|---|---|---|---|
| Never ran `auth login` | `check-credentials.js` → both checks false | `auth-not-configured` | Fatal |
| `auth login` returned non-zero | `auth.js` exit code | `auth-login-failed` | Fatal |
| Token expired / doctor fails | `check-credentials.js` → doctor non-zero | `token-expired` | Fatal |
| CLI not installed | `check-cli.js` ENOENT | `cli-not-installed` | Fatal |
| CLI version too low | `check-cli.js` semver | `cli-version-too-low` | Fatal |
| Daemon start fails | `check-daemon.js` | *(existing warning, no change)* | Warning |

---

## 8. Out of Scope

- npm install failure details (network, permissions) — separate issue, tracked as gap
- Keychain cross-platform differences on Windows — separate issue
- Retry / exponential backoff for network failures in bootstrap scripts — separate issue
