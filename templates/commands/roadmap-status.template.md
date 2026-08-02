---
description: Roadmap progress dashboard
model: haiku
---

# Roadmap Status - Multi-Phase Progress Dashboard

You are a roadmap progress tracking specialist. Display comprehensive status for roadmaps and their phases.

## Execution Protocol

### Step 1: Discover Roadmaps

Scan for roadmap files:
- `.claude/docs/roadmaps/*/ROADMAP.json`
- `.claude/roadmaps/*.json`
- `ROADMAP.json` in project root

### Step 2: Load and Parse

For each discovered roadmap:
1. Load ROADMAP.json
2. For each project/phase, load its PROGRESS.json
3. Calculate completion percentages
4. Identify blocked items

### Step 3: Display Dashboard

```
╔═══════════════════════════════════════════════════════════════════════════╗
║                        ROADMAP STATUS DASHBOARD                            ║
╠═══════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  Active Roadmaps: {{count}}                                                 ║
║                                                                             ║
╠═══════════════════════════════════════════════════════════════════════════╣
{{#each roadmaps}}
║                                                                             ║
║  📋 {{name}} ({{slug}})                                                     ║
║  ────────────────────────────────────────────────────────────────────────── ║
║                                                                             ║
║  Progress: [{{progressBar}}] {{percentage}}%                                ║
║  Phases: {{completedPhases}}/{{totalPhases}} complete                       ║
║  Tasks: {{completedTasks}}/{{totalTasks}} complete                          ║
{{#if githubIssue}}
║  GitHub: #{{issueNumber}} ({{issueUrl}})                                    ║
{{/if}}
║                                                                             ║
║  Phase Status:                                                              ║
{{#each phases}}
║    {{statusEmoji}} Phase {{number}}: {{name}}                               ║
║       Status: {{status}} | Tasks: {{taskProgress}}                          ║
{{#if blocked}}
║       ⚠️ BLOCKED: {{blockedReason}}                                         ║
{{/if}}
{{/each}}
║                                                                             ║
{{/each}}
╚═══════════════════════════════════════════════════════════════════════════╝
```

### Progress Bar Generation

Generate visual progress bar:
- 40 characters wide
- `█` for completed sections
- `░` for remaining sections
- Example: `████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░` (30%)

### Status Emoji Legend

| Status | Emoji | Meaning |
|--------|-------|---------|
| completed | ✅ | Phase/task complete |
| in_progress | 🔄 | Currently working |
| pending | ⬜ | Not started |
| blocked | 🚫 | Dependencies not met |

### Argument Handling

- `/roadmap-status` - Show all roadmaps
- `/roadmap-status {slug}` - Show specific roadmap details
- `/roadmap-status --sync` - Sync with GitHub and show status
- `/roadmap-status --verbose` - Show task-level details

### Detailed View (specific roadmap)

When a specific roadmap is requested, show:

1. **Dependency Graph** (Mermaid)
2. **Phase Details** with all tasks
3. **Blockers** and dependencies
4. **Next Actions** recommendations
5. **GitHub Sync Status** (if integrated)

### Dependency Validation

Check and report:
- Phases with unmet dependencies
- Circular dependencies (error)
- Next available phases to start

### Next Actions

Based on current state, suggest:
- Which phase to work on next
- Tasks ready to start
- Blocked items needing attention

## Output Format

Use Read tool to load roadmap files, then format output as shown above.

For GitHub sync, check:
- Issue status matches PROGRESS.json
- Comments have progress updates
- Milestone status is accurate

## Related Commands

- `/create-roadmap` - Create new roadmap
- `/phase-track` - Track individual phase
- `/github-update` - GitHub Project Board status

---

*Roadmap Status - Part of CCASP Multi-Phase Development System*
