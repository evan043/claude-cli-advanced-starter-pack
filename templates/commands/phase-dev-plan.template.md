---
description: Create phased development plans with 95%+ success probability
options:
  - label: "Small (1-2 phases)"
    description: "Quick feature or bug fix"
  - label: "Medium (3-4 phases)"
    description: "Standard feature implementation"
  - label: "Large (5+ phases)"
    description: "Complex multi-system changes"
---

# Phased Development Plan Generator

Create comprehensive, executable development plans that maximize success probability.

**NEW EPIC-HIERARCHY ARCHITECTURE:**
- Supports parent roadmap context via --parent-roadmap flag
- Supports parent epic context via --parent-epic flag
- Includes parent_context in PROGRESS.json
- Reports PHASE_DEV_COMPLETE to parent when all phases complete
- Uses src/phase-dev/completion-reporter.js for parent notification

---

## 🚨 MANDATORY FILE CREATION - DO NOT SKIP

**CRITICAL:** Every phase-dev-plan MUST create ALL of these files. Skipping ANY file is a failure.

### Exploration Documentation (REQUIRED FIRST - Step 2)
Before creating PROGRESS.json, you MUST create these 6 files in `.claude/exploration/{slug}/`:

| File | Purpose | Required |
|------|---------|----------|
| `EXPLORATION_SUMMARY.md` | Overview + statistics | ✅ YES |
| `CODE_SNIPPETS.md` | Extracted code examples | ✅ YES |
| `REFERENCE_FILES.md` | File paths + line numbers | ✅ YES |
| `AGENT_DELEGATION.md` | Agent assignments per task | ✅ YES |
| `PHASE_BREAKDOWN.md` | Full phase/task detail | ✅ YES |
| `findings.json` | Machine-readable data | ✅ YES |

### Plan Files (AFTER Exploration - Step 3+)
| File | Purpose | Required |
|------|---------|----------|
| `.claude/phase-plans/{slug}/PROGRESS.json` | State tracking | ✅ YES |
| `.claude/phase-plans/{slug}/EXECUTIVE_SUMMARY.md` | Overview | ✅ YES |
| `.claude/commands/{slug}-executor.md` | Phase executor agent | ✅ YES |
| `.claude/commands/{slug}.md` | Interactive command | ✅ YES |

---

## Why Phased Development?

- Breaks complex tasks into manageable chunks
- Each phase is independently testable
- Clear checkpoints for progress tracking
- Rollback points if issues arise

## Execution Protocol

### Step 1: Gather Requirements

Use AskUserQuestion to collect:
1. **Project name** (human-readable)
2. **Project slug** (kebab-case)
3. **Description** (what to build)
4. **Scale** (S/M/L)

**NEW: Check for parent context flags:**
- `--parent-roadmap {path}` - Path to parent ROADMAP.json
- `--parent-epic {slug}` - Slug of parent epic

**If parent context provided:**
1. Read the parent file to extract context
2. Store parent reference in PROGRESS.json
3. Include parent title/slug in plan metadata
4. **If parent is a roadmap with `compliance.enabled`:**
   - Extract compliance config from parent ROADMAP.json
   - Store as `compliance_config` in PROGRESS.json
   - Include multi-tenancy strategy, RBAC roles, and doc requirements
   - Display compliance inheritance notice:
   ```
   ╔═══════════════════════════════════════════════════════════════╗
   ║  Compliance Inherited from Roadmap                           ║
   ╠═══════════════════════════════════════════════════════════════╣
   ║                                                              ║
   ║  Mode: Commercial SaaS                                       ║
   ║  Multi-Tenancy: {strategy}                                   ║
   ║  RBAC Roles: {roles}                                         ║
   ║  Self-Audit: Required before completion                      ║
   ║                                                              ║
   ╚═══════════════════════════════════════════════════════════════╝
   ```

### Step 2: L2 Exploration (MANDATORY - DO NOT SKIP)

