<!-- CCASP-CODEX-COMPAT:START -->
# Codex Runtime Compatibility

This prompt was authored for Claude-style slash workflows. In Codex runtime, adapt tool calls as follows:
- `AskUserQuestion` => ask the user directly in chat.
- `WebSearch`/`WebFetch` => use available web tools (`search_query`, `open`, `find`) and cite links.
- `Read`/`Write` => use shell/filesystem tools in this workspace.
- Claude-only MCP calls (for example Playwright MCP names) => use available equivalents or clearly state fallback.
- Keep intent and output format identical; only adapt execution mechanics.
<!-- CCASP-CODEX-COMPAT:END -->
<!-- CODEX-OVERRIDE:START -->
# happy-start — Codex Runtime

This command starts the Happy Engineering development environment. Happy MCP tools are Claude Code CLI-specific and unavailable in Codex.

## What I Can Do

Start your development server manually:

```bash
# Start the dev server (common options)
npm run dev        # Vite/React
npm start          # CRA
npx next dev       # Next.js
python -m uvicorn backend.main:app --reload --port 8001  # FastAPI
```

Tell me your project type and I'll start the right dev server.

**For Happy Engineering MCP integration with dashboard, use Claude Code CLI: `/happy-start`**
<!-- CODEX-OVERRIDE:END -->
---
description: Start a Happy Mode session for mobile app integration
model: sonnet
---

# /happy-start - Launch Happy CLI Session

Launches a new PowerShell terminal with Happy CLI wrapping Claude Code for mobile app control.

## What This Does

1. Opens a **new PowerShell window** in the current project directory
2. Runs `npx happy-coder` which wraps Claude Code
3. Your paired Happy mobile app automatically sees the new session
4. Control this Claude session from your phone

## Prerequisites

- `happy-coder` npm package installed globally: `npm install -g happy-coder`
- Claude Code CLI authenticated: `claude auth`
- Happy mobile app paired (run `happy auth` once to pair)

## Instructions for Claude

**When this command is invoked, IMMEDIATELY execute the following Bash command:**

```bash
wt.exe -d "${CWD}" powershell -NoExit -ExecutionPolicy Bypass -File "${CWD}/bin/happy-start.ps1"
```

This uses the `happy-start.ps1` PowerShell script which:
1. Clears the `HAPPY_SERVER_URL` environment variable (prevents 401 auth errors)
2. Launches the `happy` CLI with the full path

Note: Uses Windows Terminal (`wt.exe`) with PowerShell to launch a completely independent terminal window. The PowerShell script approach avoids command parsing issues with inline commands.

After executing, respond with:

```
Happy Session Started
─────────────────────
A new PowerShell window has opened with Claude Code wrapped by Happy.

Your Happy mobile app should now see this session.
You can control Claude from your phone.

This terminal will close normally. The Happy session runs in the new window.
```

## Happy CLI Flags

| Flag | Description |
|------|-------------|
| `npx happy-coder` | Start Claude Code wrapped by Happy |
| `npx happy-coder -m opus` | Use Opus model |
| `npx happy-coder -p auto` | Auto-approve permissions |
| `npx happy-coder auth` | Pair with mobile app (one-time setup) |

{{#if happyMode.enabled}}
## Project Configuration

| Setting | Value |
|---------|-------|
| Dashboard URL | {{happyMode.dashboardUrl}} |
| Default Verbosity | {{happyMode.verbosity}} |
{{/if}}

---

*Requires: happy-coder npm package*
