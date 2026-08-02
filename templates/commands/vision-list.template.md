---
description: List and manage multiple visions with registry-backed status overview
options:
  - label: "List All"
    description: "Show all visions with status and plan type"
  - label: "Active Only"
    description: "Show only active (non-completed/failed) visions"
  - label: "Cleanup"
    description: "Remove stale or failed visions"
---

# Vision List - Multi-Vision Management

View, filter, and manage multiple visions from the centralized registry. Registry-backed for fast O(1) lookups instead of filesystem scanning.

**Vision Architecture:**
```
VISION (L0+) → EPIC (L0) → ROADMAP (L1) → PHASE-DEV (L2) → TASKS (L3)
```

---

## Execution Protocol

### Step 1: Load Registry Data

```javascript
import { getRegisteredVisions, getActiveVisions, getVisionCount, getVisionStatus, describePlanType } from '${CWD}/node_modules/claude-cli-advanced-starter-pack/src/vision/index.js';

const projectRoot = '${CWD}';
const { total, active } = getVisionCount(projectRoot);
const visions = getRegisteredVisions(projectRoot);
const activeVisions = getActiveVisions(projectRoot);
```

### Step 2: Display Vision List

```
╔════════════════════════════════════════════════════════════════════════════╗
║                        VISION REGISTRY                                     ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                            ║
║  Total: {{total}} vision(s), {{active}} active                             ║
║                                                                            ║
╠════════════════════════════════════════════════════════════════════════════╣
║  SLUG                    STATUS         PLAN TYPE        PROGRESS  TITLE   ║
║  ────────────────────────────────────────────────────────────────────────  ║
{{#each visions}}
║  {{slug}}                {{status}}     {{planLabel}}    {{pct}}%  {{title}}║
{{/each}}
║                                                                            ║
╚════════════════════════════════════════════════════════════════════════════╝
```

**Plan Type Legend:**
| Type | Label | Description |
|------|-------|-------------|
| task-list | Task List | Simple flat task list (score 0-6) |
| phase-dev-plan | Phase Dev Plan | Phased tasks (score 7-14) |
| roadmap | Roadmap | Multi-phase roadmap (score 15-25) |
| epic | Epic | Epic with roadmaps (score 26-40) |
| vision-full | Full Vision | Complete hierarchy (score 41+) |

### Step 3: Filter Options

**Active only** (default when many visions exist):
```javascript
const active = getActiveVisions(projectRoot);
// Shows only visions with status not 'completed' or 'failed'
```

**By plan type:**
```javascript
const filtered = visions.filter(v => v.plan_type === 'roadmap');
```

**By status:**
```javascript
const filtered = visions.filter(v => v.status === 'executing');
```

### Step 4: Quick Actions Per Vision

For each vision displayed, offer:
- `/vision-status {slug}` - View detailed status
- `/vision-run {slug}` - Execute/resume
- `/vision-adjust {slug}` - Adjust plan
- `ccasp vision cleanup` - Remove stale visions

### Step 5: Cleanup Mode

When `--cleanup` or "Cleanup" option selected:

```javascript
import { visionCleanup } from '${CWD}/node_modules/claude-cli-advanced-starter-pack/src/commands/vision-cmd/operations.js';

// Dry run first
await visionCleanup(projectRoot, { dryRun: true });

// Then with confirmation
await visionCleanup(projectRoot, { force: false });
```

**Cleanup identifies:**
- Orphaned registry entries (directory missing)
- Failed visions
- Visions matching a specific status filter

```
╔════════════════════════════════════════════════════════════════════════════╗
║                      VISION CLEANUP REPORT                                 ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                            ║
║  Candidates:                                                               ║
{{#each candidates}}
║    - {{slug}} [{{status}}] → {{reason}}                                    ║
{{/each}}
║                                                                            ║
║  Proceed with cleanup? (yes/no/dry-run)                                    ║
║                                                                            ║
╚════════════════════════════════════════════════════════════════════════════╝
```

## CLI Alternative

```bash
# List all visions
ccasp vision list

# JSON output
ccasp vision list --json

# Cleanup stale visions
ccasp vision cleanup

# Cleanup dry run
ccasp vision cleanup --dry-run

# Force cleanup of failed visions
ccasp vision cleanup --force
```

## Argument Handling

- `/vision-list` - Show all visions (default)
- `/vision-list --active` - Active visions only
- `/vision-list --cleanup` - Run cleanup mode
- `/vision-list --json` - JSON output

## Related Commands

- `/vision-init` - Initialize new Vision
- `/vision-status` - Detailed status for one vision
- `/vision-run` - Execute a vision
- `/vision-adjust` - Adjust vision plan

---

*Vision List - Part of CCASP Vision Mode Multi-Instance Management*
