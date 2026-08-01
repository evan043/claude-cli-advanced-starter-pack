---
description: GitHub Epic progress dashboard
model: haiku
---

# GitHub Epic Status - Hierarchy Progress Dashboard

You are an Epic progress tracking specialist. Display comprehensive status for the entire epic hierarchy showing epic → roadmaps → phase-dev-plans → phases → tasks with visual progress indicators and actionable insights.

## Execution Protocol

### Step 1: Load Epic Data and Hierarchy

Load epic and aggregate all child progress:

```javascript
import { loadEpic, loadOrchestratorState } from './src/epic/state-manager.js';
import { aggregateEpicProgress } from './src/orchestration/progress-aggregator.js';

const epic = loadEpic(projectRoot, epicSlug);
const state = loadOrchestratorState(projectRoot, epicSlug);

if (!epic) {
  console.error('Epic not found');
  return;
}

// Aggregate progress from all roadmaps
const epicPath = `.claude/epics/${epicSlug}`;
const progress = aggregateEpicProgress(epicPath);
```

### Step 2: Display Overview (All Epics)

When no slug provided (`/github-epic-status`), show summary table:

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                          GITHUB EPIC STATUS DASHBOARD                          ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                                 ║
║  Active Epics: 2            Completed: 1            Total Roadmaps: 12          ║
║                                                                                 ║
╠───────────────────────────────────────────────────────────────────────────────╣
║ # │ Epic Name                │ Roadmaps │ Progress    │ Status      │ Next     ║
╠───────────────────────────────────────────────────────────────────────────────╣
║ 1 │ Multi-Tenant Auth System │ 3/3      │ ██████████ 100% │ completed   │ -    ║
║ 2 │ Dashboard Refactor       │ 2/4      │ ████░░░░░░ 50%  │ active      │ RM 3 ║
║ 3 │ API v2 Migration         │ 0/5      │ ░░░░░░░░░░ 0%   │ not_started │ RM 1 ║
╚═══════════════════════════════════════════════════════════════════════════════╝

Commands:
  /github-epic-status {slug}  - View detailed epic status
  /epic-advance {slug}        - Advance to next roadmap
```

List all epics in `.claude/epics/` directory.

### Step 3: Display Detailed View (Specific Epic)

When slug provided (`/github-epic-status {slug}`), show full hierarchy:

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║  EPIC: Dashboard Refactor                                                      ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                                 ║
║  Business Objective:                                                            ║
║  Modernize admin dashboard with new component library and responsive design     ║
║                                                                                 ║
║  Success Criteria:                                                              ║
║  [x] All pages migrated to new component library                                ║
║  [x] Mobile responsive on all screen sizes                                      ║
║  [ ] Performance improved by 40%                                                ║
║  [ ] E2E test coverage > 80%                                                    ║
║                                                                                 ║
╠───────────────────────────────────────────────────────────────────────────────╣
║  Status: active          Created: 2026-01-20        GitHub: #456               ║
║  Progress: 50% (2/4)     Updated: 2026-02-04        Token: 180k/500k (36%)     ║
╚═══════════════════════════════════════════════════════════════════════════════╝

## Roadmap Breakdown

┌───┬────────────────────────────┬──────────┬────────────┬──────────────┬───────────┐
│ # │ Roadmap                    │ Plans    │ Phases     │ Status       │ Deps      │
├───┼────────────────────────────┼──────────┼────────────┼──────────────┼───────────┤
│ 1 │ Component Library Setup    │ 2/2      │ 8/8        │ ✅ complete  │ -         │
│ 2 │ Page Migration - Admin     │ 3/3      │ 12/12      │ ✅ complete  │ 1         │
│ 3 │ Page Migration - User      │ 1/2      │ 6/10       │ 🔄 active    │ 2         │
│ 4 │ Testing & Performance      │ 0/3      │ 0/15       │ ⬜ pending   │ 3         │
└───┴────────────────────────────┴──────────┴────────────┴──────────────┴───────────┘

## Hierarchy Tree View

📦 Epic: Dashboard Refactor (50%)
│
├─ ✅ Roadmap 1: Component Library Setup (100%)
│  ├─ ✅ /setup-ui-lib (100%) - 4 phases, 15 tasks
│  └─ ✅ /setup-styling (100%) - 4 phases, 12 tasks
│
├─ ✅ Roadmap 2: Page Migration - Admin (100%)
│  ├─ ✅ /migrate-dashboard (100%) - 3 phases, 8 tasks
│  ├─ ✅ /migrate-users (100%) - 4 phases, 10 tasks
│  └─ ✅ /migrate-settings (100%) - 5 phases, 12 tasks
│
├─ 🔄 Roadmap 3: Page Migration - User (60%)
│  ├─ ✅ /migrate-profile (100%) - 3 phases, 7 tasks
│  └─ 🔄 /migrate-preferences (20%) - 3/10 phases, 5/18 tasks ← CURRENT
│
└─ ⬜ Roadmap 4: Testing & Performance (0%)
   ├─ ⬜ /e2e-testing (0%) - Not started
   ├─ ⬜ /performance-audit (0%) - Not started
   └─ ⬜ /optimization (0%) - Not started
```

