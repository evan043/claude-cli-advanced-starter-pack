---
description: Execute and coordinate multiple phase-dev-plans within a roadmap
type: project
complexity: high
allowed-tools: Read, Write, Edit, Task, Bash
category: development
---

# Roadmap Track - Multi-Plan Execution Coordinator

You are a roadmap execution coordinator. You coordinate execution across MULTIPLE phase-dev-plans within a roadmap, respect cross-plan dependencies, and aggregate progress.

> ⚠️ **CONTEXT SAFETY REQUIRED**: This command MUST follow [Context-Safe Orchestration](../patterns/context-safe-orchestration.md) patterns. All plan executions return summaries only. Full results stored in files.

---

## HARD SEQUENTIAL GATES (NON-NEGOTIABLE)

**These rules OVERRIDE all other instructions. Violating them causes context overflow and lost work.**

### FORBIDDEN - Will Cause Failure:
- **DO NOT** launch Phase N+1 before Phase N status = `completed` in PROGRESS.json
- **DO NOT** launch multiple `/phase-track` commands for different plans simultaneously
- **DO NOT** spawn parallel background agents for separate plans/phases
- **DO NOT** "get ahead" by starting later phases while earlier ones run
- **DO NOT** interpret "run-all" as "run all at once" — it means "run all sequentially, one at a time"

### REQUIRED - Must Follow:
1. **ONE plan at a time**: Only ONE `/phase-track` execution may be active at any moment
2. **Wait for completion**: After launching `/phase-track {slug}`, you MUST wait for it to return before starting the next plan
3. **Verify via file**: Read PROGRESS.json to confirm `status: "completed"` before advancing
4. **If validation fails**: STOP. Do NOT continue to the next plan. Report the failure and wait for user input
5. **Context checkpoint**: Check context usage before EACH plan. If >70%, pause and offer /compact

### Why This Matters:
Launching multiple plans/phases in parallel causes:
- Context window overflow (the model freezes/stops responding)
- Lost work from forced compaction
- Silent permission denials on background agents
- The exact bug you are reading this to prevent

---

## Context Safety Rules

| Rule | Implementation |
|------|----------------|
| File-based state | ROADMAP.json is source of truth |
| Summary-only delegation | /phase-track returns max 200 chars |
| No full output aggregation | Read completion from files |
| Context checkpoints | Check before each plan |

### Orchestration Config (Read from ROADMAP.json)

All thresholds and limits are read from the `orchestration` block embedded in ROADMAP.json:
```json
{
  "orchestration": {
    "max_parallel_plans": 2,
    "plan_batch_strategy": "dependency_order",
    "compact_before_plan": true,
    "compact_after_plan": true,
    "context_threshold_percent": 40,
    "agent_model": "sonnet"
  }
}
```

If `orchestration` is missing (legacy roadmaps), defaults apply: `max_parallel_plans: 2, context_threshold_percent: 40, agent_model: 'sonnet'`.

---

## COMPLIANCE GATE (If Enabled)

**Before starting ANY plan execution, check compliance status:**

1. Read `compliance` from ROADMAP.json
2. **If `compliance.enabled && compliance.blocking`:**
   a. Check `compliance.documentation.routes_md` is NOT `not_started`
   b. Check `compliance.documentation.rbac_md` is NOT `not_started`
   c. Check `compliance.documentation.api_contract` is NOT `not_started`
   d. **If ANY required doc is `not_started`:**
      ```
      ╔═══════════════════════════════════════════════════════════════╗
      ║  🚫 COMPLIANCE GATE — Execution Blocked                      ║
      ╠═══════════════════════════════════════════════════════════════╣
      ║                                                              ║
      ║  Commercial SaaS compliance is BLOCKING plan execution.      ║
      ║                                                              ║
      ║  Missing required documents:                                 ║
      ║  • ROUTES.md:       {status}                                 ║
      ║  • API_CONTRACT.md: {status}                                 ║
      ║  • RBAC.md:         {status}                                 ║
      ║                                                              ║
      ║  To unblock:                                                 ║
      ║    1. Create missing documents                               ║
      ║    2. Update ROADMAP.json compliance.documentation statuses  ║
      ║    3. Re-run /roadmap-track {slug}                           ║
      ║                                                              ║
      ╚═══════════════════════════════════════════════════════════════╝
      ```
      → **STOP. Do NOT start any plans.**

3. **If `compliance.enabled && !compliance.blocking`:**
   → Display warning but allow execution:
   ```
   ⚠️  Compliance docs incomplete (non-blocking). Consider completing before release.
   ```

4. **If `compliance` is null or `compliance.enabled === false`:**
   → Skip compliance checks entirely, proceed normally.

## NEW ARCHITECTURE (Epic-Hierarchy)

Roadmap now coordinates MULTIPLE phase-dev-plans instead of direct phases:

```
Roadmap: User Authentication
  ├─ Phase-Dev-Plan: auth-backend (PROGRESS.json)
  │   ├─ Phase 1: Database Schema
  │   ├─ Phase 2: API Endpoints
  │   └─ Phase 3: Middleware
  ├─ Phase-Dev-Plan: auth-frontend (PROGRESS.json)
  │   ├─ Phase 1: Login UI
  │   ├─ Phase 2: Token Management
  │   └─ Phase 3: Protected Routes
  └─ Phase-Dev-Plan: auth-testing (PROGRESS.json)
      ├─ Phase 1: Unit Tests
      └─ Phase 2: E2E Tests
```

**Key Changes:**
- Roadmap tracks **phase-dev-plan references**, not direct phases
- Each plan has its own PROGRESS.json
- Cross-plan dependencies (e.g., frontend waits for backend)
- Roadmap completion = average of all plan completions

## Execution Protocol

### Step 1: Load Roadmap State

Load the roadmap and all plan references:

```javascript
// Load roadmap from consolidated structure
function loadRoadmapState(slug) {
  const roadmapPath = `.claude/roadmaps/${slug}/ROADMAP.json`;

  if (!existsSync(roadmapPath)) {
    throw new Error(`Roadmap not found: ${roadmapPath}`);
  }

  const roadmap = JSON.parse(readFileSync(roadmapPath, 'utf8'));

  // Load all plan PROGRESS.json files
  const planStates = [];
  for (const planRef of roadmap.phase_dev_plan_refs) {
    const progressPath = planRef.path;
    if (existsSync(progressPath)) {
      const progress = JSON.parse(readFileSync(progressPath, 'utf8'));
      planStates.push({
        slug: planRef.slug,
        ref: planRef,
        progress: progress
      });
    }
  }

  return {
    roadmap,
    planStates,
    structure: 'epic-hierarchy'
  };
}
```

### Step 2: Display Execution Dashboard (Multi-Plan)

```
╔═══════════════════════════════════════════════════════════════════════════╗
║                    ROADMAP EXECUTION DASHBOARD                             ║
╠═══════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  📋 {{roadmap.title}}                                                       ║
║  ──────────────────────────────────────────────────────────────────────────║
║                                                                             ║
║  Overall Progress: [{{progressBar}}] {{overallPercentage}}%                 ║
║  Plans: {{completedPlans}}/{{totalPlans}}                                   ║
║  Compliance: {{compliance_status_display}}                                  ║
║                                                                             ║
╠═══════════════════════════════════════════════════════════════════════════╣
║  PHASE-DEV-PLANS                                                            ║
╠═══════════════════════════════════════════════════════════════════════════╣
{{#each planRefs}}
║  {{statusIcon}} {{slug}}: {{title}}                                         ║
║     Progress: [{{planProgress}}] {{planPercentage}}%                        ║
{{#if agents_assigned}}
║     🤖 Agents: {{agents_assigned}}                                          ║
{{/if}}
{{#if isActive}}
║     ▶ ACTIVE                                                                ║
{{/if}}
{{#if isBlocked}}
║     🚫 BLOCKED: {{blockedReason}}                                           ║
{{/if}}
{{#if phases}}
║     Phases: {{completedPhases}}/{{totalPhases}}                             ║
{{/if}}
{{/each}}
║                                                                             ║
╠═══════════════════════════════════════════════════════════════════════════╣
║  CROSS-PLAN DEPENDENCIES                                                    ║
╠═══════════════════════════════════════════════════════════════════════════╣
{{#each dependencies}}
║  {{dependentSlug}} → {{dependsOnSlug}} {{status}}                           ║
║     Reason: {{reason}}                                                      ║
{{/each}}
{{#if noDependencies}}
║  No cross-plan dependencies                                                 ║
{{/if}}
║                                                                             ║
╠═══════════════════════════════════════════════════════════════════════════╣
║  NEXT AVAILABLE                                                             ║
╠═══════════════════════════════════════════════════════════════════════════╣
{{#each nextAvailable}}
║  → {{slug}}: {{title}} (Dependencies satisfied)                             ║
{{/each}}
{{#if noNextAvailable}}
║  No plans available. Check blocked plans or dependencies.                   ║
{{/if}}
║                                                                             ║
╚═══════════════════════════════════════════════════════════════════════════╝
```

**Compliance Status Display Logic:**

Compute `compliance_status_display` as follows:
```javascript
function getComplianceStatusDisplay(roadmap) {
  const compliance = roadmap.compliance;

  // Not configured
  if (!compliance || !compliance.enabled) {
    return "— (not configured)";
  }

  // Passed
  if (compliance.status === 'passed') {
    const score = compliance.audit?.score || 0;
    return `✓ PASS (Score: ${score}/100)`;
  }

  // Blocked by docs
  if (compliance.blocking) {
    const docs = compliance.documentation || {};
    const pendingDocs = [];
    if (docs.routes_md === 'not_started') pendingDocs.push('ROUTES.md');
    if (docs.rbac_md === 'not_started') pendingDocs.push('RBAC.md');
    if (docs.api_contract === 'not_started') pendingDocs.push('API_CONTRACT.md');

    if (pendingDocs.length > 0) {
      return `🚫 BLOCKED — ${pendingDocs.join(', ')} required`;
    }
  }

  // Planning
  if (compliance.status === 'planning') {
    const docs = compliance.documentation || {};
    const pendingCount = Object.values(docs).filter(s => s !== 'complete').length;
    return `⚠ PLANNING (${pendingCount} docs pending)`;
  }

  // Failed
  if (compliance.status === 'failed') {
    return "✗ FAILED — review required";
  }

  return "— (unknown status)";
}
```

