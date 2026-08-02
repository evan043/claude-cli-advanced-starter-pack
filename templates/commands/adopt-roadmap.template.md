---
description: Adopt orphan roadmaps or phase-dev-plans into parent hierarchies
---

# Adopt Roadmap/Plan - Hierarchy Adoption Manager

Integrate standalone roadmaps and phase-dev-plans into epic/roadmap hierarchies after creation.

**Use Cases:**
- Started with standalone roadmap, now want to group under an epic
- Created phase-dev-plan independently, now want to add to roadmap
- Restructuring project hierarchy mid-flight
- Late-stage epic/roadmap organization

---

## When to Use This Command

Use `/adopt-roadmap` when:
- You have orphan roadmaps (created without `--parent-epic`)
- You have orphan phase-dev-plans (created without `--parent-roadmap`)
- You want to reorganize existing work into epic/roadmap structure
- You started standalone and now need hierarchy

---

## Execution Protocol

### Step 1: Choose Adoption Type

Ask user which type of adoption to perform:

```
╔═══════════════════════════════════════════════════════════════╗
║  Hierarchy Adoption Manager                                   ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  What would you like to adopt?                                ║
║                                                               ║
║  A) Adopt roadmap into epic                                   ║
║     - Adds parent_epic reference to roadmap                   ║
║     - Updates epic with new roadmap                           ║
║     - Syncs GitHub issues with breadcrumb                     ║
║                                                               ║
║  B) Adopt phase-dev-plan into roadmap                         ║
║     - Adds parent_context to PROGRESS.json                    ║
║     - Updates roadmap with new plan reference                 ║
║     - Syncs GitHub issues with breadcrumb                     ║
║                                                               ║
║  C) List orphans                                              ║
║     - Show all orphan roadmaps                                ║
║     - Show all orphan phase-dev-plans                         ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

### Step 2A: Adopt Roadmap into Epic

**2A.1 - List orphan roadmaps:**

```javascript
import { listOrphanRoadmaps } from './src/github/hierarchy-manager.js';

const orphans = listOrphanRoadmaps(projectRoot);

if (orphans.length === 0) {
  console.log('✓ No orphan roadmaps found. All roadmaps have parent epics.');
  return;
}

// Display table
console.log('\n📋 Orphan Roadmaps:\n');
orphans.forEach((roadmap, index) => {
  console.log(`${index + 1}. ${roadmap.title} (${roadmap.slug})`);
  console.log(`   Status: ${roadmap.status} | Plans: ${roadmap.plan_count} | Completion: ${roadmap.completion}%`);
  console.log(`   Created: ${roadmap.created}`);
  console.log('');
});
```

**2A.2 - Ask user to select roadmap:**

Use AskUserQuestion to get roadmap selection (number or slug).

**2A.3 - List available epics:**

```javascript
import { readdirSync, existsSync, readFileSync } from 'fs';
import { join } from 'path';

const epicsDir = join(projectRoot, '.claude', 'epics');
const epics = [];

if (existsSync(epicsDir)) {
  const entries = readdirSync(epicsDir, { withFileTypes: true });

  for (const entry of entries) {
    if (entry.isDirectory()) {
      const epicPath = join(epicsDir, entry.name, 'EPIC.json');
      if (existsSync(epicPath)) {
        const epic = JSON.parse(readFileSync(epicPath, 'utf8'));
        epics.push({
          slug: epic.slug,
          title: epic.title,
          roadmap_count: epic.roadmaps?.length || 0,
          completion: epic.completion_percentage || 0,
        });
      }
    }
  }
}

if (epics.length === 0) {
  console.log('⚠️  No epics found. Create an epic first with /create-github-epic');
  return;
}

// Display epics
console.log('\n🎯 Available Epics:\n');
epics.forEach((epic, index) => {
  console.log(`${index + 1}. ${epic.title} (${epic.slug})`);
  console.log(`   Roadmaps: ${epic.roadmap_count} | Completion: ${epic.completion}%`);
  console.log('');
});
```

**2A.4 - Ask user to select epic:**

Use AskUserQuestion to get epic selection (number or slug).

**2A.5 - Perform adoption:**

```javascript
import { adoptRoadmapToEpic } from './src/github/hierarchy-manager.js';

const result = await adoptRoadmapToEpic(roadmapSlug, epicSlug, projectRoot);

if (result.success) {
  console.log('\n✅ Roadmap adopted successfully!\n');
  console.log(`Roadmap: ${roadmapSlug}`);
  console.log(`Parent Epic: ${epicSlug}`);

  if (result.updates.github.item_updated) {
    console.log('✓ Roadmap GitHub issue updated with parent link');
  }

  if (result.updates.github.parent_updated) {
    console.log('✓ Epic GitHub issue updated with new roadmap');
  }

  console.log(`\nEpic now has ${result.updates.epic.roadmap_count} roadmap(s)`);
  console.log(`Epic completion: ${result.updates.epic.completion}%`);
} else {
  console.error(`\n❌ Adoption failed: ${result.error}`);
}
```

### Step 2B: Adopt Phase-Dev-Plan into Roadmap

**2B.1 - List orphan plans:**

```javascript
import { listOrphanPlans } from './src/github/hierarchy-manager.js';

