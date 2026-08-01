---
description: Advance epic to next roadmap
model: sonnet
---

# Epic Advance - Manual Epic Progression

You are an Epic execution specialist. Allow manual advancement through epic roadmaps with gating override support and decision logging.

## Purpose

This command provides manual control over epic progression when:
- Automatic gating is blocking advancement
- User wants to skip ahead to a specific roadmap
- Testing results need manual review
- Override is needed for development/debugging

## Execution Protocol

### Step 1: Load Epic State

Load epic and orchestrator state:

```javascript
import { loadEpic, loadOrchestratorState } from './src/epic/state-manager.js';
import { getNextRoadmap } from './src/epic/schema.js';

const epic = loadEpic(projectRoot, epicSlug);
const state = loadOrchestratorState(projectRoot, epicSlug);

if (!epic) {
  console.error('Epic not found');
  return;
}
```

### Step 2: Display Current Position

Show user where they are in the epic:

```
╔═══════════════════════════════════════════════════════════════════════╗
║  EPIC POSITION: {epic_name}                                            ║
╠═══════════════════════════════════════════════════════════════════════╣
║                                                                         ║
║  Overall Progress: {completion_percentage}%                             ║
║  Current Roadmap Index: {current_roadmap_index + 1}/{total_roadmaps}   ║
║                                                                         ║
╠───────────────────────────────────────────────────────────────────────╣
║  ROADMAP STATUS                                                         ║
╠───────────────────────────────────────────────────────────────────────╣
║                                                                         ║
║  ✓ Roadmap 1: {title} (100% - COMPLETED)                               ║
║  ✓ Roadmap 2: {title} (100% - COMPLETED)                               ║
║  → Roadmap 3: {title} (45% - IN PROGRESS) ← CURRENT                    ║
║  ⬜ Roadmap 4: {title} (0% - PENDING)                                   ║
║  ⬜ Roadmap 5: {title} (0% - PENDING)                                   ║
║                                                                         ║
╚═══════════════════════════════════════════════════════════════════════╝
```

### Step 3: Check Gating Requirements

Check if advancement is blocked:

```javascript
import { checkGatingRequirements } from './src/epic/state-manager.js';
import { checkGates } from './src/orchestration/gating.js';

const nextRoadmapResult = getNextRoadmap(epic);

if (!nextRoadmapResult) {
  console.log('✅ Epic is complete! No more roadmaps to execute.');
  return;
}

if (nextRoadmapResult.blocked) {
  console.log('\n⚠️ Gating Requirements Not Met:\n');
  nextRoadmapResult.blockers.forEach(b => {
    console.log(`   - ${b}`);
  });

  if (nextRoadmapResult.canOverride) {
    console.log('\n🔓 Manual override is ALLOWED for this epic.');
  } else {
    console.log('\n🔒 Manual override is NOT ALLOWED. Fix blockers first.');
    return;
  }
}
```

Display gating status:

```
╔═══════════════════════════════════════════════════════════════════════╗
║  GATING STATUS                                                          ║
╠═══════════════════════════════════════════════════════════════════════╣
║                                                                         ║
║  Next Roadmap: Roadmap 4 - {title}                                      ║
║                                                                         ║
║  ⚠️ BLOCKERS DETECTED:                                                  ║
║     • Previous roadmap tests failing (3 failed)                         ║
║     • Documentation incomplete (2 files missing)                        ║
║                                                                         ║
║  Gating Configuration:                                                  ║
║     • Tests Required: YES                                               ║
║     • Docs Required: NO                                                 ║
║     • Manual Override: ENABLED                                          ║
║                                                                         ║
╚═══════════════════════════════════════════════════════════════════════╝
```

### Step 4: Request User Decision

Use AskUserQuestion to get advancement decision:

```
header: "Epic Advancement Decision"
question: "How do you want to proceed?"
options:
  - label: "Advance anyway (Override blockers)"
    value: "override"
    description: "Skip gating checks and advance to next roadmap"

  - label: "Jump to specific roadmap"
    value: "jump"
    description: "Skip to a specific roadmap by index"

  - label: "Re-run gating checks"
    value: "recheck"
    description: "Re-run tests and gating validation"

  - label: "Cancel"
    value: "cancel"
    description: "Return without advancing"
```