### Step 3: Offer Actions (Multi-Plan)

Based on current state, offer relevant actions:

**When roadmap has plans pending:**
1. `start <plan-slug>` - Start a specific plan (if dependencies satisfied)
2. `auto` - Auto-start next available plan
3. `run-all` - **Run ALL plans sequentially and autonomously**
4. `status` - Refresh status display

**When roadmap has active plans:**
1. `track <plan-slug>` - Delegate to /phase-track for detailed plan execution
2. `sync <plan-slug>` - Sync plan reference from PROGRESS.json
3. `sync-all` - Sync all plan references
4. `pause` - Pause execution

**When plan is blocked:**
1. `unblock <plan-slug>` - Remove block and resume
2. `skip <plan-slug>` - Skip blocked plan (update dependencies)
3. `reassign <plan-slug>` - Reassign to different approach

**When roadmap is completed:**
1. `report` - Generate completion report
2. `sync-github` - Sync to parent epic (if integrated)
3. `archive` - Archive roadmap and cleanup

### Step 4: Execute Action (Multi-Plan)

#### Start Plan
```javascript
// Check dependencies are satisfied
async function startPlan(roadmap, planSlug) {
  // 1. Check cross-plan dependencies
  const depCheck = checkPlanDependencies(roadmap, planSlug);
  if (!depCheck.satisfied) {
    console.error(`Plan ${planSlug} blocked by dependencies: ${depCheck.missing.join(', ')}`);
    return;
  }

  // 2. Update plan reference status
  updatePlanReference(roadmap, planSlug, { status: 'in_progress' });

  // 3. Pass agent context from roadmapAgentMapping (if available)
  const agentMapping = roadmap.roadmapAgentMapping?.[planSlug];
  if (agentMapping) {
    console.log(`🤖 Agents for ${planSlug}: ${agentMapping.primary.join(', ')}`);
  }

  // 4. Delegate to /phase-track for execution
  console.log(`Starting plan: ${planSlug}`);
  console.log(`Delegating to /phase-track ${planSlug}...`);

  // Spawn /phase-track command
  await runCommand(`/phase-track ${planSlug}`);
}
```

#### Sync Plan Reference
```javascript
// Update plan reference from its PROGRESS.json
async function syncPlanRef(roadmap, planSlug) {
  const planRef = roadmap.phase_dev_plan_refs.find(ref => ref.slug === planSlug);
  if (!planRef) return;

  // Load PROGRESS.json
  const progressPath = planRef.path;
  const progress = JSON.parse(readFileSync(progressPath, 'utf8'));

  // Update reference
  updatePlanReference(roadmap, planSlug, {
    status: progress.status,
    completion_percentage: progress.completion_percentage || 0
  });

  // Recalculate overall completion
  roadmap.metadata.overall_completion_percentage = calculateOverallCompletion(roadmap);

  // Check if roadmap complete
  checkRoadmapCompletion(roadmap);
}
```

#### Sync All Plans
```javascript
// Sync all plan references
async function syncAllPlans(roadmap) {
  for (const planRef of roadmap.phase_dev_plan_refs) {
    await syncPlanRef(roadmap, planRef.slug);
  }

  console.log(`Synced ${roadmap.phase_dev_plan_refs.length} plan references`);
}
```

#### Auto-Advance (Multi-Plan)
```javascript
// Find next available plan (dependencies satisfied)
async function autoAdvance(roadmap) {
  const nextAvailable = getNextAvailablePlans(roadmap);

  if (nextAvailable.length === 0) {
    // Check if all complete
    const allComplete = roadmap.phase_dev_plan_refs.every(ref => ref.status === 'completed');
    if (allComplete) {
      console.log('🎉 All plans complete!');
      return;
    } else {
      console.log('No plans available. Check dependencies or blocked plans.');
      return;
    }
  }

  if (nextAvailable.length === 1) {
    // Auto-start single available plan
    await startPlan(roadmap, nextAvailable[0].slug);
  } else {
    // Multiple available - ask user
    console.log('Multiple plans available:');
    nextAvailable.forEach((plan, i) => {
      console.log(`  ${i + 1}. ${plan.slug}: ${plan.title}`);
    });
    // Prompt for selection
  }
}
```

#### Run All Plans (Autonomous Mode - Context-Safe)

> **SEQUENTIAL EXECUTION ONLY**: "run-all" means "run each plan one at a time, in order, waiting for each to complete before starting the next." It does NOT mean "run all at once." Launching multiple plans simultaneously is FORBIDDEN and will cause context overflow.