const orphans = listOrphanPlans(projectRoot);

if (orphans.length === 0) {
  console.log('✓ No orphan phase-dev-plans found. All plans have parent roadmaps.');
  return;
}

// Display table
console.log('\n📋 Orphan Phase-Dev-Plans:\n');
orphans.forEach((plan, index) => {
  console.log(`${index + 1}. ${plan.title} (${plan.slug})`);
  console.log(`   Status: ${plan.status} | Scale: ${plan.scale} | Phases: ${plan.phase_count} | Completion: ${plan.completion}%`);
  console.log(`   Created: ${plan.created}`);
  console.log('');
});
```

**2B.2 - Ask user to select plan:**

Use AskUserQuestion to get plan selection (number or slug).

**2B.3 - List available roadmaps:**

```javascript
const roadmapsDir = join(projectRoot, '.claude', 'roadmaps');
const roadmaps = [];

if (existsSync(roadmapsDir)) {
  const entries = readdirSync(roadmapsDir, { withFileTypes: true });

  for (const entry of entries) {
    if (entry.isDirectory()) {
      const roadmapPath = join(roadmapsDir, entry.name, 'ROADMAP.json');
      if (existsSync(roadmapPath)) {
        const roadmap = JSON.parse(readFileSync(roadmapPath, 'utf8'));
        roadmaps.push({
          slug: roadmap.slug,
          title: roadmap.title,
          plan_count: roadmap.phase_dev_plan_refs?.length || 0,
          completion: roadmap.metadata?.overall_completion_percentage || 0,
        });
      }
    }
  }
}

if (roadmaps.length === 0) {
  console.log('⚠️  No roadmaps found. Create a roadmap first with /create-roadmap');
  return;
}

// Display roadmaps
console.log('\n🗺️  Available Roadmaps:\n');
roadmaps.forEach((roadmap, index) => {
  console.log(`${index + 1}. ${roadmap.title} (${roadmap.slug})`);
  console.log(`   Plans: ${roadmap.plan_count} | Completion: ${roadmap.completion}%`);
  console.log('');
});
```

**2B.4 - Ask user to select roadmap:**

Use AskUserQuestion to get roadmap selection (number or slug).

**2B.5 - Perform adoption:**

```javascript
import { adoptPlanToRoadmap } from './src/github/hierarchy-manager.js';

const result = await adoptPlanToRoadmap(planSlug, roadmapSlug, projectRoot);

if (result.success) {
  console.log('\n✅ Phase-dev-plan adopted successfully!\n');
  console.log(`Plan: ${planSlug}`);
  console.log(`Parent Roadmap: ${roadmapSlug}`);

  if (result.updates.github.item_updated) {
    console.log('✓ Plan GitHub issue updated with parent link');
  }

  if (result.updates.github.parent_updated) {
    console.log('✓ Roadmap GitHub issue updated with new plan');
  }

  console.log(`\nRoadmap now has ${result.updates.roadmap.plan_count} plan(s)`);
  console.log(`Roadmap completion: ${result.updates.roadmap.completion}%`);
} else {
  console.error(`\n❌ Adoption failed: ${result.error}`);
}
```

### Step 2C: List Orphans

**Display both orphan roadmaps and plans:**

```javascript
import { listOrphanRoadmaps, listOrphanPlans } from './src/github/hierarchy-manager.js';

const orphanRoadmaps = listOrphanRoadmaps(projectRoot);
const orphanPlans = listOrphanPlans(projectRoot);

console.log('\n╔═══════════════════════════════════════════════════════════════╗');
console.log('║  Orphan Items Report                                          ║');
console.log('╠═══════════════════════════════════════════════════════════════╣');

// Orphan Roadmaps
console.log('║                                                               ║');
console.log(`║  Orphan Roadmaps: ${orphanRoadmaps.length.toString().padEnd(46)}║`);
console.log('║                                                               ║');

if (orphanRoadmaps.length === 0) {
  console.log('║  ✓ No orphan roadmaps                                         ║');
} else {
  orphanRoadmaps.forEach(roadmap => {
    const line = `  - ${roadmap.title} (${roadmap.slug})`;
    console.log(`║  ${line.padEnd(60)}║`);
  });
}

console.log('║                                                               ║');
console.log('╠═══════════════════════════════════════════════════════════════╣');

// Orphan Plans
console.log('║                                                               ║');
console.log(`║  Orphan Phase-Dev-Plans: ${orphanPlans.length.toString().padEnd(39)}║`);
console.log('║                                                               ║');

