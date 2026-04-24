# Using this skill with GitHub Copilot

GitHub Copilot (Chat in VS Code / Visual Studio / JetBrains / GitHub.com) reads `.github/copilot-instructions.md` from the workspace root and prepends it to every chat turn. That's the drop-in point for `SKILL.md`'s body.

## Prerequisites

```bash
npm install -g @switchbot/openapi-cli
switchbot config set-token <token> <secret>
switchbot policy new && switchbot policy validate
```

Copilot shells out through the user's integrated terminal, so the `switchbot` binary must be on the same `PATH` VS Code (or your IDE) sees.

## Install — repo-scoped instructions

```bash
mkdir -p .github
cp SKILL.md .github/copilot-instructions.md
```

Then open `.github/copilot-instructions.md` and **remove the top YAML front-matter** (Copilot doesn't parse it — it would show up as literal `---` in the prompt). Keep everything from `# SwitchBot skill` down.

That's it. Copilot Chat in that workspace now treats the skill body as always-on context.

## Scope & privacy

- `.github/copilot-instructions.md` is committed to the repo. If you share the repo, collaborators get the same instructions. This is usually fine — the skill body contains no secrets — but be aware.
- User-scoped alternative: Copilot also supports "custom instructions" in the Copilot settings (a single free-text box per user, not per repo). Paste `SKILL.md`'s body there if you want it on for every project without committing anything. Trade-off: it's on globally, which is noisy for repos that have nothing to do with smart-home control.

## Non-chat Copilot (inline suggestions)

Inline code-completion Copilot does NOT read `.github/copilot-instructions.md` — that surface only gets file content + a small neighborhood. The skill is only useful in **Copilot Chat** / **Copilot in the CLI** / **Copilot Workspace**, where the model has a real system prompt.

If you wanted the skill to influence inline suggestions, you'd need to turn the skill into actual code (e.g. a TypeScript helper module with JSDoc) that Copilot sees while you type — out of scope for this doc.

## Verification

Open Copilot Chat in a workspace where `.github/copilot-instructions.md` is installed:

```text
You: turn on the bedroom light
Copilot: I'll use the switchbot CLI. First let me bootstrap:

         switchbot agent-bootstrap --compact
         [...]
         switchbot devices command 01-... turnOn --audit-log
```

If Copilot invents a deviceId, doesn't read `policy.yaml`, or tries to call a REST endpoint directly — the instructions didn't load. Check:

- File is at `.github/copilot-instructions.md` exactly (not `.github/copilot/instructions.md`, not `COPILOT.md`).
- Front-matter `---` block was removed.
- You're in Copilot **Chat**, not inline completion.
- Reopen the workspace after adding the file; Copilot caches the instruction file per-session.