```javascript
/**
 * Execute ALL plans SEQUENTIALLY without user intervention.
 *
 * HARD GATE: Only ONE plan runs at a time. The next plan
 * CANNOT start until the current plan's PROGRESS.json
 * shows status: "completed". This is non-negotiable.
 */
async function runAllPlans(roadmap) {
  console.log('🚀 AUTONOMOUS MODE (Context-Safe): Running all phase-dev-plans SEQUENTIALLY...\n');
  console.log('📋 State tracked in: ROADMAP.json (not context)\n');
  console.log('⛔ HARD GATE: Only ONE plan runs at a time. Next plan waits for current to complete.\n');

  // Get plans in dependency order
  const orderedPlans = topologicalSortPlans(roadmap);
  const roadmapPath = `.claude/roadmaps/${roadmap.slug}/ROADMAP.json`;

  for (const planRef of orderedPlans) {
    // CONTEXT CHECKPOINT: Check before each plan
    const contextUsage = await estimateContextUsage();
    if (contextUsage.percent > (100 - (roadmap.orchestration?.context_threshold_percent || 40))) {
      console.log(`\n⚠️ CONTEXT CHECKPOINT: ${contextUsage.percent}% used`);
      console.log('   Consider: /compact to free context before continuing');
      console.log('   Progress is saved - you can safely compact and resume.\n');
      // Could pause here for user decision
    }

    // Skip already completed plans
    if (planRef.status === 'completed') {
      console.log(`✓ Plan ${planRef.slug} already complete`);
      continue;
    }

    // Check dependencies
    const depCheck = checkPlanDependencies(roadmap, planRef.slug);
    if (!depCheck.satisfied) {
      console.log(`⚠️ Plan ${planRef.slug} blocked: ${depCheck.missing.join(', ')}`);
      continue;
    }

    // Compact before plan if configured in orchestration block
    if (roadmap.orchestration?.compact_before_plan !== false) {
      console.log('   Compacting context before plan execution...');
      await compactContext();
    }

    // Start plan - update FILE immediately
    console.log(`\n▶ Plan: ${planRef.slug}`);
    updatePlanReference(roadmap, planRef.slug, { status: 'in_progress' });
    fs.writeFileSync(roadmapPath, JSON.stringify(roadmap, null, 2));

    // Delegate to /phase-track (returns summary only)
    // CRITICAL: Do NOT capture full output - read result from file
    console.log(`   Executing /phase-track ${planRef.slug} run-all...`);
    await runCommand(`/phase-track ${planRef.slug} run-all`);

    // Read result from PROGRESS.json file (not from command output)
    const progressPath = planRef.path;
    const planProgress = JSON.parse(fs.readFileSync(progressPath, 'utf8'));

    // Update roadmap with minimal data from file
    planRef.status = planProgress.status || 'completed';
    planRef.completion_percentage = planProgress.completion_percentage || 100;

    // Save to file immediately
    roadmap.metadata.overall_completion_percentage = calculateOverallCompletion(roadmap);
    fs.writeFileSync(roadmapPath, JSON.stringify(roadmap, null, 2));

    // Minimal context output (summary only)
    console.log(`   ✓ ${planRef.status}: ${planRef.completion_percentage}%`);
    console.log(`   Roadmap: ${roadmap.metadata.overall_completion_percentage}%`);

    // Compact after plan if configured in orchestration block
    if (roadmap.orchestration?.compact_after_plan !== false) {
      console.log('   Compacting context after plan completion...');
      await compactContext();
    }

    // Sync to parent epic (file update, not context)
    if (roadmap.parent_epic) {
      await syncToParentEpic(roadmap);
    }
  }

  // Final status from file
  const allComplete = roadmap.phase_dev_plan_refs.every(p => p.status === 'completed');
  roadmap.status = allComplete ? 'completed' : 'partial';
  fs.writeFileSync(roadmapPath, JSON.stringify(roadmap, null, 2));

  console.log(`\n${allComplete ? '🎉 ALL PLANS COMPLETE!' : '⚠️ Some plans incomplete'}`);

  // Return minimal summary (not full results)
  return {
    success: allComplete,
    summary: `${roadmap.phase_dev_plan_refs.filter(p => p.status === 'completed').length}/${roadmap.phase_dev_plan_refs.length} plans complete`,
    roadmapPath // Reference to file for full details
  };
}

// Topological sort for dependency-ordered execution
function topologicalSortPlans(roadmap) {
  const sorted = [];
  const visited = new Set();

  function visit(planSlug) {
    if (visited.has(planSlug)) return;
    visited.add(planSlug);

    // Visit dependencies first
    const deps = roadmap.cross_plan_dependencies.filter(
      dep => dep.dependent_slug === planSlug
    );
    for (const dep of deps) {
      visit(dep.depends_on_slug);
    }

    // Add to sorted list
    const planRef = roadmap.phase_dev_plan_refs.find(ref => ref.slug === planSlug);
    if (planRef) {
      sorted.push(planRef);
    }
  }

  for (const planRef of roadmap.phase_dev_plan_refs) {
    visit(planRef.slug);
  }

  return sorted;
}
```