if (orphanPlans.length === 0) {
  console.log('║  ✓ No orphan phase-dev-plans                                  ║');
} else {
  orphanPlans.forEach(plan => {
    const line = `  - ${plan.title} (${plan.slug})`;
    console.log(`║  ${line.padEnd(60)}║`);
  });
}

console.log('║                                                               ║');
console.log('╚═══════════════════════════════════════════════════════════════╝');

// Recommendations
if (orphanRoadmaps.length > 0 || orphanPlans.length > 0) {
  console.log('\n💡 Recommendations:\n');

  if (orphanRoadmaps.length > 0) {
    console.log('  Orphan roadmaps can be adopted into epics:');
    console.log('  /adopt-roadmap → Option A\n');
  }

  if (orphanPlans.length > 0) {
    console.log('  Orphan plans can be adopted into roadmaps:');
    console.log('  /adopt-roadmap → Option B\n');
  }
}
```

---

## What Changes Are Made

### When Adopting Roadmap to Epic:

**Roadmap Changes (ROADMAP.json):**
```json
{
  "parent_epic": {
    "epic_id": "uuid-of-epic",
    "epic_slug": "epic-slug",
    "epic_path": ".claude/epics/epic-slug/EPIC.json"
  },
  "updated": "2026-02-04T..."
}
```

**Epic Changes (EPIC.json):**
```json
{
  "roadmaps": [
    // ... existing roadmaps
    {
      "roadmap_id": "uuid-of-roadmap",
      "slug": "roadmap-slug",
      "title": "Roadmap Title",
      "status": "active",
      "completion_percentage": 45,
      "created": "...",
      "updated": "..."
    }
  ],
  "completion_percentage": 62,  // recalculated
  "updated": "2026-02-04T..."
}
```

**GitHub Issue Updates:**
- Roadmap issue: Comment added with parent epic link
- Epic issue: Comment added with new roadmap

### When Adopting Plan to Roadmap:

**Plan Changes (PROGRESS.json):**
```json
{
  "parent_context": {
    "type": "roadmap",
    "slug": "roadmap-slug",
    "title": "Roadmap Title",
    "path": ".claude/roadmaps/roadmap-slug/ROADMAP.json"
  },
  "project": {
    "lastUpdated": "2026-02-04T..."
  }
}
```

**Roadmap Changes (ROADMAP.json):**
```json
{
  "phase_dev_plan_refs": [
    // ... existing plans
    {
      "slug": "plan-slug",
      "path": ".claude/phase-plans/plan-slug/PROGRESS.json",
      "title": "Plan Title",
      "status": "in_progress",
      "completion_percentage": 65,
      "created": "...",
      "updated": "..."
    }
  ],
  "metadata": {
    "plan_count": 4,  // incremented
    "overall_completion_percentage": 58  // recalculated
  },
  "updated": "2026-02-04T..."
}
```

**GitHub Issue Updates:**
- Plan issue: Comment added with parent roadmap link
- Roadmap issue: Comment added with new plan

---

## Error Handling

### Roadmap Already Has Parent
```
❌ Adoption failed: Roadmap already has parent epic: existing-epic-slug

Use /roadmap-status to view current hierarchy.
To change parent, manually edit ROADMAP.json or create new roadmap.
```

### Plan Already Has Parent
```
❌ Adoption failed: Plan already has parent: roadmap - existing-roadmap-slug

Use /phase-track to view current hierarchy.
To change parent, manually edit PROGRESS.json or create new plan.
```

### Item Not Found
```
❌ Adoption failed: Roadmap not found: /path/to/roadmap

Verify the roadmap slug is correct:
  ls .claude/roadmaps/
```

### No Orphans Found
```
✓ No orphan roadmaps found. All roadmaps have parent epics.

Your project hierarchy is fully organized!
```

---

## Argument Handling

Support quick adoption via arguments:

- `/adopt-roadmap` - Interactive mode (recommended)
- `/adopt-roadmap --roadmap {slug} --to-epic {slug}` - Adopt roadmap directly
- `/adopt-roadmap --plan {slug} --to-roadmap {slug}` - Adopt plan directly
- `/adopt-roadmap --list-orphans` - List orphans only

**Example:**
```
/adopt-roadmap --roadmap auth-system --to-epic platform-v2
```

---

## Related Commands

- `/create-roadmap` - Create new roadmap (with optional --parent-epic)
- `/phase-dev-plan` - Create new plan (with optional --parent-roadmap)
- `/create-github-epic` - Create parent epic
- `/roadmap-status` - View roadmap hierarchy
- `/phase-track` - View plan hierarchy

---

## Validation Checklist

Before completing adoption:
```
[ ] Item exists (roadmap or plan)
[ ] Parent exists (epic or roadmap)
[ ] Item is currently orphan (no existing parent)
[ ] JSON files updated with parent references
[ ] Completion percentages recalculated
[ ] GitHub issues updated (if they exist)
[ ] User notified of success
```

---

*Adopt Roadmap/Plan - Part of CCASP GitHub Hierarchy Sync*
