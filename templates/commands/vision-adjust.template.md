---
description: Adjust Vision plan when drift detected or requirements change
options:
  - label: "Interactive Adjustment"
    description: "Step-by-step guided adjustment"
  - label: "Quick Fix"
    description: "Apply specific adjustment immediately"
  - label: "Re-plan"
    description: "Regenerate roadmaps and architecture"
---

# Vision Adjust - Dynamic Plan Adjustment

Adjust Vision plan when drift is detected, requirements change, or execution reveals new constraints. Uses the Phase 7 Orchestrator to maintain alignment between vision and reality.

**Adjustment Triggers:**
- Drift events with severity HIGH or CRITICAL
- User-requested changes to features or constraints
- Technology decisions need revision
- Roadmap execution reveals blockers
- Architecture needs refactoring
- API contracts need changes

---

## Execution Protocol (Phase 7 Orchestrator Integration)

### Step 1: Load Vision and Assess State

```javascript
import { createOrchestrator, loadVision, formatDriftReport } from '${CWD}/node_modules/claude-cli-advanced-starter-pack/src/vision/index.js';

// Create orchestrator and resume from vision
const orchestrator = createOrchestrator(projectRoot);
const resumeResult = await orchestrator.resume(visionSlug);

if (!resumeResult.success) {
  console.error(`Failed to load vision: ${resumeResult.error}`);
  return;
}

const vision = resumeResult.vision;
const status = orchestrator.getStatus();

// Legacy import for direct updates
import { loadVision, updateVision } from '${CWD}/node_modules/claude-cli-advanced-starter-pack/src/vision/state-manager.js';

const vision = loadVision(projectRoot, visionSlug);

if (!vision) {
  console.log(`Vision not found: ${visionSlug}`);
  return;
}

// Calculate current drift severity
const driftSeverity = calculateMaxDriftSeverity(vision.observer.drift_events);
const alignment = vision.observer.current_alignment;
```

Display current state:

```
╔════════════════════════════════════════════════════════════════════════════╗
║                         VISION ADJUSTMENT MODE                              ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  Vision: {{title}} ({{slug}})                                               ║
║  Status: {{status}}                                                         ║
║  Alignment: [{{alignmentBar}}] {{alignmentPercentage}}%                     ║
║                                                                             ║
{{#if (lt alignment 0.9)}}
║  ⚠️ ALIGNMENT BELOW TARGET (95%)                                            ║
║                                                                             ║
{{/if}}
║  Drift Events: {{drift_count}} (Max Severity: {{max_severity}})             ║
║  Adjustments Made: {{adjustments_made}}                                     ║
║  Last Observation: {{last_observation}}                                     ║
║                                                                             ║
╠════════════════════════════════════════════════════════════════════════════╣
║  What would you like to adjust?                                             ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  1. Features & Constraints                                                  ║
║  2. Architecture & Tech Decisions                                           ║
║  3. Roadmaps & Execution Plan                                               ║
║  4. API Contracts                                                           ║
║  5. Wireframes & UI Design                                                  ║
║  6. Address Drift Events                                                    ║
║  7. Re-plan Entire Vision                                                   ║
║  8. Cancel                                                                  ║
║                                                                             ║
╚════════════════════════════════════════════════════════════════════════════╝

Enter choice (1-8):
```

### Step 2: Route to Adjustment Mode

Based on user selection:

#### Option 1: Features & Constraints

Use AskUserQuestion to gather changes:

```
╔════════════════════════════════════════════════════════════════════════════╗
║                     ADJUST FEATURES & CONSTRAINTS                           ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  Current Features:                                                          ║
{{#each features}}
║    {{@index}}. {{this}}                                                     ║
{{/each}}
║                                                                             ║
║  Current Constraints:                                                       ║
{{#each constraints}}
║    {{@index}}. {{this}}                                                     ║
{{/each}}
║                                                                             ║
╠════════════════════════════════════════════════════════════════════════════╣
║  What would you like to do?                                                 ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  A. Add new feature                                                         ║
║  B. Remove feature                                                          ║
║  C. Modify feature                                                          ║
║  D. Add constraint                                                          ║
║  E. Remove constraint                                                       ║
║  F. Done                                                                    ║
║                                                                             ║
╚════════════════════════════════════════════════════════════════════════════╝

Enter choice (A-F):
```

