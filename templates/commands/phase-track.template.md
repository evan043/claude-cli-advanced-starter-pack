---
description: Track progress of phased development plans
model: haiku
---

# /phase-track - Phased Development Progress Tracker

View and update progress on phased development plans.

---

## HARD SEQUENTIAL GATES (NON-NEGOTIABLE)

**Phases execute ONE AT A TIME. Phase N+1 CANNOT start until Phase N status = `completed` in PROGRESS.json.**

### FORBIDDEN - Will Cause Context Overflow and Lost Work:
- **DO NOT** start Phase N+1 while Phase N is still `in_progress`
- **DO NOT** launch multiple phases in parallel (even via background agents)
- **DO NOT** launch tasks from different phases simultaneously
- **DO NOT** skip a phase that failed validation and continue to the next
- **DO NOT** interpret "run-all" as "run all at once" — it means "run all sequentially, one at a time"

### REQUIRED - Hard Gate Protocol:
1. **ONE phase at a time**: Execute all tasks in Phase N → verify all complete → mark Phase N `completed` → THEN start Phase N+1
2. **Verify via PROGRESS.json**: Read the file to confirm `status: "completed"` before advancing — do not rely on memory
3. **Context checkpoint**: Before EACH phase, check context usage. If >70%, STOP and offer /compact
4. **Failure = Full Stop**: If a task or phase fails, HALT execution. Do NOT continue to the next phase. Report the error and wait for user input
5. **File is source of truth**: Write to PROGRESS.json after EVERY task completion. If the session crashes, progress is preserved

---