**CRITICAL:** You MUST run L2 exploration BEFORE creating plan files.

1. **Deploy Explore Agent** - Use Task tool with `subagent_type: "Explore"` thoroughness "very thorough"
2. **Create Exploration Directory:** `mkdir -p .claude/exploration/{slug}`
3. **Write ALL 6 Exploration Files** in `.claude/exploration/{slug}/`:
   - EXPLORATION_SUMMARY.md (overview + statistics)
   - CODE_SNIPPETS.md (code examples from codebase)
   - REFERENCE_FILES.md (files to modify/reference)
   - AGENT_DELEGATION.md (agent assignments)
   - PHASE_BREAKDOWN.md (full phase/task detail)
   - findings.json (machine-readable)

4. **Verification Checkpoint** - STOP and verify ALL 6 files exist before continuing

5. **If compliance_config inherited from parent:**
   - Include in exploration agent prompt: "This plan must enforce multi-tenancy with {strategy} resolution"
   - Include: "RBAC roles: {roles} — all routes and APIs must check roles"
   - Include: "All API endpoints must specify method/auth/role/tenant scope"
   - Include: "Frontend routes must map to ROUTES.md definitions"
   - Agent should identify existing auth/tenancy/RBAC patterns in codebase

**⛔ DO NOT proceed to Step 3 until ALL 6 exploration files exist.**

### Step 2.8: Check Build Tier Configuration (If Competitor Research Active)

**Check tech-stack.json for build tier configuration:**
```javascript
// Read build tier config from tech-stack.json
const buildTier = techStack.buildTier || {};
const tier = buildTier.tier; // "b2c_mvp" or "enterprise_b2b" or undefined
const phaseOrdering = buildTier.roadmap_phase_ordering || [];
```

**If build tier is configured**, display and apply:

```
╔═══════════════════════════════════════════════════════════════╗
║  Build Tier Detected                                         ║
╠═══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Tier: {B2C MVP / Enterprise B2B}                            ║
║  Phase ordering: {phaseOrdering summary}                     ║
║                                                              ║
║  Stubbed features will generate CCASP:STUB placeholders.     ║
║  Enable later via Project Configuration panel.               ║
║                                                              ║
╚═══════════════════════════════════════════════════════════════╝
```

**Phase ordering by tier:**

- **B2C MVP**: Foundation → Auth/Onboarding → Core Features → Payments → Growth/Viral → Polish
- **Enterprise B2B**: Billing Foundation → Registration/Tenancy → Admin Dashboard → Core Features → API/Integrations → Compliance/Scale

Use the tier-specific phase ordering from `buildTier.roadmap_phase_ordering` when generating the phase breakdown in Step 3. If no build tier is configured, use the default ordering.

### Step 3: Generate Phase Breakdown
Based on exploration findings, create phases with clear objectives, success criteria, and agent assignments.

**If build tier is configured, use tier-specific phase ordering** from Step 2.8. B2C MVP plans should prioritize revenue-generating features early; Enterprise B2B plans should prioritize infrastructure and compliance.

**If compliance_config is active, add mandatory compliance tasks:**

- **First phase:** Add task "Define route map for this plan's scope" (if ROUTES.md not yet complete)
- **Backend phases:** Add task "Define API contracts for endpoints in this phase" with method/auth/role/tenant
- **All phases with data access:** Add task "Verify tenant isolation on all database queries"
- **All phases with UI:** Add task "Verify route guards match RBAC.md permissions"
- **Last phase:** Add task "Run self-audit compliance checklist" (MANDATORY — cannot skip)

These compliance tasks use the same task format as other tasks but are tagged with `"compliance": true` in PROGRESS.json.

### Step 3.5: Compute Agent Mapping Per Phase

**After generating the phase breakdown, compute `agent_mapping` for each phase.**

For each phase:

1. **Read agent registry** from `.claude/config/agents.json` (if available)
2. **Analyze each task's type/keywords** and match against agent triggers
3. **Build dependency graph** from `task.depends_on` / `task.blockedBy`
4. **Topological sort into batches:**
   - Batch 1: all tasks with no dependencies
   - Batch 2: tasks depending only on batch 1 tasks
   - Batch N: tasks depending only on batches 1..N-1
5. **Cap each batch** at `orchestration.max_parallel_agents` (default 2)
6. **Write `agent_mapping` into each phase** of PROGRESS.json

```javascript
function computePhaseAgentMapping(phase, agentRegistry, maxParallel) {
  if (!agentRegistry?.specialists?.length) return null;

  // Match tasks to agents
  const taskAgents = phase.tasks
    .filter(t => t.task_type !== 'system' && t.task_type !== 'orchestration')
    .map(task => {
      const matched = agentRegistry.specialists.find(agent =>
        agent.triggers?.some(trigger =>
          task.description.toLowerCase().includes(trigger.toLowerCase())
        )
      );
      return {
        task_id: task.id,
        agents: matched ? [matched.subagent_type] : ['l2-specialist']
      };
    });

  // Build dependency-ordered batches
  const completed = new Set();
  const batches = [];
  const taskMap = new Map(phase.tasks.map(t => [t.id, t]));

  while (completed.size < taskAgents.length) {
    const batch = [];
    for (const ta of taskAgents) {
      if (completed.has(ta.task_id)) continue;
      const task = taskMap.get(ta.task_id);
      const deps = task?.depends_on || task?.blockedBy || [];
      if (deps.every(dep => completed.has(dep))) {
        batch.push(ta);
      }
    }
    if (batch.length === 0) break;

    // Cap at max_parallel_agents
    const capped = batch.slice(0, maxParallel || 2);
    capped.forEach(bt => completed.add(bt.task_id));
    // Add remaining from this batch level in next iteration
    batch.slice(maxParallel || 2).forEach(() => {}); // handled next loop

    batches.push({
      batch: batches.length + 1,
      parallel_tasks: capped
    });

    // Mark all from this dependency level as completed for next batch
    batch.forEach(bt => completed.add(bt.task_id));
  }

  const allAgents = taskAgents.map(ta => ta.agents[0]).filter(a => a !== 'l2-specialist');
  return {
    primary_agents: [...new Set(allAgents)],
    secondary_agents: [],
    total_batches: batches.length,
    batches
  };
}
```

**Include batch visualization in executive summary:**

```markdown
## Agent Mapping

| Phase | Primary Agents | Batches | Tasks |
|-------|---------------|---------|-------|
| Phase 1 | frontend-react-specialist | 2 | 4 |
| Phase 2 | backend-fastapi-specialist | 3 | 6 |
| Phase 3 | test-playwright-specialist | 1 | 2 |

### Phase 1 Batches
- **Batch 1** (parallel): 1.1 [frontend], 1.3 [backend]
- **Batch 2** (parallel): 1.2 [frontend], 1.4 [state]
```

**If no agent registry exists**, skip agent_mapping (backwards compatible — `agent_mapping` will be absent from PROGRESS.json).

### Step 4: Create Plan Artifacts

Create `.claude/phase-plans/{slug}/PROGRESS.json` with parent context:

```json
{
  "plan_id": "{slug}",
  "project": {
    "name": "{project-name}",
    "slug": "{slug}",
    "created": "{timestamp}",
    "lastUpdated": "{timestamp}"
  },
  "scale": "S | M | L",
  "target_success": 0.95,

  // NEW: Parent context
  "parent_context": {
    "type": "roadmap | epic | null",
    "slug": "{parent-slug}",
    "title": "{parent-title}",
    "path": "{parent-path}"
  },

  // Commercial compliance (inherited from parent roadmap if applicable)
  "compliance_config": {
    "inherited_from": "roadmap | project | null",
    "parent_compliance_path": ".claude/roadmaps/{parent-slug}/ROADMAP.json",
    "multi_tenancy": {
      "enabled": true,
      "strategy": "subdomain"
    },
    "rbac": {
      "enabled": true,
      "roles": ["user", "admin", "super_admin"]
    },
    "self_audit_required": true,
    "self_audit_status": "pending",
    "self_audit_checklist": {
      "routes_defined": false,
      "multi_tenancy_enforced": false,
      "rbac_applied": false,
      "apis_only_data_access": false,
      "ui_maps_to_routes": false,
      "no_proprietary_ip": false,
      "deps_license_safe": false
    }
  },

  "phases": [
    {
      "id": 1,
      "name": "{phase-name}",
      "status": "pending",
      "tasks": [
        {
          "id": "1.1",
          "description": "{task-description}",
          "completed": false
        }
      ],
      "success_criteria": ["{criterion}"],

      // NEW: Agent mapping (computed in Step 3.5, optional)
      "agent_mapping": {
        "primary_agents": ["frontend-react-specialist"],
        "secondary_agents": [],
        "total_batches": 2,
        "batches": [
          {
            "batch": 1,
            "parallel_tasks": [
              {"task_id": "1.1", "agents": ["frontend-react-specialist"]}
            ]
          }
        ]
      }
    }
  ]
}
```

**Parent context examples:**

**If --parent-roadmap provided:**
```json
"parent_context": {
  "type": "roadmap",
  "slug": "auth-system",
  "title": "Authentication System",
  "path": ".claude/roadmaps/auth-system/ROADMAP.json"
}
```

**If --parent-epic provided:**
```json
"parent_context": {
  "type": "epic",
  "slug": "platform-v2",
  "title": "Platform V2 Migration",
  "path": ".claude/epics/platform-v2/EPIC.json"
}
```

**If standalone (no parent):**
```json
"parent_context": null
```

Create `EXECUTIVE_SUMMARY.md`:
```markdown
# {Project Name} - Executive Summary

**Status:** Planning / Active / Completed
**Scale:** {S/M/L}
**Target Success:** 95%

{{#if parent_context}}
**Parent:** {parent_context.type} - [{parent_context.title}]({parent_context.path})
{{/if}}

## Overview
{Brief description of the plan}

## Phases
{List of phases with objectives}

## Success Criteria
{List of acceptance criteria}
```

### Step 5: Create GitHub Issue (MANDATORY - Use issue-hierarchy-manager.js)

**IMPORTANT:** Use the GitHub Issue Hierarchy Manager to ensure all parent issues exist.