**Run-All Execution Rules (Multi-Plan, Context-Safe):**
1. **ONE PLAN AT A TIME** - Only one plan executes at any moment. This is a hard gate, not a suggestion
2. Plans execute in dependency order (topological sort)
3. Each plan delegates to /phase-track for detailed execution
4. **WAIT for /phase-track to RETURN before starting the next plan** - Do NOT launch the next plan while the current one is running
5. **Context checkpoint before each plan (pause at 70%)** - If >70%, STOP and offer /compact
6. **Results read from files, not from command output**
7. Plan references synced from PROGRESS.json files
8. Overall roadmap completion updated incrementally in ROADMAP.json
9. Execution continues until all plans complete or error occurs
10. User can interrupt, /compact, and resume at any time
11. If a plan fails, execution **STOPS** and offers recovery options (do NOT skip and continue)
12. **Full details in files, only summaries in context**
13. **NEVER launch background agents for plan execution** - all plan execution is foreground, sequential

#### Run All Plans with Parallel Mode (--parallel)

```
/roadmap-track {slug} run-all --parallel
```

Runs up to **2 plans concurrently** as background agents (if their dependencies are satisfied). Each plan internally calls `/phase-track {slug} --run-all`.

**Parallel Execution Protocol:**

1. Topological sort plans by `cross_plan_dependencies`
2. Find up to 2 plans whose dependencies are all satisfied
3. Launch both as background agents (`run_in_background: true`)
4. **Compact IMMEDIATELY** after launching agents
5. **Poll every 2 minutes** using `TaskOutput` with `timeout: 120000`
6. **Compact after EVERY poll** — whether the agent finished or not
7. When an agent completes, read its PROGRESS.json (ground truth), update ROADMAP.json, fill the next slot
8. If only 1 plan is available (due to dependencies), run it alone

**Context auto-compact threshold: 40% remaining (60% used)**
- Before each launch cycle: if context >= 60% used, save ROADMAP.json and STOP
- Resume with `/roadmap-track {slug} run-all --parallel`

```javascript
/**
 * Parallel mode: 2 plans at a time (if dependency-free).
 * Compact after launching, compact after every poll.
 */
async function runAllPlansParallel(roadmap) {
  const roadmapPath = `.claude/roadmaps/${roadmap.slug}/ROADMAP.json`;
  const orderedPlans = topologicalSortPlans(roadmap);
  const completedSlugs = new Set(
    orderedPlans.filter(p => p.status === 'completed').map(p => p.slug)
  );

  while (completedSlugs.size < orderedPlans.length) {
    // Context check (40% remaining = 60% used)
    const usage = await estimateContextUsage();
    if (usage.percent > (100 - (roadmap.orchestration?.context_threshold_percent || 40))) {
      console.log(`⛔ CONTEXT: ${usage.percent}% used. STOPPING.`);
      console.log(`   /compact then /roadmap-track ${roadmap.slug} run-all --parallel`);
      fs.writeFileSync(roadmapPath, JSON.stringify(roadmap, null, 2));
      return { paused: true };
    }

    // Find plans with satisfied dependencies
    const available = orderedPlans.filter(p =>
      !completedSlugs.has(p.slug) &&
      p.status !== 'in_progress' &&
      checkPlanDependencies(roadmap, p.slug).satisfied
    );

    if (available.length === 0) break;

    // Launch up to max_parallel_plans (default 2)
    const batch = available.slice(0, roadmap.orchestration?.max_parallel_plans || 2);
    const handles = [];

    for (const plan of batch) {
      plan.status = 'in_progress';
      fs.writeFileSync(roadmapPath, JSON.stringify(roadmap, null, 2));

      const h = await Task({
        description: `Plan: ${plan.slug}`,
        prompt: `Execute /phase-track ${plan.slug} --run-all\nReturn only: [PLAN:${plan.slug}] {status}: {summary}`,
        subagent_type: 'phase-orchestrator',
        model: roadmap.orchestration?.agent_model || 'sonnet',
        run_in_background: true
      });
      handles.push({ handle: h, plan });
    }

    // COMPACT IMMEDIATELY after launching
    await compactContext();

    // Poll every 2 minutes, compact after each
    for (const { handle, plan } of handles) {
      const result = await TaskOutput({
        task_id: handle.task_id,
        block: true,
        timeout: 120000  // 2 minutes
      });

      // Read PROGRESS.json for ground truth
      const planRef = roadmap.phase_dev_plan_refs.find(r => r.slug === plan.slug);
      const progress = JSON.parse(fs.readFileSync(planRef.path, 'utf8'));
      planRef.status = progress.status || 'completed';
      planRef.completion_percentage = progress.completion_percentage || 100;
      completedSlugs.add(plan.slug);

      roadmap.metadata.overall_completion_percentage = calculateOverallCompletion(roadmap);
      fs.writeFileSync(roadmapPath, JSON.stringify(roadmap, null, 2));

      // COMPACT after each poll
      await compactContext();
    }
  }

  const allDone = roadmap.phase_dev_plan_refs.every(p => p.status === 'completed');

  // If all plans complete, run compliance audit (if enabled)
  if (allDone && roadmap.compliance?.enabled) {
    await runComplianceAudit(roadmap);
  }

  roadmap.status = allDone ? 'completed' : 'partial';
  fs.writeFileSync(roadmapPath, JSON.stringify(roadmap, null, 2));

  return { status: roadmap.status };
}
```