**Add Feature:**
- Ask for feature description
- Parse feature using NLP
- Add to vision.prompt.parsed.features
- Check if existing roadmaps cover it
- If not, suggest creating new roadmap or extending existing one

**Remove Feature:**
- Ask which feature to remove (by index)
- Check which roadmaps/phases implement it
- Warn user about impact
- Remove from vision.prompt.parsed.features
- Mark affected roadmaps for review

**Modify Feature:**
- Ask which feature to modify
- Ask for new description
- Update vision.prompt.parsed.features
- Check affected roadmaps
- Suggest adjustments

**Add/Remove Constraints:**
- Similar flow to features
- Update vision.prompt.parsed.constraints
- Check architecture compatibility
- Suggest tech stack changes if needed

**Update Vision:**
```javascript
await updateVision(projectRoot, visionSlug, (vision) => {
  vision.prompt.parsed.features = updatedFeatures;
  vision.prompt.parsed.constraints = updatedConstraints;
  vision.metadata.updated = new Date().toISOString();

  // Record adjustment
  recordDriftEvent(vision, {
    severity: 'medium',
    area: 'features',
    expected: 'Original feature set',
    actual: 'User-requested modifications',
    resolution: 'adjusted'
  });

  return vision;
});
```

#### Option 2: Architecture & Tech Decisions

Display current architecture:

```
╔════════════════════════════════════════════════════════════════════════════╗
║                      ADJUST ARCHITECTURE                                    ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  Current Tech Stack:                                                        ║
║                                                                             ║
║    Frontend: {{frontend.framework}}                                         ║
║    Reason: {{frontend.reason}}                                              ║
║                                                                             ║
║    State: {{state.library}}                                                 ║
║    Reason: {{state.reason}}                                                 ║
║                                                                             ║
║    Backend: {{backend.framework}}                                           ║
║    Reason: {{backend.reason}}                                               ║
║                                                                             ║
║    Database: {{database.type}}                                              ║
║    Reason: {{database.reason}}                                              ║
║                                                                             ║
{{#each additional}}
║    {{category}}: {{choice}}                                                 ║
║    Reason: {{reason}}                                                       ║
║                                                                             ║
{{/each}}
╠════════════════════════════════════════════════════════════════════════════╣
║  What would you like to change?                                             ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  1. Change Frontend Framework                                               ║
║  2. Change State Management                                                 ║
║  3. Change Backend Framework                                                ║
║  4. Change Database                                                         ║
║  5. Add/Modify Additional Tech                                              ║
║  6. Regenerate All Diagrams                                                 ║
║  7. Done                                                                    ║
║                                                                             ║
╚════════════════════════════════════════════════════════════════════════════╝

Enter choice (1-7):
```

**Change Tech Decision:**
- Ask for new technology choice
- Ask for reason
- Check compatibility with existing features
- Warn about breaking changes
- Update vision.architecture.tech_decisions
- **CRITICAL:** Re-generate affected roadmaps
- Update agents (may need new agents for new tech)

**Example: Change Frontend Framework**
```javascript
await updateVision(projectRoot, visionSlug, (vision) => {
  vision.architecture.tech_decisions.frontend = {
    framework: newFramework,
    reason: newReason
  };

  // Mark roadmaps for regeneration
  vision.execution_plan.roadmaps
    .filter(rm => rm.title.includes('Frontend'))
    .forEach(rm => {
      rm.needs_regeneration = true;
    });

  // Record drift event
  recordDriftEvent(vision, {
    severity: 'high',
    area: 'architecture',
    expected: oldFramework,
    actual: newFramework,
    resolution: 'adjusted'
  });

  return vision;
});
```

**Regenerate Diagrams:**
- Re-run Mermaid diagram generation
- Update component diagram
- Update data flow diagram
- Update sequence diagram
- Update deployment diagram

#### Option 3: Roadmaps & Execution Plan

Display roadmaps:

```
╔════════════════════════════════════════════════════════════════════════════╗
║                      ADJUST EXECUTION PLAN                                  ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  Current Roadmaps:                                                          ║
║                                                                             ║
{{#each roadmaps}}
║  {{order}}. {{title}}                                                       ║
║     Status: {{status}} | Completion: {{completion_percentage}}%             ║
║     Estimated Phases: {{estimated_phases}}                                  ║
║     Path: .claude/roadmaps/{{roadmap_slug}}/ROADMAP.json                    ║
{{#if needs_regeneration}}
║     ⚠️ NEEDS REGENERATION                                                   ║
{{/if}}
║                                                                             ║
{{/each}}
╠════════════════════════════════════════════════════════════════════════════╣
║  What would you like to do?                                                 ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  1. Reorder roadmaps                                                        ║
║  2. Add new roadmap                                                         ║
║  3. Remove roadmap                                                          ║
║  4. Modify roadmap scope                                                    ║
║  5. Regenerate roadmap (if needs_regeneration)                              ║
║  6. Adjust token budget                                                     ║
║  7. Done                                                                    ║
║                                                                             ║
╚════════════════════════════════════════════════════════════════════════════╝

Enter choice (1-7):
```

**Reorder Roadmaps:**
- Ask for new order
- Update vision.execution_plan.roadmaps[].order
- Check dependencies (warn if reordering breaks dependencies)

**Add New Roadmap:**
- Ask for title, description, estimated phases
- Create roadmap using roadmap-manager
- Add to vision.execution_plan.roadmaps
- Link to parent epic

**Remove Roadmap:**
- Ask which roadmap to remove
- Warn about impact (tasks, phases)
- Remove from vision.execution_plan.roadmaps
- Delete roadmap files
- Update epic if GitHub integrated

**Modify Roadmap Scope:**
- Ask which roadmap to modify
- Ask for new scope description
- Update roadmap ROADMAP.json
- Recalculate estimated phases/tasks

**Regenerate Roadmap:**
- Load roadmap
- Re-run planning based on current vision state
- Generate new phases and tasks
- Preserve completed work
- Mark as regenerated

**Adjust Token Budget:**
- Ask for new total token budget
- Recalculate per_roadmap allocation
- Warn if current usage exceeds new budget

#### Option 4: API Contracts

Display current API contracts:

```
╔════════════════════════════════════════════════════════════════════════════╗
║                        ADJUST API CONTRACTS                                 ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  Current API Endpoints: {{api_count}}                                       ║
║                                                                             ║
{{#each api_contracts}}
║  {{method}} {{path}}                                                        ║
║    {{description}}                                                          ║
{{#if auth_required}}
║    🔒 Auth Required                                                         ║
{{/if}}
║                                                                             ║
{{/each}}
╠════════════════════════════════════════════════════════════════════════════╣
║  What would you like to do?                                                 ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  1. Add new endpoint                                                        ║
║  2. Remove endpoint                                                         ║
║  3. Modify endpoint                                                         ║
║  4. Change request/response schema                                          ║
║  5. Toggle authentication                                                   ║
║  6. Done                                                                    ║
║                                                                             ║
╚════════════════════════════════════════════════════════════════════════════╝

Enter choice (1-6):
```

**Add Endpoint:**
- Ask for method, path, description
- Ask for request/response schemas (JSON)
- Ask if auth required
- Add to vision.architecture.api_contracts

**Modify Endpoint:**
- Ask which endpoint (by index)
- Ask what to change
- Update api_contracts
- Mark backend roadmap for review

#### Option 5: Wireframes & UI Design

Display current wireframes:

```
╔════════════════════════════════════════════════════════════════════════════╗
║                       ADJUST WIREFRAMES & UI                                ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  Current UI Design:                                                         ║
║                                                                             ║
║  Components: {{component_count}}                                            ║
║  Screens: {{screen_count}}                                                  ║
║                                                                             ║
║  ASCII UI Preview:                                                          ║
{{ascii_ui}}
║                                                                             ║
╠════════════════════════════════════════════════════════════════════════════╣
║  What would you like to do?                                                 ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  1. Regenerate ASCII wireframe                                              ║
║  2. Add new component                                                       ║
║  3. Remove component                                                        ║
║  4. Modify component                                                        ║
║  5. Add new screen                                                          ║
║  6. Done                                                                    ║
║                                                                             ║
╚════════════════════════════════════════════════════════════════════════════╝

Enter choice (1-6):
```

**Regenerate Wireframe:**
- Use current features and constraints
- Generate new ASCII art
- Update component breakdown
- Update vision.wireframes

**Add/Modify/Remove Component:**
- Update vision.wireframes.components
- Regenerate affected screens
- Mark frontend roadmap for review

#### Option 6: Address Drift Events

Display drift events:

```
╔════════════════════════════════════════════════════════════════════════════╗
║                        DRIFT EVENT RESOLUTION                               ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  Detected Drift Events: {{drift_count}}                                     ║
║                                                                             ║
{{#each drift_events}}
║  {{@index}}. {{severityBadge}} {{area}}                                     ║
║     Detected: {{detected_at}}                                               ║
║     Expected: {{expected}}                                                  ║
║     Actual: {{actual}}                                                      ║
║     Resolution: {{resolution}}                                              ║
║                                                                             ║
{{/each}}
╠════════════════════════════════════════════════════════════════════════════╣
║  Select drift event to address (0-{{drift_count-1}}):                      ║
╚════════════════════════════════════════════════════════════════════════════╝

Enter index:
```

For selected drift event, offer resolution options:

```
╔════════════════════════════════════════════════════════════════════════════╗
║  Drift Event: {{area}}                                                      ║
║  Severity: {{severityBadge}}                                                ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  Expected: {{expected}}                                                     ║
║  Actual: {{actual}}                                                         ║
║                                                                             ║
║  How would you like to resolve this?                                        ║
║                                                                             ║
║  1. Adjust vision to match actual (accept drift)                            ║
║  2. Force execution to match vision (reject drift)                          ║
║  3. Find middle ground (compromise)                                         ║
║  4. Ignore this drift event                                                 ║
║  5. Escalate to manual review                                               ║
║                                                                             ║
╚════════════════════════════════════════════════════════════════════════════╝

Enter choice (1-5):
```

**Accept Drift:**
- Update vision to reflect actual state
- Mark drift event as 'adjusted'
- Update alignment score
- Recalculate completion

**Reject Drift:**
- Rollback changes that caused drift
- Mark affected phases for rework
- Update roadmap status
- Mark drift event as 'rejected'

**Compromise:**
- Ask user for compromise approach
- Update both vision and execution
- Mark drift event as 'adjusted'

**Ignore:**
- Mark drift event as 'ignored'
- Don't affect alignment score
- Add to ignore list

**Escalate:**
- Mark drift event as 'escalated'
- Create GitHub issue for manual review
- Pause autonomous execution

#### Option 7: Re-plan Entire Vision

**WARNING:** This will regenerate all roadmaps and reset execution plan.

```
╔════════════════════════════════════════════════════════════════════════════╗
║                          RE-PLAN ENTIRE VISION                              ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  ⚠️ WARNING: This will regenerate all roadmaps and phases.                 ║
║                                                                             ║
║  Current progress:                                                          ║
║    Roadmaps: {{completed}}/{{total}} completed                              ║
║    Completion: {{completion_percentage}}%                                   ║
║                                                                             ║
║  Completed work will be preserved, but uncompleted phases                   ║
║  will be regenerated based on current vision state.                         ║
║                                                                             ║
║  Continue? (yes/no)                                                         ║
║                                                                             ║
╚════════════════════════════════════════════════════════════════════════════╝
```

If user confirms:

1. Create checkpoint before re-planning:
```javascript
import { createVisionCheckpoint } from './src/vision/state-manager.js';

await createVisionCheckpoint(projectRoot, visionSlug, 'Before re-planning');
```

2. Re-run web search for updated inspiration
3. Regenerate wireframes based on new features
4. Regenerate architecture diagrams
5. Regenerate API contracts
6. Delete uncompleted roadmaps
7. Create new roadmaps based on updated vision
8. Update execution plan
9. Re-create agents if tech stack changed
10. Update alignment score

```javascript
await updateVision(projectRoot, visionSlug, (vision) => {
  vision.status = 'orchestrating';
  vision.execution_plan.roadmaps = newRoadmaps;
  vision.execution_plan.estimated_phases = calculateEstimatedPhases(newRoadmaps);
  vision.execution_plan.estimated_tasks = calculateEstimatedTasks(newRoadmaps);

  // Record re-planning
  recordDriftEvent(vision, {
    severity: 'high',
    area: 'execution_plan',
    expected: 'Original plan',
    actual: 'User-requested re-planning',
    resolution: 'adjusted'
  });

  return vision;
});
```

### Step 3: Recalculate Alignment Score

After any adjustment, recalculate alignment:

```javascript
import { updateAlignment } from './src/vision/schema.js';

function calculateAlignment(vision) {
  let alignment = 1.0;

  // Penalize for unresolved drift events
  const unresolvedDrift = vision.observer.drift_events.filter(
    e => e.resolution !== 'adjusted' && e.resolution !== 'ignored'
  );
  alignment -= unresolvedDrift.length * 0.05;

  // Penalize for high/critical severity drift
  const criticalDrift = vision.observer.drift_events.filter(
    e => e.severity === 'critical' || e.severity === 'high'
  );
  alignment -= criticalDrift.length * 0.1;

  // Bonus for adjustments made
  alignment += Math.min(vision.observer.adjustments_made * 0.02, 0.1);

  // Clamp between 0 and 1
  alignment = Math.max(0, Math.min(1, alignment));

  return alignment;
}

const newAlignment = calculateAlignment(vision);
updateAlignment(vision, newAlignment);
await saveVision(projectRoot, vision);
```

### Step 4: Update Affected Roadmaps

If adjustments affect roadmaps, update them:

```javascript
import { loadRoadmap, updateRoadmap } from './src/roadmap/roadmap-manager.js';

for (const roadmap of vision.execution_plan.roadmaps) {
  if (roadmap.needs_regeneration) {
    const roadmapData = loadRoadmap(projectRoot, roadmap.roadmap_slug);

    if (roadmapData) {
      // Regenerate phases for uncompleted work
      const uncompleted = roadmapData.phases.filter(p => p.status !== 'completed');

      // Generate new phases based on updated vision
      const newPhases = await generatePhasesFromVision(vision, roadmap);

      // Merge: keep completed phases, replace uncompleted
      roadmapData.phases = [
        ...roadmapData.phases.filter(p => p.status === 'completed'),
        ...newPhases
      ];

      await updateRoadmap(projectRoot, roadmap.roadmap_slug, (rm) => {
        rm.phases = roadmapData.phases;
        rm.updated = new Date().toISOString();
        return rm;
      });
    }

    // Clear regeneration flag
    roadmap.needs_regeneration = false;
  }
}
```

### Step 5: Update GitHub Epic/Issues (if integrated)

If GitHub integration is enabled:

```javascript
import { updateEpicIssue } from './src/epic/epic-manager.js';
import { updateRoadmapIssue } from './src/roadmap/roadmap-manager.js';

// Update epic issue body with new roadmap structure
if (vision.execution_plan.epic_slug) {
  await updateEpicIssue(projectRoot, vision.execution_plan.epic_slug);
}

// Update affected roadmap issues
for (const roadmap of vision.execution_plan.roadmaps) {
  if (roadmap.needs_github_update) {
    await updateRoadmapIssue(projectRoot, roadmap.roadmap_slug);
    roadmap.needs_github_update = false;
  }
}
```

### Step 6: Display Adjustment Summary

```
╔════════════════════════════════════════════════════════════════════════════╗
║                     VISION ADJUSTMENT COMPLETE! ✓                           ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  Vision: {{title}}                                                          ║
║  Adjustment Type: {{adjustment_type}}                                       ║
║  Timestamp: {{timestamp}}                                                   ║
║                                                                             ║
╠════════════════════════════════════════════════════════════════════════════╣
║  Changes Made                                                               ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
{{#each changes}}
║  • {{this}}                                                                 ║
{{/each}}
║                                                                             ║
╠════════════════════════════════════════════════════════════════════════════╣
║  Updated Metrics                                                            ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  Alignment: {{old_alignment}}% → {{new_alignment}}%                         ║
║  Drift Events: {{old_drift}} → {{new_drift}}                                ║
║  Adjustments Made: {{adjustments_made}}                                     ║
║                                                                             ║
╠════════════════════════════════════════════════════════════════════════════╣
║  Affected Roadmaps                                                          ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
{{#each affected_roadmaps}}
║  • {{title}} ({{roadmap_slug}})                                             ║
{{#if regenerated}}
║    ✓ Regenerated with {{phase_count}} phases                                ║
{{else}}
║    ↻ Requires regeneration: /roadmap-regenerate {{roadmap_slug}}            ║
{{/if}}
║                                                                             ║
{{/each}}
╠════════════════════════════════════════════════════════════════════════════╣
║  Next Steps                                                                 ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  1. Review updated vision:                                                  ║
║     /vision-status {{slug}}                                                 ║
║                                                                             ║
║  2. Review updated VISION_SUMMARY.md:                                       ║
║     .claude/visions/{{slug}}/VISION_SUMMARY.md                              ║
║                                                                             ║
{{#if needs_roadmap_regeneration}}
║  3. Regenerate affected roadmaps (marked above)                             ║
║                                                                             ║
{{/if}}
║  4. Continue execution:                                                     ║
║     /vision-execute {{slug}}                                                ║
║                                                                             ║
║  5. Or work on specific roadmap:                                            ║
║     /roadmap-track {{next_roadmap_slug}}                                    ║
║                                                                             ║
╠════════════════════════════════════════════════════════════════════════════╣
║  Checkpoint Created                                                         ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  A checkpoint was created before adjustment.                                ║
║  If needed, rollback with:                                                  ║
║    /vision-rollback {{slug}} {{checkpoint_id}}                              ║
║                                                                             ║
╚════════════════════════════════════════════════════════════════════════════╝
```