### Step 5A: Override and Advance

If user chooses "override":

1. **Confirm override with reason:**

```
header: "Override Confirmation"
question: "Provide reason for override (required for logging):"
input_type: "text"
```

2. **Log override decision:**

```javascript
import { createCheckpoint } from './src/epic/state-manager.js';
import { logGateDecision } from './src/orchestration/gating.js';

// Log to epic orchestrator state
await createCheckpoint(projectRoot, epicSlug, 'Manual override', {
  type: 'manual_override',
  roadmap_index: state.currentRoadmapIndex,
  override_reason: userReason,
  blockers_overridden: nextRoadmapResult.blockers,
  timestamp: new Date().toISOString(),
  decision_maker: 'user'
});

// Log to gating system
logGateDecision(
  epicPath,
  nextRoadmapResult.roadmap.roadmap_id,
  {
    overall: 'fail',
    gates: gateResults,
    can_override: true
  },
  'override'
);
```

3. **Advance to next roadmap:**

```javascript
import { advanceToNextRoadmap, updateRoadmapStatus } from './src/epic/state-manager.js';

// Mark current roadmap as complete (even if tests failed)
await updateRoadmapStatus(
  projectRoot,
  epicSlug,
  currentRoadmap.roadmap_id,
  'completed',
  { override: true, override_reason: userReason }
);

// Advance
const { nextRoadmap, epicComplete } = await advanceToNextRoadmap(
  projectRoot,
  epicSlug,
  currentRoadmap.roadmap_id
);

if (epicComplete) {
  console.log('\n🎉 Epic completed (with overrides)!');
} else {
  console.log(`\n✅ Advanced to Roadmap ${nextRoadmap.roadmap_index + 1}: ${nextRoadmap.title}`);
  console.log('⚠️ Override logged. Consider fixing issues before next advancement.');
}
```

### Step 5B: Jump to Specific Roadmap

If user chooses "jump":

1. **Ask for roadmap index:**

```
header: "Jump to Roadmap"
question: "Which roadmap do you want to jump to?"
input_type: "number"
min: 1
max: {total_roadmaps}
```

2. **Confirm jump:**

```
header: "Confirm Jump"
question: "Jump to Roadmap {target_index}? This will skip Roadmaps {current + 1} to {target - 1}."
options:
  - label: "Yes - Jump ahead"
    value: "confirm"
  - label: "Cancel"
    value: "cancel"
```

3. **Require override reason if skipping:**

```
header: "Skip Reason"
question: "Provide reason for skipping roadmaps (required for logging):"
input_type: "text"
```

4. **Execute jump:**

```javascript
// Mark all skipped roadmaps as "skipped"
for (let i = state.currentRoadmapIndex + 1; i < targetIndex; i++) {
  await updateRoadmapStatus(
    projectRoot,
    epicSlug,
    epic.roadmaps[i].roadmap_id,
    'skipped',
    { reason: skipReason }
  );
}

// Update orchestrator state
const stateUpdate = await loadOrchestratorState(projectRoot, epicSlug);
stateUpdate.currentRoadmapIndex = targetIndex;
await saveOrchestratorState(projectRoot, epicSlug, stateUpdate);

// Log checkpoint
await createCheckpoint(projectRoot, epicSlug, 'Jumped to roadmap', {
  type: 'roadmap_jump',
  from_index: state.currentRoadmapIndex,
  to_index: targetIndex,
  skipped_count: targetIndex - state.currentRoadmapIndex - 1,
  reason: skipReason
});

console.log(`\n✅ Jumped to Roadmap ${targetIndex + 1}: ${epic.roadmaps[targetIndex].title}`);
```

### Step 5C: Re-run Gating Checks

If user chooses "recheck":

```javascript
console.log('\n🔄 Re-running gating checks...\n');

const currentRoadmapPath = getRoadmapDir(epic.roadmaps[state.currentRoadmapIndex].slug);
const gates = await checkGates(currentRoadmapPath, epic.gating);

console.log(formatGateResults(gates));

if (gates.overall === 'pass') {
  console.log('\n✅ All gates passed! Safe to advance.');

  // Auto-advance if all gates pass
  const { nextRoadmap, epicComplete } = await advanceToNextRoadmap(
    projectRoot,
    epicSlug,
    epic.roadmaps[state.currentRoadmapIndex].roadmap_id
  );

  if (epicComplete) {
    console.log('\n🎉 Epic completed!');
  } else {
    console.log(`\n✅ Advanced to Roadmap ${nextRoadmap.roadmap_index + 1}: ${nextRoadmap.title}`);
  }
} else {
  console.log('\n❌ Gates still failing. Use override or fix issues.');
}
```