### Compliance Audit at Roadmap Completion

**When all phase-dev-plans reach 100% completion AND compliance is enabled:**

```javascript
async function runComplianceAudit(roadmap) {
  console.log('\n🔍 Running compliance audit...\n');

  const roadmapPath = `.claude/roadmaps/${roadmap.slug}/ROADMAP.json`;

  // 1. Check documentation completeness
  const docs = roadmap.compliance.documentation || {};
  const incompleteDocs = [];

  if (docs.routes_md !== 'complete') incompleteDocs.push('ROUTES.md');
  if (docs.rbac_md !== 'complete') incompleteDocs.push('RBAC.md');
  if (docs.api_contract !== 'complete') incompleteDocs.push('API_CONTRACT.md');
  if (docs.erd !== 'complete') incompleteDocs.push('ERD');

  if (incompleteDocs.length > 0) {
    console.log(`⚠️  Compliance docs incomplete: ${incompleteDocs.join(', ')}`);
    console.log('   Pausing roadmap. Complete docs before marking as complete.\n');

    roadmap.status = 'paused';
    roadmap.compliance.status = 'planning';
    fs.writeFileSync(roadmapPath, JSON.stringify(roadmap, null, 2));
    return;
  }

  // 2. Run dependency license audit
  console.log('   Checking dependency licenses...');

  const auditResult = await auditDependencyLicenses();

  if (auditResult.blockedLicenses.length > 0) {
    console.log(`   ✗ BLOCKED LICENSES FOUND: ${auditResult.blockedLicenses.join(', ')}\n`);

    roadmap.compliance.status = 'failed';
    roadmap.compliance.audit = {
      last_audit_date: new Date().toISOString(),
      score: 0,
      verdict: 'FAIL',
      audit_file: `.claude/roadmaps/${roadmap.slug}/compliance-audit.json`,
      failure_reason: `Blocked licenses: ${auditResult.blockedLicenses.join(', ')}`
    };

    roadmap.status = 'paused';
    fs.writeFileSync(roadmapPath, JSON.stringify(roadmap, null, 2));

    console.log('   Roadmap PAUSED due to compliance failure.');
    console.log('   Fix license issues before marking complete.\n');
    return;
  }

  console.log('   ✓ No blocked licenses\n');

  // 3. Run self-audit verification
  console.log('   Checking plan self-audits...');

  const planAuditsFailed = [];

  for (const planRef of roadmap.phase_dev_plan_refs) {
    const progressPath = planRef.path;
    if (existsSync(progressPath)) {
      const progress = JSON.parse(fs.readFileSync(progressPath, 'utf8'));

      if (progress.compliance_config?.self_audit_status !== 'passed') {
        planAuditsFailed.push(planRef.slug);
      }
    }
  }

  if (planAuditsFailed.length > 0) {
    console.log(`   ✗ Plans failed self-audit: ${planAuditsFailed.join(', ')}\n`);

    roadmap.compliance.status = 'failed';
    roadmap.compliance.audit = {
      last_audit_date: new Date().toISOString(),
      score: 0,
      verdict: 'FAIL',
      audit_file: `.claude/roadmaps/${roadmap.slug}/compliance-audit.json`,
      failure_reason: `Plans failed self-audit: ${planAuditsFailed.join(', ')}`
    };

    roadmap.status = 'paused';
    fs.writeFileSync(roadmapPath, JSON.stringify(roadmap, null, 2));

    console.log('   Roadmap PAUSED due to failed plan audits.');
    console.log('   Review and fix failing plans before marking complete.\n');
    return;
  }

  console.log('   ✓ All plans passed self-audit\n');

  // 4. Calculate compliance score
  const score = calculateComplianceScore(roadmap, auditResult);

  // 5. Update compliance audit in ROADMAP.json
  roadmap.compliance.status = 'passed';
  roadmap.compliance.audit = {
    last_audit_date: new Date().toISOString(),
    score: score,
    verdict: 'PASS',
    audit_file: `.claude/roadmaps/${roadmap.slug}/compliance-audit.json`
  };

  fs.writeFileSync(roadmapPath, JSON.stringify(roadmap, null, 2));

  // 6. Write detailed audit file
  const auditDetails = {
    timestamp: new Date().toISOString(),
    roadmap_slug: roadmap.slug,
    verdict: 'PASS',
    score: score,
    documentation: {
      routes_md: docs.routes_md,
      rbac_md: docs.rbac_md,
      api_contract: docs.api_contract,
      erd: docs.erd
    },
    licenses: auditResult,
    plan_audits: roadmap.phase_dev_plan_refs.map(p => ({
      slug: p.slug,
      self_audit_status: 'passed'
    }))
  };

  const auditFilePath = `.claude/roadmaps/${roadmap.slug}/compliance-audit.json`;
  fs.writeFileSync(auditFilePath, JSON.stringify(auditDetails, null, 2));

  console.log(`✅ Compliance audit PASSED (Score: ${score}/100)\n`);
  console.log(`   Audit details: ${auditFilePath}\n`);
}

function calculateComplianceScore(roadmap, auditResult) {
  let score = 100;

  // Deduct for draft docs (not complete)
  const docs = roadmap.compliance.documentation || {};
  const draftDocs = Object.values(docs).filter(s => s === 'draft').length;
  score -= draftDocs * 5;

  // Deduct for risky licenses
  if (auditResult.riskyLicenses?.length > 0) {
    score -= auditResult.riskyLicenses.length * 2;
  }

  return Math.max(score, 0);
}

async function auditDependencyLicenses() {
  // This would call the actual compliance audit from src/compliance/index.js
  // For template purposes, return a mock structure
  return {
    blockedLicenses: [],
    riskyLicenses: [],
    approvedCount: 0,
    totalCount: 0
  };
}
```