```javascript
import { ensureHierarchyIssues } from './src/github/issue-hierarchy-manager.js';

// After creating PROGRESS.json, ensure GitHub issues exist
const result = await ensureHierarchyIssues(projectRoot, 'plan', planSlug);

if (result.success) {
  console.log(`✅ GitHub issues created/verified`);

  if (result.created.length > 0) {
    console.log(`Auto-created parent issues: ${result.created.join(', ')}`);
  }

  if (result.plan) {
    console.log(`Plan Issue: #${result.plan.issueNumber}`);
  }

  if (result.roadmap) {
    console.log(`Parent Roadmap Issue: #${result.roadmap.issueNumber} ${result.roadmap.created ? '(auto-created)' : '(existing)'}`);
  }

  if (result.epic) {
    console.log(`Parent Epic Issue: #${result.epic.issueNumber} ${result.epic.created ? '(auto-created)' : '(existing)'}`);
  }
} else {
  console.warn(`⚠️ GitHub issue creation failed: ${result.error}`);
}
```

**What this does:**

1. **Ensures Plan Issue Exists (Standalone or Hierarchical)**
   - Title: `{project_name}` (from PROGRESS.json)
   - Body: CCASP-META header + breadcrumb + phase list
   - Labels: `phase-dev-plan`
   - Stores issue number in `PROGRESS.json` → `github_issue`
   - **Works with `parent_context: null`** for standalone plans

2. **Auto-Creates Parent Roadmap Issue (if missing and parent exists)**
   - If plan has `parent_context.type === 'roadmap'`
   - Checks if roadmap issue exists
   - If not, creates roadmap issue with proper CCASP-META
   - Updates ROADMAP.json with issue number
   - **Skipped for standalone plans** (`parent_context: null`)

3. **Auto-Creates Parent Epic Issue (if missing and parent exists)**
   - If roadmap has `parent_epic` reference
   - Checks if epic issue exists
   - If not, creates epic issue with proper CCASP-META
   - Updates EPIC.json with issue number
   - **Skipped for standalone plans** (`parent_context: null`)

4. **Adds Breadcrumb Navigation (if parents exist)**
   - Links parent epic and roadmap in plan issue body
   - Format: `**Hierarchy:** [Epic #123](url) > [Roadmap #456](url) > This Plan`
   - **Standalone plans**: No breadcrumb, just plan issue

**CCASP-META format (handled by issue-hierarchy-manager.js):**
```html
<!-- CCASP-META
source: /phase-dev-plan
slug: {slug}
issue_type: feature
progress_file: .claude/phase-plans/{slug}/PROGRESS.json
parent_type: roadmap
parent_slug: {parent-slug}
created_at: {timestamp}
-->
```

**Generated Files section (auto-included):**
| File | Type | Path |
|------|------|------|
| Progress Tracking | JSON | .claude/phase-plans/{slug}/PROGRESS.json |
| Executive Summary | MD | .claude/phase-plans/{slug}/EXECUTIVE_SUMMARY.md |
| Exploration Summary | MD | .claude/exploration/{slug}/EXPLORATION_SUMMARY.md |
| Code Snippets | MD | .claude/exploration/{slug}/CODE_SNIPPETS.md |
| Reference Files | MD | .claude/exploration/{slug}/REFERENCE_FILES.md |
| Agent Delegation | MD | .claude/exploration/{slug}/AGENT_DELEGATION.md |
| Phase Breakdown | MD | .claude/exploration/{slug}/PHASE_BREAKDOWN.md |
| Findings | JSON | .claude/exploration/{slug}/findings.json |

### Step 6: Generate Executable Commands

Create `.claude/commands/{slug}-executor.md` and `.claude/commands/{slug}.md`

### Step 7: Report Completion to Parent (When All Phases Complete)

**COMPLIANCE GATE (If compliance_config active):**

Before reporting completion to parent, run the self-audit checklist:

1. All routes in this plan's scope defined and documented in ROUTES.md?
2. Multi-tenancy enforced at data layer (tenant ID on all queries)?
3. RBAC applied to all routes, APIs, and data access in this plan?
4. APIs are the ONLY data access layer (no direct DB from frontend)?
5. UI components map to defined routes (no orphan components)?
6. No proprietary inspiration crossed into expression (IP safe)?
7. All new dependencies are license-safe (no GPL/AGPL/SSPL)?

**If ALL checks pass:**
- Set `compliance_config.self_audit_status = "passed"`
- Update all checklist items to `true`
- Proceed with completion reporting

**If ANY check fails:**
- Set `compliance_config.self_audit_status = "failed"`
- Display which checks failed
- Ask user to resolve before marking complete
- **DO NOT report completion to parent until self-audit passes**

**IMPORTANT:** When all phases in PROGRESS.json are completed, report back to parent.

**Use src/phase-dev/completion-reporter.js:**

```javascript
import { reportPhaseDevComplete, calculateCompletionMetrics } from 'src/phase-dev/completion-reporter.js';

// Calculate metrics
const metrics = calculateCompletionMetrics(progress);

// Report to parent (if exists)
const result = await reportPhaseDevComplete(
  projectRoot,
  slug,
  metrics
);

if (result.success) {
  console.log(`✅ Reported PHASE_DEV_COMPLETE to ${result.mode}`);
  if (result.roadmap_completion) {
    console.log(`Roadmap completion: ${result.roadmap_completion}%`);
  }
  if (result.epic_completion) {
    console.log(`Epic completion: ${result.epic_completion}%`);
  }
}
```

**What happens:**
1. If parent_context.type === 'roadmap':
   - Updates the plan reference in ROADMAP.json
   - Marks status as 'completed'
   - Recalculates overall roadmap completion
   - If roadmap complete, reports to epic (if exists)

2. If parent_context.type === 'epic':
   - Finds parent roadmap under epic
   - Updates phase status in roadmap
   - Updates roadmap completion in epic
   - Recalculates epic completion

3. If parent_context === null:
   - Standalone mode, just marks PROGRESS.json as complete

### Step 8: Display Summary

```
╔═══════════════════════════════════════════════════════════════╗
║  ✓ Phase-Dev-Plan Created Successfully!                       ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Plan: {project-name}                                         ║
║  Slug: {slug}                                                 ║
║  Scale: {S/M/L}                                               ║
{{#if parent_context}}
║  Parent: {parent_context.type} - {parent_context.title}       ║
{{/if}}
║                                                               ║
║  Location: .claude/phase-plans/{slug}/                        ║
║  Progress: .claude/phase-plans/{slug}/PROGRESS.json           ║
║                                                               ║
{{#if github_issue}}
║  GitHub Issue: #{github_issue}                                ║
{{/if}}
║                                                               ║
║  Next Steps:                                                  ║
║  1. Review exploration files in .claude/exploration/{slug}/   ║
║  2. Start execution: /{slug}-executor                         ║
║  3. Track progress: /{slug}                                   ║
{{#if parent_context}}
║  4. When complete, will report to parent {parent_context.type}║
{{/if}}
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

## Enforcement Rules (Epic-Hierarchy Architecture)

| Rule | Mandatory |
|------|-----------|
| L2 Exploration FIRST | ✅ YES |
| All 6 exploration files created | ✅ YES |
| PROGRESS.json after exploration | ✅ YES |
| GitHub issue created with CCASP-META | ✅ YES |
| Issue number stored in PROGRESS.json | ✅ YES |
| Parent context stored if provided | ✅ YES |
| Report completion to parent | ✅ YES |
| Use completion-reporter.js | ✅ YES |

### ⛔ FAILURE CONDITIONS - DO NOT PROCEED IF:
- Exploration files missing (any of the 6)
- PROGRESS.json created before exploration
- Parent flag provided but parent file doesn't exist
- parent_context not stored in PROGRESS.json
- Completion not reported to parent when done

### Validation Checklist (Run Before Completion)
```
[ ] .claude/exploration/{slug}/ has all 6 exploration files
[ ] .claude/phase-plans/{slug}/PROGRESS.json exists
[ ] .claude/phase-plans/{slug}/EXECUTIVE_SUMMARY.md exists
[ ] .claude/commands/{slug}-executor.md exists
[ ] .claude/commands/{slug}.md exists
[ ] GitHub issue created with CCASP-META header
[ ] If --parent-roadmap or --parent-epic used, parent_context stored
[ ] If --parent-roadmap used, parent ROADMAP.json exists
[ ] If --parent-epic used, parent EPIC.json exists
[ ] Completion reporter configured to report when done
```

## Argument Handling

If invoked with arguments:

- `/phase-dev-plan` - Interactive mode
- `/phase-dev-plan {description}` - Quick start with description
- `/phase-dev-plan --parent-roadmap {path}` - Create as child of roadmap
- `/phase-dev-plan --parent-epic {slug}` - Create as child of epic
- `/phase-dev-plan --slug {slug} --title "{title}" --description "{desc}"` - Full specification

**Example with parent context:**
```
/phase-dev-plan --parent-roadmap .claude/roadmaps/auth-system/ROADMAP.json --slug auth-backend --title "Authentication Backend" --description "Implement backend API and database for authentication"
```

---

*Phase-Dev-Plan Generator - Part of CCASP Roadmap Orchestration Framework*