### Step 6: Display Updated Status

Show final epic state:

```
╔═══════════════════════════════════════════════════════════════════════╗
║  ✓ Epic Advanced                                                       ║
╠═══════════════════════════════════════════════════════════════════════╣
║                                                                         ║
║  Epic: {epic_name}                                                      ║
║  Current Position: Roadmap {new_index + 1}/{total_roadmaps}            ║
║  Overall Progress: {new_completion_percentage}%                         ║
║                                                                         ║
║  Overrides Logged: {override_count}                                     ║
║  Checkpoints: {checkpoint_count}                                        ║
║                                                                         ║
║  Next Steps:                                                            ║
║  1. Review status: /github-epic-status {epic-slug}                      ║
║  2. Execute roadmap: /create-roadmap --parent-epic={epic-slug}          ║
║  3. Check overrides: View checkpoints in orchestrator-state.json        ║
║                                                                         ║
╚═══════════════════════════════════════════════════════════════════════╝
```

## Override Logging

All override decisions are logged to:

**File:** `.claude/epics/{epic-slug}/state/orchestrator-state.json`

**Log Entry Format:**

```json
{
  "checkpoints": [
    {
      "checkpointId": "uuid-v4",
      "createdAt": "2026-02-04T10:30:00Z",
      "roadmapIndex": 2,
      "type": "manual_override",
      "summary": "Manual override to advance despite test failures",
      "override_reason": "Tests are flaky, proceeding with manual verification",
      "blockers_overridden": [
        "Tests failed for previous roadmap",
        "3 E2E tests failing"
      ],
      "decision_maker": "user"
    }
  ]
}
```

## Confirmation Requirements

**Always require confirmation for:**
- Skipping tests (if require_tests: true)
- Jumping ahead (skipping roadmaps)
- Advancing with documentation incomplete (if require_docs: true)

**Confirmation dialog:**

```
╔═══════════════════════════════════════════════════════════════════════╗
║  ⚠️ CONFIRMATION REQUIRED                                              ║
╠═══════════════════════════════════════════════════════════════════════╣
║                                                                         ║
║  You are about to SKIP TESTS and advance.                               ║
║                                                                         ║
║  Risks:                                                                 ║
║  • Untested code may break downstream work                              ║
║  • Integration issues may surface later                                 ║
║  • Epic quality gates may fail at final validation                      ║
║                                                                         ║
║  Override Reason: "{user_reason}"                                       ║
║                                                                         ║
║  Type "CONFIRM" to proceed:                                             ║
║                                                                         ║
╚═══════════════════════════════════════════════════════════════════════╝
```

## Argument Handling

- `/epic-advance {epic-slug}` - Interactive mode
- `/epic-advance {epic-slug} --override "{reason}"` - Auto-override with reason
- `/epic-advance {epic-slug} --jump {index}` - Jump to specific roadmap
- `/epic-advance {epic-slug} --recheck` - Re-run gating checks only

## Error Handling

If advancement fails:
1. Report specific error
2. Preserve current state (do not corrupt epic)
3. Show rollback options
4. Display troubleshooting steps

## Related Commands

- `/github-epic-status {slug}` - View current epic status
- `/create-github-epic` - Create new epic
- `/create-roadmap --parent-epic={slug}` - Execute roadmap under epic

## Enforcement Rules

| Rule | Implementation |
|------|----------------|
| Require override reason | Text input required for all overrides |
| Log all decisions | All overrides logged to orchestrator-state.json |
| Confirmation for skip tests | Require "CONFIRM" typing for test skips |
| Preserve epic state | Never corrupt EPIC.json or orchestrator state |
| Support gating module | Use `src/orchestration/gating.js` |

---

*Epic Advance - Part of CCASP Epic-Hierarchy Refactor*