### Step 5: Progress Visualization (Multi-Plan)

Generate ASCII progress bars for plans:

```
Phase-Dev-Plan Progress:
auth-backend:  ████████████████████ 100% ✅
auth-frontend: ████████████░░░░░░░░  60% 🔄 (3/5 phases)
auth-testing:  ░░░░░░░░░░░░░░░░░░░░   0% ⬜ (blocked by auth-frontend)

Overall: [█████████████░░░░░░░░░░░░░░░░░░░░░░] 53%

Dependencies:
  auth-frontend → auth-backend ✅
  auth-testing → auth-frontend ⚠️ (waiting)
```

#### Agent Mapping Display (when roadmapAgentMapping present)

If the roadmap has `roadmapAgentMapping`, display agent assignments per plan:

```
╠═══════════════════════════════════════════════════════════════════════════╣
║  AGENT ASSIGNMENTS                                                         ║
╠═══════════════════════════════════════════════════════════════════════════╣
║  auth-backend:                                                             ║
║     Primary: backend-fastapi-specialist                                    ║
║     Secondary: test-playwright-specialist                                  ║
║  auth-frontend:                                                            ║
║     Primary: frontend-react-specialist                                     ║
║     Secondary: state-zustand-specialist                                    ║
║  auth-testing:                                                             ║
║     Primary: test-playwright-specialist                                    ║
╠═══════════════════════════════════════════════════════════════════════════╣
```

**Populate `agents_assigned` display field** for each plan reference:
```javascript
function getAgentsAssigned(roadmap, planSlug) {
  const mapping = roadmap.roadmapAgentMapping?.[planSlug];
  if (!mapping) return null;
  return mapping.primary.join(', ');
}
```

### Step 6: Parent Epic Sync

If roadmap has parent epic:

```javascript
// Sync to parent epic
async function syncToParentEpic(roadmap) {
  if (!roadmap.parent_epic) return;

  const epicPath = roadmap.parent_epic.epic_path;
  if (!existsSync(epicPath)) {
    console.warn(`Parent epic not found: ${epicPath}`);
    return;
  }

  // Load epic
  const epic = JSON.parse(readFileSync(epicPath, 'utf8'));

  // Update roadmap reference in epic
  const roadmapRef = epic.roadmap_refs.find(ref => ref.slug === roadmap.slug);
  if (roadmapRef) {
    roadmapRef.status = roadmap.status;
    roadmapRef.completion_percentage = roadmap.metadata.overall_completion_percentage;
    roadmapRef.updated = new Date().toISOString();
  }

  // Save updated epic
  writeFileSync(epicPath, JSON.stringify(epic, null, 2));

  console.log(`Synced to parent epic: ${roadmap.parent_epic.epic_slug}`);
}
```

## Argument Handling (Multi-Plan)

- `/roadmap-track` - List all roadmaps, select one
- `/roadmap-track {slug}` - Show specific roadmap dashboard (multi-plan view)
- `/roadmap-track {slug} start {plan-slug}` - Start a plan (delegate to /phase-track)
- `/roadmap-track {slug} sync {plan-slug}` - Sync plan reference from PROGRESS.json
- `/roadmap-track {slug} sync-all` - Sync all plan references
- `/roadmap-track {slug} auto` - Auto-advance to next available plan
- `/roadmap-track {slug} run-all` - Run ALL plans sequentially (autonomous mode)
- `/roadmap-track {slug} run-all --parallel` - Run up to 2 plans concurrently (background agents, aggressive compacting)
- `/roadmap-track {slug} report` - Generate completion report
- `/roadmap-track {slug} track {plan-slug}` - Delegate to /phase-track for detailed plan execution

## Execution Rules (Multi-Plan)

1. **Dependency Enforcement**: Cannot start plan with unmet cross-plan dependencies
2. **ONE ACTIVE PLAN AT A TIME**: Only ONE plan may be `in_progress` at any moment. Do NOT start a second plan until the first completes. This prevents context overflow
3. **Plan Delegation**: Each plan delegates to /phase-track for detailed execution
4. **Sequential Execution**: Wait for `/phase-track` to return before starting the next plan
5. **Automatic Syncing**: Plan references auto-sync from PROGRESS.json after completion
6. **Parent Epic Sync**: Auto-sync to parent epic on plan completion if integrated
7. **Completion Aggregation**: Roadmap completion = average of all plan completions
8. **Failure = Full Stop**: If a plan fails, do NOT continue to the next plan. Stop and report

