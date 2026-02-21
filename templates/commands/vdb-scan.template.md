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
# vdb-scan — Not Supported in Codex

This command requires Claude Code CLI infrastructure that has no Codex equivalent:
- **Vision Driver Bot (VDB)**: Requires Claude Code hooks system for autonomous session management
- **Task() orchestration**: Multi-agent spawning is Claude Code CLI-specific
- **Pre/PostToolUse hooks**: Codex does not support Claude's hook system

## Use Claude Code CLI Instead

To use this command, switch to Claude Code CLI and run `/vdb-scan`.

VDB provides autonomous development with self-healing execution loops — this requires the full Claude Code CLI runtime environment.
<!-- CODEX-OVERRIDE:END -->
---
description: Vision Driver Bot board scan
model: haiku
---

# Vision Driver Bot - Scan Board

Scan the Vision/Epic board for actionable items and queue them for execution.

## Instructions

1. **Load Configuration**

Read `.claude/vdb/config.json` for board settings.

2. **Fetch Board State**

Scan for epics and phases from configured sources:

**GitHub (if enabled):**
```bash
# Fetch epic issues
gh issue list --label "epic" --json number,title,body,state,labels --limit 100

# Fetch phase issues for each epic
gh issue list --label "phase-dev" --json number,title,body,state,labels --limit 100
```

**Local (always enabled):**
- Read `.claude/github-epics/*.json`
- Read `.claude/roadmaps/*.json` (legacy)

3. **Find Actionable Items**

For each active epic, check phases:
- Status is `pending` (not completed or in_progress)
- All dependencies are resolved (completed)
- Not already in queue

4. **Calculate Priority**

Score each actionable item:
- Epic priority (P0=100, P1=80, P2=60, P3=40, P4=20)
- Complexity bonus (S=30, M=20, L=10)
- Vision alignment bonus (Core=15, Strategic=10)
- Staleness bonus (days since update × 2, max 20)

5. **Queue Items**

Add top items to queue (up to `maxQueuePerScan` from config):
- Write to `.claude/vdb/queue.json`
- Apply prioritization strategy (priority/balanced/fifo)

6. **Report Results**

Display scan summary:
```
╔═══════════════════════════════════════╗
║           VDB BOARD SCAN              ║
╠═══════════════════════════════════════╣
║ Epics scanned: [n]                    ║
║ Active epics: [n]                     ║
║ Phases checked: [n]                   ║
║ Actionable items found: [n]           ║
║ Queued: [n]                           ║
╠═══════════════════════════════════════╣
║ TOP ITEMS:                            ║
║ 1. [Phase Title] (Score: [n])         ║
║ 2. [Phase Title] (Score: [n])         ║
║ 3. [Phase Title] (Score: [n])         ║
╚═══════════════════════════════════════╝
```

## Arguments

- `--dry-run` - Scan without queuing (show what would be queued)
- `--include-blocked` - Also check blocked items for unblock status
- `--limit N` - Maximum items to queue (default: from config)

## After Scanning

The queued items can be executed by:
1. GitHub Actions workflow (automatic, every 15 min)
2. `/vdb-execute-next` command (manual)
3. `ccasp vdb execute-next` CLI command