Use `src/orchestration/progress-aggregator.js` to calculate hierarchy:

```javascript
import { aggregateEpicProgress, formatProgressSummary } from './src/orchestration/progress-aggregator.js';

const epicPath = `.claude/epics/${epicSlug}`;
const progress = aggregateEpicProgress(epicPath);

// Display tree
console.log(formatProgressSummary(progress));
```

### Step 4: Show Current Position and Next Action

Display where execution currently is:

```
## Current Position

📍 **Roadmap 3, Phase-Dev-Plan: /migrate-preferences**
   - Phase 4/10: "Form Migration" (in progress)
   - Task 5.2/5.8: "Migrate password change form"
   - Last Updated: 2 hours ago

🎯 **Next Action Required:**
   Complete Phase 4 of /migrate-preferences:
   - [ ] Task 5.3: Migrate email preferences
   - [ ] Task 5.4: Migrate notification settings
   - [ ] Task 5.5: Update form validation

   Command: /phase-track migrate-preferences
```

Calculate using orchestrator state:

```javascript
// Find active phase-dev-plan
const activeRoadmap = epic.roadmaps[state.currentRoadmapIndex];
const roadmapPath = `.claude/roadmaps/${activeRoadmap.slug}/ROADMAP.json`;
const roadmap = JSON.parse(fs.readFileSync(roadmapPath, 'utf8'));

// Find active plan
const activePlan = roadmap.phase_dev_plan_refs.find(
  ref => ref.status === 'in_progress'
);

if (activePlan) {
  const progressPath = activePlan.path;
  const progress = JSON.parse(fs.readFileSync(progressPath, 'utf8'));

  // Find active phase
  const activePhase = progress.phases.find(p => p.status === 'in_progress');

  // Find next incomplete task
  const nextTask = activePhase?.tasks.find(t => !t.completed);

  console.log(`\n📍 Current Position:\n`);
  console.log(`   Roadmap ${state.currentRoadmapIndex + 1}: ${activeRoadmap.title}`);
  console.log(`   Plan: ${activePlan.title}`);
  console.log(`   Phase: ${activePhase?.name}`);
  console.log(`   Next Task: ${nextTask?.description}`);
}
```

### Step 5: Show Blockers at Any Level

Scan hierarchy for blockers:

```
## Blockers

⚠️ **2 blockers detected:**

1. **Roadmap 3 - Gating**
   - Tests failing: 3 E2E tests in /migrate-profile
   - Location: .claude/roadmaps/page-migration-user/
   - Action: Run `npx playwright test` or use /epic-advance to override

2. **Phase-Dev-Plan: /migrate-preferences - Dependency**
   - Blocked by: Task 4.3 must complete before Phase 5 can start
   - Location: .claude/phase-plans/migrate-preferences/PROGRESS.json
   - Action: Complete Task 4.3 first
```

Check blockers using gating module:

```javascript
import { checkGates } from './src/orchestration/gating.js';

const blockers = [];

// Check each roadmap for gating blockers
for (const roadmap of epic.roadmaps) {
  if (roadmap.status === 'completed' || roadmap.status === 'not_started') {
    continue;
  }

  const roadmapPath = getRoadmapDir(roadmap.slug);
  const gates = await checkGates(roadmapPath, epic.gating);

  if (gates.overall === 'fail') {
    blockers.push({
      level: 'roadmap',
      roadmap_index: roadmap.roadmap_index,
      title: roadmap.title,
      gates: gates.gates,
      can_override: gates.can_override
    });
  }
}

// Display blockers
if (blockers.length > 0) {
  console.log('\n## Blockers\n');
  blockers.forEach((blocker, i) => {
    console.log(`${i + 1}. **${blocker.title}** (${blocker.level})`);
    Object.entries(blocker.gates).forEach(([type, result]) => {
      if (result.result === 'fail') {
        console.log(`   - ${type}: ${result.message}`);
      }
    });
    if (blocker.can_override) {
      console.log(`   - Action: Use /epic-advance to override`);
    }
  });
}
```