## Error Handling (Multi-Plan)

If plan execution fails:
1. Set plan reference status to 'blocked'
2. Record failure reason in plan PROGRESS.json
3. Update roadmap plan reference
4. Block dependent plans automatically
5. Suggest remediation steps (retry, skip, reassign)

## Plan Delegation Pattern

Roadmap delegates to /phase-track for each plan:

```
Roadmap-Track (L0) → coordinates plans
  ├─ /phase-track auth-backend → executes plan phases
  │   └─ spawns L2 specialists for tasks
  ├─ /phase-track auth-frontend → executes plan phases
  │   └─ spawns L2 specialists for tasks
  └─ /phase-track auth-testing → executes plan phases
      └─ spawns L2 specialists for tasks
```

**Key Pattern:**
- Roadmap-Track: Plan-level coordination
- Phase-Track: Phase/task-level execution
- L2 Specialists: Code-level implementation

## Metrics Tracking (Multi-Plan)

Track and display:
- Plans completed (total and this session)
- Overall roadmap completion percentage
- Individual plan completion percentages
- Cross-plan dependency status
- Parent epic sync status
- Time spent per plan

## Related Commands

- `/create-roadmap` - Create new roadmap
- `/roadmap-status` - View-only status (multi-plan view)
- `/roadmap-edit` - Modify roadmap structure and plan references
- `/phase-track` - Track individual phase-dev-plan in detail
- `/epic-track` - Track parent epic (if integrated)
- `/phase-dev-plan` - Create new phase-dev-plan

---

## Dynamic Command Cleanup on Completion

**IMPORTANT:** When a roadmap reaches 100% completion, offer to clean up the dynamic command.

### Completion Detection

```javascript
// When all phases are completed
if (completedPhases === totalPhases && percentage === 100) {
  const dynamicCommandPath = `.claude/commands/roadmap-${slug}.md`;

  // Display completion message
  console.log(`
╔═══════════════════════════════════════════════════════════════════════════╗
║  🎉 ROADMAP COMPLETE!                                                      ║
╠═══════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  ${roadmap.title}                                                          ║
║                                                                             ║
║  All ${totalPhases} phases completed                                       ║
║  Total tasks: ${completedTasks}/${totalTasks}                              ║
║                                                                             ║
╠═══════════════════════════════════════════════════════════════════════════╣
║  CLEANUP OPTIONS                                                            ║
╠═══════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  [1] Remove dynamic command: /roadmap-${slug}                              ║
║  [2] Archive roadmap files                                                  ║
║  [3] Keep everything (do nothing)                                          ║
║                                                                             ║
╚═══════════════════════════════════════════════════════════════════════════╝
  `);
}
```

### Cleanup Actions

**Option 1: Remove Dynamic Command**
```bash
rm .claude/commands/roadmap-{slug}.md
```

**Option 2: Archive Roadmap**
```bash
# Create archive directory
mkdir -p .claude/roadmaps/_archived/

# Move roadmap directory to archive
mv .claude/roadmaps/{slug}/ .claude/roadmaps/_archived/{slug}-{date}/

# Remove dynamic command
rm .claude/commands/roadmap-{slug}.md
```

**Option 3: Keep Everything**
- Roadmap remains accessible via `/roadmap-status {slug}`
- Dynamic command `/roadmap-{slug}` stays available
- Useful if you may resume or reference the roadmap later

### Auto-Cleanup Prompt

When completing the final phase via `/roadmap-track {slug} finish`:

```
header: "Roadmap Complete"
question: "All phases complete! What would you like to do with the roadmap?"
options:
  - label: "Remove dynamic command"
    description: "Delete /roadmap-{slug} command, keep roadmap files"
  - label: "Archive roadmap"
    description: "Move to _archived/, remove command"
  - label: "Keep everything"
    description: "Leave roadmap and command in place"
```

---

## Summary: Roadmap Multi-Plan Architecture

### What Changed

**OLD (Legacy):**
- Roadmap directly contained phases
- Roadmap managed phase execution
- Single ROADMAP.json with embedded phases

**NEW (Epic-Hierarchy):**
- Roadmap coordinates MULTIPLE phase-dev-plans
- Each plan has its own PROGRESS.json
- Roadmap tracks plan references, not phases directly
- Cross-plan dependencies managed at roadmap level
- Plans delegate to /phase-track for execution

### Why This Change

1. **Scalability**: Large roadmaps decompose into manageable plans
2. **Parallelization**: Multiple plans can run concurrently (if dependencies allow)
3. **Separation of Concerns**: Roadmap = plan coordination, Phase-Track = execution
4. **Epic Integration**: Roadmaps can report to parent epics
5. **Domain Isolation**: Backend, frontend, testing as separate plans

### Migration Path

Legacy roadmaps automatically migrate on load:
- Direct phases → converted to plan references
- Phase dependencies → cross-plan dependencies
- Existing PROGRESS.json files preserved
- Backwards compatible (can still read old format)

---

*Roadmap Track - Multi-Plan Coordinator*
*Part of CCASP Epic-Hierarchy Architecture*
