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
# vdb-status — Not Supported in Codex

This command requires Claude Code CLI infrastructure that has no Codex equivalent:
- **Vision Driver Bot (VDB)**: Requires Claude Code hooks system for autonomous session management
- **Task() orchestration**: Multi-agent spawning is Claude Code CLI-specific
- **Pre/PostToolUse hooks**: Codex does not support Claude's hook system

## Use Claude Code CLI Instead

To use this command, switch to Claude Code CLI and run `/vdb-status`.

VDB provides autonomous development with self-healing execution loops — this requires the full Claude Code CLI runtime environment.
<!-- CODEX-OVERRIDE:END -->
---
description: Vision Driver Bot status
model: haiku
---

# Vision Driver Bot Status

Check the current status of the Vision Driver Bot, including queue status, recent executions, and recommendations.

## Instructions

1. **Load VDB State**

Read the VDB configuration and state files:
- `.claude/vdb/config.json` - VDB configuration
- `.claude/vdb/state.json` - Current state
- `.claude/vdb/queue.json` - Task queue
- `.claude/vdb/recommendations.json` - AI recommendations

2. **Check Queue Status**

Display the current task queue:
- Number of queued tasks
- Currently executing task (if any)
- Next task in line

3. **Recent Executions**

Read `.claude/vdb/queue-history.json` and show:
- Last 5 completed tasks
- Any recent failures
- Success rate

4. **Velocity Metrics**

Read `.claude/pm-hierarchy/completion-tracking.json` and show:
- Daily completion rate
- Weekly trend
- Average task duration

5. **Recommendations**

If there are pending recommendations in `.claude/vdb/recommendations.json`:
- Display each recommendation with priority
- Suggest actions to take

6. **Board Connection**

Verify board connectivity:
- Check GitHub connection via `gh auth status`
- Show linked repository
- Show project board number if configured

## Output Format

```
╔════════════════════════════════════════════════════════════════╗
║                    VISION DRIVER BOT STATUS                    ║
╠════════════════════════════════════════════════════════════════╣
║ Status: [Active/Idle/Paused]                                   ║
║ Last Scan: [timestamp]                                         ║
║ Last Execution: [timestamp]                                    ║
╠════════════════════════════════════════════════════════════════╣
║ QUEUE                                                          ║
║ ├─ Queued: [n] tasks                                           ║
║ ├─ Executing: [task name or "None"]                            ║
║ └─ Next: [task name or "Empty"]                                ║
╠════════════════════════════════════════════════════════════════╣
║ VELOCITY (Last 7 days)                                         ║
║ ├─ Phases completed: [n]                                       ║
║ ├─ Success rate: [n]%                                          ║
║ └─ Avg duration: [n] minutes                                   ║
╠════════════════════════════════════════════════════════════════╣
║ RECOMMENDATIONS                                                ║
║ ├─ [P1] Description...                                         ║
║ └─ [P2] Description...                                         ║
╚════════════════════════════════════════════════════════════════╝
```

## Troubleshooting

If VDB is not configured:
- Suggest running `ccasp vdb init` to set up VDB
- Or create configuration manually in `.claude/vdb/config.json`
