<!-- CODEX-SUPPORT: unsupported -->

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
# vdb-init — Not Supported in Codex

This command requires Claude Code CLI infrastructure that has no Codex equivalent:
- **Vision Driver Bot (VDB)**: Requires Claude Code hooks system for autonomous session management
- **Task() orchestration**: Multi-agent spawning is Claude Code CLI-specific
- **Pre/PostToolUse hooks**: Codex does not support Claude's hook system

## Use Claude Code CLI Instead

To use this command, switch to Claude Code CLI and run `/vdb-init`.

VDB provides autonomous development with self-healing execution loops — this requires the full Claude Code CLI runtime environment.
<!-- CODEX-OVERRIDE:END -->
---
description: Vision Driver Bot initialization
model: sonnet
---

# Vision Driver Bot - Initialize

Set up Vision Driver Bot for this project. This configures autonomous development from your Vision/Epic board.

## What This Does

1. **Creates VDB Configuration** (`.claude/vdb/config.json`)
   - Detects GitHub repository from git remote
   - Sets up board connections
   - Configures execution settings
   - Sets safety constraints

2. **Creates Directory Structure**
   ```
   .claude/vdb/
   ├── config.json         # VDB configuration
   ├── state.json          # Runtime state
   ├── queue.json          # Task queue
   ├── queue-history.json  # Completed tasks
   ├── recommendations.json # AI recommendations
   ├── logs/               # Execution logs
   └── summaries/          # Daily/epic summaries
   ```

3. **Installs GitHub Actions Workflow**
   - Copies `vision-driver-bot.yml` to `.github/workflows/`
   - Configures scheduled execution (every 15 minutes)
   - Sets up manual trigger options

## Prerequisites

Before running init:
- [ ] Project is a git repository
- [ ] GitHub remote is configured
- [ ] `gh` CLI is installed and authenticated

## Instructions

1. **Detect Repository**

Run:
```bash
git remote get-url origin
```

Parse owner and repo from the URL.

2. **Create Configuration**

Create `.claude/vdb/config.json` with:
```json
{
  "version": "1.0.0",
  "boards": {
    "primary": "github",
    "github": {
      "enabled": true,
      "owner": "<detected>",
      "repo": "<detected>",
      "projectNumber": null,
      "labels": {
        "epic": "epic",
        "phase": "phase-dev",
        "vdbManaged": "vdb-managed"
      }
    },
    "local": {
      "enabled": true,
      "epicDir": ".claude/github-epics",
      "roadmapDir": ".claude/roadmaps"
    }
  },
  "execution": {
    "mode": "github-actions",
    "autoCommit": true,
    "autoPush": true
  },
  "created": "<timestamp>"
}
```

3. **Create Directories**

```bash
mkdir -p .claude/vdb/logs
mkdir -p .claude/vdb/summaries
```

4. **Copy Workflow**

Copy the GitHub Actions workflow template to `.github/workflows/vision-driver-bot.yml`.

5. **Create Labels** (optional)

If the user confirms, create GitHub labels:
```bash
gh label create "epic" --color "7057ff" --description "Epic-level work item"
gh label create "phase-dev" --color "0366d6" --description "Development phase"
gh label create "vdb-managed" --color "1d76db" --description "Managed by VDB"
```

## Post-Init Steps

Display these instructions to the user:

```
╔═══════════════════════════════════════════════════════════════╗
║           VDB INITIALIZED SUCCESSFULLY! 🤖                    ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║ Next steps:                                                   ║
║                                                               ║
║ 1. Add secrets to GitHub repository:                          ║
║    • ANTHROPIC_API_KEY - Your Anthropic API key              ║
║    • VDB_PAT - Personal Access Token with repo+project scope ║
║                                                               ║
║ 2. (Optional) Create a GitHub Project board:                  ║
║    gh project create --owner <owner> --title "Vision Board"  ║
║    Then update projectNumber in .claude/vdb/config.json      ║
║                                                               ║
║ 3. Create your first epic:                                    ║
║    • Use /create-github-epic command                          ║
║    • Or create issues with 'epic' label on GitHub             ║
║                                                               ║
║ 4. Push to trigger the workflow:                              ║
║    git add .claude .github                                    ║
║    git commit -m "feat: initialize Vision Driver Bot"         ║
║    git push                                                   ║
║                                                               ║
║ The bot will start scanning every 15 minutes!                 ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

## Configuration Options

During init, optionally ask:

1. **Poll Frequency**
   - Every 5 minutes (aggressive)
   - Every 15 minutes (default)
   - Every hour (conservative)

2. **Execution Mode**
   - Auto (scan + execute) - default
   - Scan only (manual execution)

3. **Branch Strategy**
   - Direct to main/master
   - Feature branches (vdb/phase-*)

4. **Notifications**
   - None (default)
   - Slack webhook
   - Discord webhook