### Step 6: Metrics and Insights

Display velocity and completion estimates:

```
## Metrics & Insights

📊 **Velocity:**
   - Completion Rate: 12% per day
   - Estimated Completion: 2026-02-12 (8 days remaining)
   - Trend: ⚠️ Decelerating (was 15% per day)

💡 **Recommendations:**
   - Roadmap 3 has high complexity (L) - consider parallel work
   - Testing coverage at 65% - add more E2E tests in Roadmap 4
   - Token usage at 36% - plenty of budget remaining

📈 **Completion History:**
   - Jan 20: Epic created (0%)
   - Jan 25: Roadmap 1 complete (25%)
   - Feb 01: Roadmap 2 complete (50%)
   - Feb 04: Currently at 50%
```

Calculate velocity using progress aggregator:

```javascript
import { calculateVelocity } from './src/orchestration/progress-aggregator.js';

// Load checkpoint history from orchestrator state
const progressHistory = state.checkpoints
  .filter(cp => cp.type === 'roadmap_complete')
  .map(cp => ({
    timestamp: cp.createdAt,
    completion: calculateCompletionAtCheckpoint(epic, cp)
  }));

const velocity = calculateVelocity(progressHistory);

console.log(`\n## Metrics & Insights\n`);
console.log(`📊 Velocity:`);
console.log(`   - Completion Rate: ${velocity.completion_rate}% per day`);
console.log(`   - Estimated Completion: ${velocity.estimated_completion}`);
console.log(`   - Trend: ${velocity.trend}`);
```

### Step 7: GitHub Sync Status

If GitHub integrated, show sync status:

```
## GitHub Integration

Epic Issue: #456 (open) - last synced 30 minutes ago

Child Issues:
  ✓ #457 Roadmap 1: Component Library Setup [closed]
  ✓ #458 Roadmap 2: Page Migration - Admin [closed]
  🔄 #459 Roadmap 3: Page Migration - User [open]
  ⬜ #460 Roadmap 4: Testing & Performance [open]

Phase Issues:
  ✓ #461 /setup-ui-lib [closed]
  ✓ #462 /setup-styling [closed]
  ... (15 more)
  🔄 #475 /migrate-preferences [open] ← ACTIVE

[S] Sync now    [O] Open in browser    [C] Create missing issues
```

### Step 8: Display Actions Available

Show available commands:

```
## Available Actions

[A] Advance to next roadmap        → /epic-advance {epic-slug}
[S] View specific roadmap status    → /roadmap-status {roadmap-slug}
[P] View phase-dev-plan status      → /phase-track {plan-slug}
[G] Open GitHub Epic                → gh issue view {epic-number}
[O] Override gating                 → /epic-advance {epic-slug} --override
[R] Refresh status                  → /github-epic-status {epic-slug}
[B] Back to all epics               → /github-epic-status
```

## Argument Handling

- `/github-epic-status` - Dashboard of all epics
- `/github-epic-status {slug}` - Detailed view of specific epic
- `/github-epic-status {slug} --json` - Output as JSON
- `/github-epic-status {slug} --sync` - Sync with GitHub before displaying

## Completion Calculation

Use progress aggregator to roll up completion:

```javascript
import { aggregateEpicProgress, calculateOverallCompletion } from './src/orchestration/progress-aggregator.js';

const progress = aggregateEpicProgress(epicPath);

// Progress is calculated as:
// - Epic completion = average of roadmap completions
// - Roadmap completion = average of phase-dev-plan completions
// - Phase-dev-plan completion = (completed tasks / total tasks) * 100
```

## Performance Considerations

For large epics with many roadmaps:
- Cache progress calculations
- Load roadmap details on-demand
- Use pagination for hierarchy tree (show top 2 levels, expand on request)

## Related Commands

- `/create-github-epic` - Create new epic
- `/epic-advance {slug}` - Advance epic manually
- `/roadmap-status {slug}` - View roadmap details
- `/phase-track {slug}` - Track phase-dev-plan progress

## Enforcement Rules

| Rule | Implementation |
|------|----------------|
| Use progress aggregator | Import from `src/orchestration/progress-aggregator.js` |
| Show entire hierarchy | Epic → Roadmap → Phase-Dev-Plan → Phase → Task |
| Calculate velocity | Use checkpoint history from orchestrator state |
| Display blockers | Check gating at all levels |
| Support JSON export | --json flag for programmatic access |

---

*GitHub Epic Status - Part of CCASP Epic-Hierarchy Refactor*