### Step 7: Update VISION_SUMMARY.md

Regenerate the VISION_SUMMARY.md file with updated content (same format as vision-init, but reflecting changes).

## Quick Adjustment Mode

If invoked with specific flags, apply adjustment immediately:

```bash
/vision-adjust kanban-board --add-feature "Export to CSV"

/vision-adjust kanban-board --remove-constraint "Must use MySQL"

/vision-adjust kanban-board --change-backend "Express"

/vision-adjust kanban-board --reorder-roadmaps "2,1,3,4"
```

**Processing Quick Adjustments:**

```javascript
const args = parseArguments(commandArgs);

if (args.addFeature) {
  await updateVision(projectRoot, visionSlug, (vision) => {
    vision.prompt.parsed.features.push(args.addFeature);
    recordDriftEvent(vision, {
      severity: 'medium',
      area: 'features',
      expected: 'Original features',
      actual: `Added: ${args.addFeature}`,
      resolution: 'adjusted'
    });
    return vision;
  });

  console.log(`✅ Added feature: ${args.addFeature}`);
  console.log('Review roadmaps to ensure coverage.');
}
```

## Argument Handling

- `/vision-adjust {slug}` - Interactive adjustment mode
- `/vision-adjust {slug} --add-feature "{feature}"` - Add feature
- `/vision-adjust {slug} --remove-feature "{feature}"` - Remove feature
- `/vision-adjust {slug} --add-constraint "{constraint}"` - Add constraint
- `/vision-adjust {slug} --remove-constraint "{constraint}"` - Remove constraint
- `/vision-adjust {slug} --change-frontend "{framework}"` - Change frontend
- `/vision-adjust {slug} --change-backend "{framework}"` - Change backend
- `/vision-adjust {slug} --change-database "{database}"` - Change database
- `/vision-adjust {slug} --reorder-roadmaps "{order}"` - Reorder (e.g., "2,1,3,4")
- `/vision-adjust {slug} --replan` - Full re-planning

**Examples:**

```bash
/vision-adjust kanban-board

/vision-adjust kanban-board --add-feature "Export to CSV"

/vision-adjust kanban-board --change-backend "Express"

/vision-adjust kanban-board --replan
```

## Validation Checklist

Before marking complete, verify:

```
[ ] Vision loaded successfully
[ ] Adjustment type identified
[ ] Changes applied to VISION.json
[ ] Alignment score recalculated
[ ] Drift events updated/resolved
[ ] Affected roadmaps identified
[ ] Roadmaps regenerated (if needed)
[ ] GitHub issues updated (if integrated)
[ ] VISION_SUMMARY.md regenerated
[ ] Checkpoint created
[ ] Summary displayed to user
```

## Error Handling

If adjustment fails:
- Restore from checkpoint
- Log error details
- Display error to user
- Suggest manual adjustment steps

## Related Commands

- `/vision-init` - Initialize new Vision
- `/vision-status` - View Vision status
- `/vision-execute` - Start/resume execution
- `/vision-rollback` - Rollback to checkpoint
- `/roadmap-track` - Track specific roadmap

---

## CLI Alternative

```bash
# Interactive adjustment
ccasp vision adjust <slug>

# Quick adjustments
ccasp vision adjust <slug> --add-feature "Export to CSV"
ccasp vision adjust <slug> --remove-constraint "Must use MySQL"
ccasp vision adjust <slug> --change-backend "Express"
```

## Re-analysis with Orchestrator

For major changes, re-run orchestrator phases:

```javascript
// After making adjustments, re-run analysis
const analysisResult = await orchestrator.analyze();

// Re-generate architecture
const archResult = await orchestrator.architect();

// Re-run security scan
const securityResult = await orchestrator.scanSecurity();
```

---

*Vision Adjust - Part of CCASP Vision Mode Autonomous Development Framework (Phase 7)*
