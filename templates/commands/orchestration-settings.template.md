---
description: View and modify orchestration settings (parallel agents, compacting)
model: haiku
---

# /orchestration-settings - Parallel & Compacting Configuration

View or modify how parallel agents and context compacting behave during `/phase-track --parallel` and `/roadmap-track run-all --parallel`.

## Current Settings

Read settings from `tech-stack.json` at `.claude/config/tech-stack.json`:

```javascript
const settings = techStack.orchestration || {
  parallel: { maxTasks: 2, maxPlans: 2, maxRoadmaps: 2 },
  compacting: {
    remainingThreshold: 40,
    pollIntervalSec: 120,
    compactAfterLaunch: true,
    compactAfterPoll: true,
  },
};
```

## Display Current Config

Show a compact summary:

```
Orchestration Settings
━━━━━━━━━━━━━━━━━━━━━

Parallel Agents
  Tasks per phase:     {{parallel.maxTasks}}
  Plans per roadmap:   {{parallel.maxPlans}}
  Roadmaps per epic:   {{parallel.maxRoadmaps}}

Context Compacting
  Auto-compact at:     {{compacting.remainingThreshold}}% remaining
  Poll interval:       {{compacting.pollIntervalSec}}s
  Compact after launch: {{compacting.compactAfterLaunch}}
  Compact after poll:   {{compacting.compactAfterPoll}}
```

## Modify Settings

When the user provides arguments, update the specified values:

| Argument | Effect |
|----------|--------|
| `/orchestration-settings` | Display current config |
| `/orchestration-settings --max-tasks N` | Set max parallel tasks per phase |
| `/orchestration-settings --max-plans N` | Set max parallel plans per roadmap |
| `/orchestration-settings --compact-at N` | Set remaining context % threshold |
| `/orchestration-settings --poll N` | Set poll interval in seconds |
| `/orchestration-settings --interactive` | Open interactive menu (same as CLI `ccasp` settings option 8) |

## Instructions for Claude

1. Read `.claude/config/tech-stack.json`
2. If no arguments: display current settings using the format above
3. If arguments provided: update the specified fields and save
4. Use `AskUserQuestion` for `--interactive` mode with these options:
   - Max parallel tasks (1-4)
   - Max parallel plans (1-3)
   - Compact threshold (20-50% remaining)
   - Poll interval (60-300 seconds)
   - Compact after launch (yes/no)
   - Compact after poll (yes/no)

## Defaults

If `orchestration` key doesn't exist in tech-stack.json, use:

```json
{
  "orchestration": {
    "parallel": {
      "maxTasks": 2,
      "maxPlans": 2,
      "maxRoadmaps": 2
    },
    "compacting": {
      "remainingThreshold": 40,
      "pollIntervalSec": 120,
      "compactAfterLaunch": true,
      "compactAfterPoll": true
    }
  }
}
```

## Settings Precedence

Orchestration settings can come from two sources:

1. **Artifact-level** (highest priority): `orchestration` block embedded in PROGRESS.json / ROADMAP.json / EPIC.json
2. **Global defaults** (fallback): `orchestration` in tech-stack.json

When a new plan, roadmap, or epic is created, global defaults from tech-stack.json are copied INTO the artifact's `orchestration` block. After that, the artifact's copy is authoritative.

**Changing global defaults only affects NEW plans.** Existing plans retain their embedded config.

### Apply Globals to Existing Artifact

```
/orchestration-settings --apply-to <artifact-path>
```

Copies current global defaults into the specified PROGRESS.json, ROADMAP.json, or EPIC.json file, overwriting its embedded orchestration block.

### Artifact Orchestration Fields

| Artifact | Fields |
|----------|--------|
| PROGRESS.json | `mode`, `max_parallel_agents`, `batch_strategy`, `compact_threshold_percent`, `poll_interval_seconds`, `compact_after_launch`, `compact_after_poll`, `agent_model` |
| ROADMAP.json | `max_parallel_plans`, `plan_batch_strategy`, `compact_before_plan`, `compact_after_plan`, `context_threshold_percent`, `agent_model` |
| EPIC.json | `max_parallel_roadmaps`, `roadmap_batch_strategy`, `compact_before_roadmap`, `context_threshold_percent`, `agent_model` |

## Related Commands

- `/phase-track {slug} --run-all --parallel` - Uses these settings for task parallelism
- `/roadmap-track {slug} run-all --parallel` - Uses these settings for plan parallelism

---

*Part of CCASP Orchestration System*
