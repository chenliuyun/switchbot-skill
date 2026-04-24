# Using this skill with other agents

Claude Code, Cursor, and Copilot have dedicated recipes. For everything else, the pattern is the same: find where the agent accepts a system prompt (or instruction file) and paste `SKILL.md`'s body into it. The skill is plain Markdown — any LLM-backed agent that can read a system prompt can use it.

## Prerequisites (all agents)

```bash
npm install -g @switchbot/openapi-cli
switchbot config set-token <token> <secret>
switchbot policy new && switchbot policy validate
```

The agent needs the `switchbot` binary on the same `PATH` it spawns shells with. Without the CLI, the skill is just advice — nothing will execute.

## Gemini CLI

`GEMINI.md` at the workspace root (or `~/.gemini/GEMINI.md` for user-global) is loaded into every turn's system prompt.

```bash
# project-scoped
cp SKILL.md GEMINI.md

# or user-global
mkdir -p ~/.gemini
cp SKILL.md ~/.gemini/GEMINI.md
```

Strip the top YAML front-matter (Gemini CLI doesn't parse Claude-style front-matter; it would show up literally).

## OpenAI Codex CLI / `codex`

Codex reads `AGENTS.md` at the workspace root.

```bash
cp SKILL.md AGENTS.md
```

Again, remove the YAML front-matter.

If you want it global, Codex also supports `~/.codex/AGENTS.md` (merged with the project file). Same copy-and-strip approach.

## Generic LLM app (custom assistant, Open WebUI, LibreChat, raw API)

Any frontend that lets you set a **system prompt** works — paste the body of `SKILL.md` (minus the front-matter) as the system prompt and make sure the assistant has shell-execution capability.

Minimal loop in pseudocode:

```python
system = open("SKILL.md").read().split("---\n", 2)[-1]   # drop front-matter
messages = [{"role": "system", "content": system}]
while True:
    user = input("> ")
    messages.append({"role": "user", "content": user})
    reply = llm.chat(messages)
    # if reply contains a shell action, run it with a safelist
    # feed stdout back as a tool_result message, loop
```

The skill explicitly tells the model to call `switchbot agent-bootstrap` first, so your harness should allow at minimum `switchbot *` command execution. Respect the safety tiers in the skill body (`destructive` actions should prompt the human).

## MCP-capable clients

The `switchbot` CLI ships a Model Context Protocol server:

```bash
switchbot mcp serve
```

Any MCP client (Claude Desktop, Continue.dev, Cline, Zed AI, custom) can connect to it and get typed tools for every capability the CLI exposes. When using MCP, `SKILL.md` is **optional** — the tools are self-describing — but pasting the skill body as a system prompt still helps, because it encodes the safety tiers, bootstrap sequence, and name-resolution strategy that the raw tool schemas don't.

Consult `switchbot mcp --help` for the current list of transports (stdio / SSE / HTTP) and how to register the server with your MCP client.

## Verification (applies to all)

In a fresh chat with the agent, say:

```text
List my SwitchBot devices and tell me which ones are currently on.
```

The agent should:

1. Run `switchbot agent-bootstrap --compact` (not dive straight into device commands).
2. Read `~/.config/openclaw/switchbot/policy.yaml` if it exists.
3. Prefer `--json` output for parsing.
4. Never ask you for your token — it should assume the CLI is already configured.

If any of those fails, the instruction file probably didn't load. Check the agent's docs for the exact filename/path it expects, and verify you removed the Claude-style `---` front-matter block (most non-Claude agents treat it as literal text).

## Something missing?

If you use an agent that isn't covered here and the pattern wasn't obvious, file an issue at <https://github.com/chenliuyun/switchbot-skill/issues> with:

- Agent name + version
- Where its system-prompt / instruction file lives
- What worked (or didn't) when you pasted `SKILL.md` into it

We'll either add a recipe or flag an incompatibility.