{{#if phasedDevelopment.enabled}}

## System Task Handling

When executing phases, you will encounter tasks with `task_type: "system"` or `task_type: "orchestration"`. These are mandatory orchestration steps injected into every phase:

| Task ID Pattern | Type | Action |
|----------------|------|--------|
| `X.0-context-check` | system | Check context %. If above threshold from `orchestration.compact_threshold_percent`, run /compact |
| `X.0-batch-plan` | orchestration | Analyze implementation tasks, group into non-overlapping batches of max `orchestration.max_parallel_agents` |
| `X.99-compact` | system | Run /compact, verify PROGRESS.json saved to disk |
| `X.99-gate` | system | Re-read PROGRESS.json from disk, verify ALL phase tasks complete. HALT if any incomplete |

**NEVER skip system tasks.** They are as mandatory as implementation tasks. Mark them completed in PROGRESS.json just like any other task. System tasks execute inline (not as background agents).

### Reading Agent Mapping from PROGRESS.json

Phases may include an `agent_mapping` block that pre-computes which agents handle which tasks and groups them into dependency-ordered batches:

```json
{
  "phases": [{
    "id": 1,
    "name": "Core Implementation",
    "agent_mapping": {
      "primary_agents": ["frontend-react-specialist"],
      "secondary_agents": ["state-zustand-specialist"],
      "total_batches": 3,
      "batches": [
        {
          "batch": 1,
          "parallel_tasks": [
            {"task_id": "1.1", "agents": ["frontend-react-specialist"]},
            {"task_id": "1.3", "agents": ["backend-fastapi-specialist"]}
          ]
        },
        {
          "batch": 2,
          "parallel_tasks": [
            {"task_id": "1.2", "agents": ["frontend-react-specialist"]},
            {"task_id": "1.4", "agents": ["state-zustand-specialist"]}
          ]
        },
        {
          "batch": 3,
          "parallel_tasks": [
            {"task_id": "1.5", "agents": ["test-playwright-specialist"]}
          ]
        }
      ]
    },
    "tasks": [...]
  }]
}
```

**When `agent_mapping` is present:**
- `selectIndependentBatch()` uses pre-computed `batches[]` instead of file-overlap heuristic
- Each task's `agents[0]` is used as the `subagent_type` for that task
- Batch visualization shows groupings in the progress display

**When `agent_mapping` is absent (legacy plans):**
- Falls back to existing file-overlap-based batch selection (fully backwards compatible)
- Tasks use `assignedAgent` or `l2-specialist` as the subagent_type

### Reading Orchestration Config

All thresholds and limits are read from the `orchestration` block in PROGRESS.json:
```json
{
  "orchestration": {
    "mode": "parallel",
    "max_parallel_agents": 2,
    "batch_strategy": "no_file_overlap",
    "compact_threshold_percent": 40,
    "poll_interval_seconds": 120,
    "compact_after_launch": true,
    "compact_after_poll": true,
    "agent_model": "sonnet"
  }
}
```

If `orchestration` is missing (legacy plans), use defaults: `max_parallel_agents: 2, compact_threshold_percent: 40, poll_interval_seconds: 120, agent_model: 'sonnet'`.

## Configuration

| Setting | Value |
|---------|-------|
| Default Scale | {{phasedDevelopment.defaultScale}} |
| Success Target | {{phasedDevelopment.successTarget}} ({{phasedDevelopment.successTarget * 100}}%) |
| Progress File | {{phasedDevelopment.progressFile}} |

## Available Projects

Scan for active phased development projects in **both structures**:

```bash
# NEW CONSOLIDATED STRUCTURE (preferred):
# Roadmaps with phases in: .claude/roadmaps/{slug}/phase-*.json

# LEGACY STRUCTURE (fallback):
# Phase plans in: .claude/phase-plans/{slug}/
# Progress files in: .claude/docs/*/PROGRESS.json

# Find all phase plans (new structure)
find .claude/roadmaps -name "phase-*.json" -type f 2>/dev/null

# Find legacy PROGRESS.json files
find .claude/docs -name "PROGRESS.json" -type f 2>/dev/null

# Or on Windows
dir /s /b .claude\roadmaps\phase-*.json
dir /s /b .claude\docs\PROGRESS.json
```

## Progress File Structure

```json
{
  "projectName": "Feature X",
  "scale": "M",
  "targetSuccess": 0.95,
  "agent_assignments": {
    "available": true,
    "count": 5,
    "byDomain": {
      "frontend": "frontend-react-specialist",
      "backend": "backend-fastapi-specialist"
    }
  },
  "phases": [
    {
      "id": 1,
      "name": "Setup & Foundation",
      "status": "completed",
      "assignedAgent": "backend-fastapi-specialist",
      "tasks": [
        { "id": "1.1", "description": "Create database schema", "completed": true },
        { "id": "1.2", "description": "Set up API endpoints", "completed": true }
      ],
      "completedAt": "2025-01-30T10:00:00Z"
    },
    {
      "id": 2,
      "name": "Core Implementation",
      "status": "in_progress",
      "assignedAgent": "frontend-react-specialist",
      "tasks": [
        { "id": "2.1", "description": "Implement business logic", "completed": true },
        { "id": "2.2", "description": "Add validation", "completed": false }
      ]
    }
  ],
  "metrics": {
    "totalTasks": 10,
    "completedTasks": 5,
    "currentPhase": 2,
    "estimatedCompletion": "2025-01-31"
  }
}
```

## Commands

### View Progress

```
/phase-track <project-slug>
```

Displays:
- Overall progress percentage
- Current phase status
- Remaining tasks
- Estimated completion

### Update Task Status

```
/phase-track <project-slug> --complete <task-id>
```

Marks a task as completed and updates metrics.

### Generate Report

```
/phase-track <project-slug> --report
```

Generates a markdown progress report.

### Run All Phases (Autonomous Mode - STRICTLY Sequential)

```
/phase-track <project-slug> --run-all
```

Executes ALL remaining phases **one at a time, in order**. "Run-all" does NOT mean "run all at once."

**Hard Gate Rules:**
- Only ONE phase runs at any moment. The next phase WAITS for the current to complete
- Phase N must reach `status: "completed"` in PROGRESS.json before Phase N+1 can begin
- If a phase fails, execution STOPS — it does NOT skip to the next phase

**Execution behavior:**
- Starts from current phase (or Phase 1 if none active)
- Completes all tasks in each phase before moving to next
- **Updates PROGRESS.json after each task (file is source of truth)**
- **Context checkpoint at 70% - STOPS for /compact if needed**
- **Returns summaries only - full results in cache files**
- Continues until all phases complete or an error occurs
- Can be interrupted with Ctrl+C at any time
- **Safe to /compact mid-execution - progress is preserved in files**

**Context Safety:**
- All task results written to `.claude/cache/agent-outputs/`
- PROGRESS.json updated immediately after each task
- Parent orchestrators receive summary only (max 200 chars)
- Use `/context-audit` to check current utilization

**Ideal for:**
- Well-defined plans with clear task boundaries
- Overnight or unattended execution
- When you want Claude to handle the entire implementation
- **Long-running sessions that may hit context limits**

### Run All Phases with Parallel Tasks (--parallel)

```
/phase-track <project-slug> --run-all --parallel
```

Same as `--run-all` but runs up to **2 tasks at a time** within each phase using background agents. Phases are still strictly sequential (hard gate unchanged).

**Parallel Execution Protocol:**

1. **Phases remain STRICTLY SEQUENTIAL** — Phase N+1 cannot start until Phase N completes
2. Within a phase, pick up to 2 independent tasks (no shared files, no `depends_on` overlap)
3. Launch both as background agents (`run_in_background: true`)
4. **Compact IMMEDIATELY** after launching agents — do not wait, compact right away
5. **Poll every 2 minutes** using `TaskOutput` with `timeout: 120000`
6. **Compact after EVERY poll** — whether the agent finished or not
7. When an agent completes, update PROGRESS.json immediately and pick the next available task
8. If fewer than 2 independent tasks remain, fall back to sequential (batch of 1)

**Context auto-compact threshold: 40% remaining (60% used)**
- Before each batch: if context >= 60% used, save state and STOP
- This is more aggressive than sequential mode (which stops at 70%)

**Why compact so aggressively?**
- Background agents return their full output into context when polled
- Each poll injects agent results — compacting after each prevents accumulation
- The 2-minute cadence gives agents time to work while keeping context lean

```javascript
/**
 * Parallel mode: 2 tasks at a time within each phase.
 * Compact after launching agents, compact after every poll.
 * Phases are still strictly sequential.
 */
async function runAllPhasesParallel(progressPath) {
  const cacheDir = '.claude/cache/agent-outputs';
  const batchId = `phase-par-${Date.now()}`;
  let progress = JSON.parse(fs.readFileSync(progressPath, 'utf8'));

  for (const phase of progress.phases) {
    if (phase.status === 'completed') continue;

    // HARD GATE: context check (40% remaining = 60% used)
    const usage = await estimateContextUsage();
    if (usage.percent > (100 - (progress.orchestration?.compact_threshold_percent || 40))) {
      console.log(`⛔ CONTEXT: ${usage.percent}% used (40% remaining threshold). STOPPING.`);
      console.log(`   /compact then /phase-track ${slug} --run-all --parallel`);
      fs.writeFileSync(progressPath, JSON.stringify(progress, null, 2));
      return { paused: true, atPhase: phase.id };
    }

    // HARD GATE: previous phase must be completed
    const idx = progress.phases.indexOf(phase);
    if (idx > 0 && progress.phases[idx - 1].status !== 'completed') {
      return { blocked: true, atPhase: phase.id };
    }

    phase.status = 'in_progress';
    let pending = phase.tasks.filter(t => !t.completed);

    while (pending.length > 0) {
      // Pick up to 2 independent tasks (uses agent_mapping batches if available)
      const batch = selectIndependentBatch(pending, progress.orchestration?.max_parallel_agents || 2, phase);

      if (batch.length > 1) {
        // Launch both as background agents
        // Agent selection priority: agent_mapping.agents[0] > task.assignedAgent > 'l2-specialist'
        const handles = [];
        for (const task of batch) {
          const h = await Task({
            description: `Task ${task.id}: ${task.description.slice(0, 40)}`,
            prompt: buildAOPPrompt(task, cacheDir, batchId),
            subagent_type: task.assignedAgent || 'l2-specialist',
            model: progress.orchestration?.agent_model || 'sonnet',
            run_in_background: true
          });
          handles.push({ handle: h, task });
        }

        // COMPACT IMMEDIATELY after launching agents
        if (progress.orchestration?.compact_after_launch !== false) {
          await compactContext();
        }

        // Poll every 2 minutes, compact after each poll
        for (const { handle, task } of handles) {
          const result = await TaskOutput({
            task_id: handle.task_id,
            block: true,
            timeout: (progress.orchestration?.poll_interval_seconds || 120) * 1000
          });

          // Update PROGRESS.json immediately
          const aop = parseAOPResult(result);
          task.completed = aop.status === 'success';
          task.resultSummary = aop.summary.slice(0, 200);
          task.resultFile = aop.detailsFile;
          task.completedAt = new Date().toISOString();
          fs.writeFileSync(progressPath, JSON.stringify(progress, null, 2));

          // COMPACT after each poll result
          if (progress.orchestration?.compact_after_poll !== false) {
            await compactContext();
          }
        }
      } else {
        // Single task — run inline (same as sequential mode)
        const task = batch[0];
        const result = await executeTaskContextSafe(task, cacheDir, batchId);
        task.completed = result.status === 'success';
        task.resultSummary = result.summary.slice(0, 200);
        task.resultFile = result.detailsFile;
        fs.writeFileSync(progressPath, JSON.stringify(progress, null, 2));
      }

      // Refresh pending
      progress = JSON.parse(fs.readFileSync(progressPath, 'utf8'));
      const p = progress.phases.find(p => p.id === phase.id);
      pending = p.tasks.filter(t => !t.completed);
    }

    // Mark phase complete if all tasks done
    const allDone = phase.tasks.every(t => t.completed);
    phase.status = allDone ? 'completed' : 'partial';
    fs.writeFileSync(progressPath, JSON.stringify(progress, null, 2));

    if (!allDone) return { status: 'partial', atPhase: phase.id };
  }

  return { status: 'completed' };
}

function selectIndependentBatch(pending, max, phase) {
  // PREFER pre-computed batches from agent_mapping (if present)
  if (phase?.agent_mapping?.batches?.length > 0) {
    return selectFromPrecomputedBatches(pending, max, phase.agent_mapping.batches);
  }

  // FALLBACK: file-overlap heuristic (legacy plans without agent_mapping)
  return selectByFileOverlap(pending, max);
}

function selectFromPrecomputedBatches(pending, max, batches) {
  const pendingIds = new Set(pending.filter(t => !t.completed).map(t => t.id));

  // Find first batch with pending tasks
  for (const batch of batches) {
    const batchTasks = batch.parallel_tasks
      .filter(bt => pendingIds.has(bt.task_id))
      .slice(0, max)
      .map(bt => {
        const task = pending.find(t => t.id === bt.task_id);
        // Inject agent from mapping if not already set
        if (task && bt.agents?.length > 0 && !task.assignedAgent) {
          task.assignedAgent = bt.agents[0];
        }
        return task;
      })
      .filter(Boolean);

    if (batchTasks.length > 0) return batchTasks;
  }

  // No pre-computed batch matches — fall back to first pending task
  const first = pending.find(t => !t.completed);
  return first ? [first] : [];
}

function selectByFileOverlap(pending, max) {
  const batch = [];
  const usedFiles = new Set();

  // Filter out system/orchestration tasks (they run inline, not as agents)
  const agentTasks = pending.filter(t =>
    t.task_type !== 'system' && t.task_type !== 'orchestration'
  );

  for (const task of agentTasks) {
    if (batch.length >= max) break;

    // Skip if depends on unfinished task
    if (task.blockedBy?.some(dep => pending.some(p => p.id === dep && !p.completed))) continue;

    // Skip if file conflict with batch
    const taskFiles = (task.files || []).map(f => typeof f === 'string' ? f : f.path);
    if (taskFiles.some(f => usedFiles.has(f))) continue;

    batch.push(task);
    taskFiles.forEach(f => usedFiles.add(f));
  }

  return batch.length > 0 ? batch : (agentTasks.length > 0 ? [agentTasks[0]] : []);
}
```

## Progress Visualization

```
Project: Feature X (M scale, 95% target)
════════════════════════════════════════

Phase 1: Setup & Foundation     ████████████████████ 100% ✓  🤖 backend-fastapi-specialist
Phase 2: Core Implementation    ████████████░░░░░░░░  60%    🤖 frontend-react-specialist
Phase 3: Testing & Validation   ░░░░░░░░░░░░░░░░░░░░   0%    🤖 testing-playwright-specialist
Phase 4: Documentation          ░░░░░░░░░░░░░░░░░░░░   0%

Overall: ████████░░░░░░░░░░░░  40% (4/10 tasks)

Current Task: 2.2 - Add validation
Assigned Agent: frontend-react-specialist
```

### Batch Visualization (when agent_mapping present)

When a phase has `agent_mapping.batches`, display batch groupings:

```
Phase 2: Core Implementation (3 batches)
════════════════════════════════════════

  Batch 1 (parallel):
    ✓ 2.1  Create component shell      🤖 frontend-react-specialist
    ✓ 2.3  Add API endpoint            🤖 backend-fastapi-specialist

  Batch 2 (parallel):  ◀ CURRENT
    ▶ 2.2  Wire state management       🤖 state-zustand-specialist
    ▶ 2.4  Add form validation         🤖 frontend-react-specialist

  Batch 3 (sequential):
    ○ 2.5  Integration tests           🤖 test-playwright-specialist

  Primary Agents: frontend-react-specialist
  Secondary Agents: backend-fastapi-specialist, state-zustand-specialist
```

**Batch display rules:**
- Show `✓` for completed tasks, `▶` for in-progress, `○` for pending
- Mark current batch with `◀ CURRENT`
- Show agent name next to each task
- Show primary/secondary agents summary below batches
- If no `agent_mapping`, skip batch visualization (use standard progress bar)

{{#if agents.available}}
## Agent Assignments

When agent registry is available, each phase shows its assigned specialist agent.
Deploy the assigned agent when executing phase tasks for domain-specific expertise.

| Phase | Assigned Agent | Domain |
|-------|---------------|--------|
{{#if agents.frontend}}| Frontend phases | {{agents.frontend.name}} | frontend |{{/if}}
{{#if agents.backend}}| Backend phases | {{agents.backend.name}} | backend |{{/if}}
{{#if agents.database}}| Database phases | {{agents.database.name}} | database |{{/if}}
{{#if agents.testing}}| Testing phases | {{agents.testing.name}} | testing |{{/if}}
{{#if agents.deployment}}| Deployment phases | {{agents.deployment.name}} | deployment |{{/if}}
{{/if}}

## Ralph Loop Integration

For testing phases or when validation tests fail, use Ralph Loop for continuous test-fix cycles:

### When to Use Ralph Loop

- After completing implementation phases
- When phase validation tests fail
- During "Testing & Validation" phases
- Before marking a phase as complete

### Recommended Workflow

```
1. Complete implementation tasks in phase
2. Run phase validation tests
3. If tests fail → /ralph to start continuous loop
4. Ralph fixes failures automatically
5. When all pass → Mark phase complete
```

### Testing Configuration

```json
// From PROGRESS.json
{
  "testing_config": {
    "ralph_loop": {
      "enabled": true,
      "testCommand": "npm test",
      "maxIterations": 10,
      "autoStart": false
    },
    "e2e_framework": "playwright",
    "testingAgentAvailable": true,
    "testingAgentName": "testing-playwright-specialist"
  }
}
```

### Ralph Loop Commands

| Command | Description |
|---------|-------------|
| `/ralph` | Auto-detect tests, start loop |
| `/ralph npm test` | Use specific test command |
| `/ralph --max 15` | Increase iteration limit |
| `/ralph --stop` | Stop current loop |

{{#if testing.e2e.framework}}
**E2E Testing**: Use `/ralph --playwright` for {{testing.e2e.framework}} tests
{{/if}}

> 💡 **Tip**: Enable Ralph Loop auto-start in PROGRESS.json to automatically begin test-fix cycles after each phase.

## Instructions for Claude

When this command is invoked:

1. If no project specified, list all available projects with PROGRESS.json
2. If project specified:
   - Load PROGRESS.json
   - Display progress visualization
   - Show current phase and task details
3. If --complete flag, update task status and recalculate metrics
4. If --report flag, generate markdown report
5. **If --run-all flag, execute context-safe autonomous mode:**

### Run-All Context-Safe Implementation

```javascript
/**
 * HARD GATE: Phases execute ONE AT A TIME, in strict order.
 * Phase N+1 CANNOT start until Phase N is "completed" in PROGRESS.json.
 * This function NEVER launches multiple phases in parallel.
 * Violating this causes context overflow — the exact bug this prevents.
 */
async function runAllPhasesContextSafe(progressPath) {
  const cacheDir = '.claude/cache/agent-outputs';
  const batchId = `phase-run-${Date.now()}`;

  // Load state from file (not from context/memory)
  let progress = JSON.parse(fs.readFileSync(progressPath, 'utf8'));

  for (const phase of progress.phases) {
    if (phase.status === 'completed') {
      console.log(`✓ Phase ${phase.id} complete`);
      continue;
    }

    // ═══════════════════════════════════════════════════════════════
    // HARD GATE #1: Context check BEFORE each phase (not after)
    // ═══════════════════════════════════════════════════════════════
    const usage = await estimateContextUsage();
    if (usage.percent > (100 - (progress.orchestration?.compact_threshold_percent || 40))) {
      console.log(`\n⛔ CONTEXT GATE: ${usage.percent}% used. STOPPING execution.`);
      console.log('   Run /compact then resume with /phase-track ${slug} --run-all');
      console.log('   Progress is saved — you will pick up where you left off.\n');
      fs.writeFileSync(progressPath, JSON.stringify(progress, null, 2));
      return { paused: true, atPhase: phase.id, progressPath };
    }

    // ═══════════════════════════════════════════════════════════════
    // HARD GATE #2: Verify previous phase completed before starting
    // ═══════════════════════════════════════════════════════════════
    const phaseIndex = progress.phases.indexOf(phase);
    if (phaseIndex > 0) {
      const prevPhase = progress.phases[phaseIndex - 1];
      if (prevPhase.status !== 'completed') {
        console.log(`\n⛔ HARD GATE: Cannot start Phase ${phase.id}`);
        console.log(`   Previous Phase ${prevPhase.id} status: "${prevPhase.status}" (must be "completed")`);
        console.log(`   Complete Phase ${prevPhase.id} first, then retry.`);
        return { blocked: true, atPhase: phase.id, reason: `Phase ${prevPhase.id} not complete` };
      }
    }

    console.log(`\n▶ Phase ${phase.id}: ${phase.name} (ONLY phase running right now)`);
    phase.status = 'in_progress';

    // Execute tasks with AOP
    for (const task of phase.tasks) {
      if (task.completed) continue;

      // Task execution with summary-only return
      const result = await executeTaskContextSafe(task, cacheDir, batchId);

      // Update file immediately
      task.completed = result.status === 'success';
      task.resultSummary = result.summary.slice(0, 200);
      task.resultFile = result.detailsFile;
      fs.writeFileSync(progressPath, JSON.stringify(progress, null, 2));

      console.log(`   ${task.completed ? '✓' : '✗'} ${task.id}: ${result.summary.slice(0, 50)}`);
    }

    // Update phase status
    const allTasksComplete = phase.tasks.every(t => t.completed);
    phase.status = allTasksComplete ? 'completed' : 'partial';
    phase.completedAt = phase.status === 'completed' ? new Date().toISOString() : null;
    fs.writeFileSync(progressPath, JSON.stringify(progress, null, 2));

    // ═══════════════════════════════════════════════════════════════
    // HARD GATE #3: If phase did NOT complete, STOP — do NOT continue
    // ═══════════════════════════════════════════════════════════════
    if (!allTasksComplete) {
      const failedTasks = phase.tasks.filter(t => !t.completed);
      console.log(`\n⛔ Phase ${phase.id} has ${failedTasks.length} incomplete task(s). HALTING.`);
      console.log(`   Failed: ${failedTasks.map(t => t.id).join(', ')}`);
      console.log(`   Fix these tasks before continuing to Phase ${phase.id + 1}.`);
      return {
        status: 'partial',
        summary: `Stopped at Phase ${phase.id}: ${failedTasks.length} tasks incomplete`,
        progressPath
      };
    }
  }

  // Calculate final metrics
  const completed = progress.phases.filter(p => p.status === 'completed').length;
  progress.status = completed === progress.phases.length ? 'completed' : 'partial';
  progress.completion_percentage = Math.round((completed / progress.phases.length) * 100);
  fs.writeFileSync(progressPath, JSON.stringify(progress, null, 2));

  // Return summary only (parent reads details from file)
  return {
    status: progress.status,
    summary: `${completed}/${progress.phases.length} phases complete (${progress.completion_percentage}%)`,
    progressPath
  };
}

async function executeTaskContextSafe(task, cacheDir, batchId) {
  const outputFile = `${cacheDir}/${batchId}-task-${task.id}.json`;

  // If task has assigned agent, use it with AOP prompt
  if (task.assignedAgent) {
    const result = await Task({
      description: `Task ${task.id}: ${task.description.slice(0, 30)}`,
      prompt: `${task.description}

**OUTPUT REQUIREMENTS (Context Safety):**
1. Write detailed results to: ${outputFile}
2. Return ONLY:
   [AOP:SUMMARY] Brief description of what was done
   [AOP:DETAILS_FILE] ${outputFile}
   [AOP:STATUS] success|failure`,
      subagent_type: task.assignedAgent,
      model: 'haiku',
      run_in_background: false
    });

    return extractAOPResult(result);
  }

  // Direct execution for simple tasks
  return { status: 'success', summary: 'Task completed', detailsFile: null };
}
```

{{else}}

## Phased Development Disabled

Phased development system is not enabled for this project.

To enable:
1. Run `/menu` → Project Settings (if available)
2. Or set `phasedDevelopment.enabled: true` in tech-stack.json
3. Use `/create-phase-dev` to create a new phased plan

{{/if}}

---

*Generated from tech-stack.json template*
