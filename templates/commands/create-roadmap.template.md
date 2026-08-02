---
description: Create multi-phase development roadmaps with GitHub integration and agent delegation
type: project
complexity: high
allowed-tools: Read, Write, Edit, Task, Bash, Grep, Glob
category: development
---

# Create Roadmap - Roadmap Orchestration Framework

You are a roadmap planning specialist using the CCASP Roadmap Orchestration Framework. Transform project ideas into executable multi-phase development plans with GitHub integration, agent delegation, and automated phase-dev-plan generation.

**NEW EPIC-HIERARCHY ARCHITECTURE:**
- Roadmap coordinates MULTIPLE phase-dev-plans (not phases directly)
- Each phase-dev-plan has its own PROGRESS.json
- Roadmap tracks plan completion via references in phase_dev_plan_refs[]
- Analyze scope to determine HOW MANY phase-dev-plans are needed
- Support for parent epic context via --parent-epic flag

---

## 🚨 MANDATORY FILE CREATION - DO NOT SKIP

**CRITICAL:** Every roadmap MUST create ALL of these files. Skipping ANY file is a failure.

### Exploration Documentation (REQUIRED FIRST)
Before creating ROADMAP.json, you MUST create these 6 files in `.claude/roadmaps/{slug}/exploration/`:

| File | Purpose | Required |
|------|---------|----------|
| `EXPLORATION_SUMMARY.md` | Overview + statistics | ✅ YES |
| `CODE_SNIPPETS.md` | Extracted code examples | ✅ YES |
| `REFERENCE_FILES.md` | File paths + line numbers | ✅ YES |
| `AGENT_DELEGATION.md` | Agent assignments per task | ✅ YES |
| `PHASE_BREAKDOWN.md` | Full phase/task detail | ✅ YES |
| `findings.json` | Machine-readable data | ✅ YES |

### Roadmap Files (AFTER Exploration) - NEW CONSOLIDATED STRUCTURE
| File | Purpose | Required |
|------|---------|----------|
| `.claude/roadmaps/{slug}/ROADMAP.json` | Main roadmap definition | ✅ YES |
| `.claude/roadmaps/{slug}/phase-*.json` | Per-phase plans (same dir) | ✅ YES |
| `.claude/roadmaps/{slug}/exploration/` | Exploration docs (same dir) | ✅ YES |
| `.claude/commands/roadmap-{slug}.md` | Dynamic execution command | ✅ YES |

### ⛔ STOP - Validation Checkpoint
Before proceeding past Step 3, verify ALL exploration files exist:
```bash
ls -la .claude/roadmaps/{slug}/exploration/
# Must show: EXPLORATION_SUMMARY.md, CODE_SNIPPETS.md, REFERENCE_FILES.md,
#            AGENT_DELEGATION.md, PHASE_BREAKDOWN.md, findings.json
```

---

## When to Create a Roadmap

Create a roadmap instead of a single phase plan when:
- **30+ tasks** are identified
- **3+ domains** are involved (frontend, backend, database, testing, deployment)
- **Multiple features** that could conflict or have dependencies
- **Long duration** (> 2 weeks estimated)
- User explicitly requests roadmap organization

**Small Scope Recommendation**: If < 5 issues and complexity is low, recommend `/create-phase-dev` instead.

## Three Creation Modes

### Mode A: Manual Builder
User describes what they want to build in natural language. Claude analyzes and structures into phases.

### Mode B: GitHub Import
Import existing GitHub issues, display in table format, user selects which to include, then structure into phases.

### Mode C: Multi-Project Builder (Recommended for Complex Refactors)
For complex scopes that span multiple domains or require extensive codebase analysis. Features:
- L2 agent exploration for deep code analysis
- Creates exploration documentation BEFORE roadmap
- Better for refactoring, large features, or platform migrations

## Execution Protocol

### Step 1: Choose Mode

Ask user which mode to use (use AskUserQuestion):
- **A) Manual Builder** - Describe what you want to build
- **B) From GitHub Issues** - Import and organize existing issues
- **C) Multi-Project Builder** - Complex scope with L2 exploration (Recommended for refactors)

### Step 2A (Manual): Gather Requirements

Use AskUserQuestion to collect:

1. **Roadmap Name**: What should this roadmap be called?
2. **Primary Goal**: What is the main objective? (1-2 sentences)
3. **Scope**: What features/changes are included? (open editor for detailed input)
4. **Timeline**: Target completion (optional)

### Step 2B (GitHub): Fetch and Display Issues

1. Fetch open issues from repository
2. Display in numbered table format:

```
┌────┬──────────┬────────────────────────────────┬────────────┬─────────┐
│ #  │ Issue ID │ Title                          │ Status     │ Include │
├────┼──────────┼────────────────────────────────┼────────────┼─────────┤
│ 1  │ #45      │ Add user authentication        │ Open       │ [ ]     │
│ 2  │ #46      │ Implement JWT tokens           │ Open       │ [ ]     │
└────┴──────────┴────────────────────────────────┴────────────┴─────────┘
```

3. User selects rows: "Create roadmap from rows: 2,4,5-7" or "all"
4. Optionally normalize issues (add structured metadata, additive only)

### Step 2: Analyze and Decompose

Analyze the scope to identify natural phase boundaries:

**Domain Analysis:**
- Frontend components and pages
- Backend APIs and services
- Database migrations and schemas
- Testing requirements (unit, e2e)
- Deployment and infrastructure
- Documentation needs

**Dependency Analysis:**
- Which features depend on others?
- What must be built first?
- Are there parallel tracks possible?

### Step 2.5: Configure Testing Integration (NEW - If Playwright Configured)

**IMPORTANT:** Before creating phases, check if E2E testing is configured and ask the user about testing strategy.

**Check tech-stack.json for testing configuration:**
```javascript
// Read testing config from tech-stack.json
const testing = techStack.testing || {};
const e2eFramework = testing.e2e?.framework;
const playwrightConfigured = e2eFramework === 'playwright';
```

**If Playwright is configured**, display testing status and ask questions:

```
╔═══════════════════════════════════════════════════════════════╗
║  🧪 Testing Configuration Detected                             ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  E2E Framework: Playwright                                    ║
║  Test Environment: {{testing.environment.defaultMode}}        ║
║  Ralph Loop: {{testing.ralphLoop.enabled ? "Enabled" : "Disabled"}}
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

**Ask user about testing approach for this roadmap:**

```
header: "Testing Strategy"
question: "How should E2E tests be included in this roadmap?"
options:
  - label: "Per-phase testing (Recommended)"
    description: "Add E2E verification task at the end of each phase"
  - label: "Final testing only"
    description: "Single E2E test phase at the end of roadmap"
  - label: "No E2E testing"
    description: "Skip automated E2E tests in this roadmap"
```

**Ask about testing environment:**

```
header: "Test Environment"
question: "Where should E2E tests run during this roadmap?"
options:
  - label: "Localhost (Recommended for dev)"
    description: "Test against local dev server with tunnel"
  - label: "Production"
    description: "Test against deployed app after each deploy"
  - label: "Ask each time"
    description: "Prompt for environment before each test run"
```

**Ask about Ralph Loop:**

```
header: "Ralph Loop"
question: "Enable Ralph Loop for automated test-fix cycles?"
options:
  - label: "Yes - auto-fix failing tests (Recommended)"
    description: "Automatically retry fixes until tests pass"
  - label: "No - manual testing only"
    description: "Run tests but don't auto-retry on failure"
```

**Store testing configuration for roadmap:**

```json
{
  "testing_strategy": {
    "mode": "per-phase",  // "per-phase" | "final-only" | "none"
    "environment": "localhost",  // "localhost" | "production" | "ask"
    "ralph_loop": {
      "enabled": true,
      "maxIterations": 10
    },
    "e2e_framework": "playwright"
  }
}
```

**If testing NOT configured**, show setup reminder:

```
╔═══════════════════════════════════════════════════════════════╗
║  ℹ️  E2E Testing Not Configured                                ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Automated E2E testing is not set up for this project.        ║
║                                                               ║
║  To enable:                                                   ║
║    /project-impl → Step 7 (Configure Testing)                 ║
║  Or:                                                          ║
║    /menu → Settings → Testing Configuration                   ║
║                                                               ║
║  Continuing without automated E2E testing...                  ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

### Step 2.5b: Configure Compliance Strategy (If Commercial Mode Detected)

**IMPORTANT:** Before creating phases, check if commercial compliance is configured and collect compliance strategy for this roadmap.

**Check tech-stack.json for compliance configuration:**
```javascript
// Read compliance config from tech-stack.json
const compliance = techStack.compliance || {};
const isCommercial = compliance.mode === 'commercial-saas';
```

**If commercial mode is active**, display compliance status and ask questions:

```
╔═══════════════════════════════════════════════════════════════╗
║  Commercial SaaS Compliance Detected                         ║
╠═══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Mode: Commercial SaaS                                       ║
║  Multi-Tenancy: Required                                     ║
║  RBAC: Required                                              ║
║  API Contracts: Required                                     ║
║  Route Maps: Required                                        ║
║                                                              ║
╚═══════════════════════════════════════════════════════════════╝
```

**Ask about multi-tenancy strategy:**

```
header: "Tenancy"
question: "How should tenant isolation work in this roadmap?"
options:
  - label: "Subdomain-based (Recommended for B2B SaaS)"
    description: "tenant.app.com — each tenant gets a subdomain"
  - label: "Header/token-based"
    description: "X-Tenant-ID header — API-first isolation"
  - label: "Path-based"
    description: "/tenant-slug/... — simpler deployment"
```

**Ask about user personas:**

```
header: "Personas"
question: "Which user personas apply to this roadmap?"
options:
  - label: "Standard SaaS (Recommended)"
    description: "User + Admin + Super Admin (3 roles)"
  - label: "Custom roles"
    description: "I'll define custom role names"
```

**If custom roles selected, ask:**

```
header: "Roles"
question: "Enter your custom role names (comma-separated)"
```

**Ask about compliance blocking:**

```
header: "Enforcement"
question: "Should compliance planning block phase execution?"
options:
  - label: "Yes - require docs before coding (Recommended)"
    description: "ROUTES.md + RBAC.md must exist before plans can start"
  - label: "No - docs can be created alongside coding"
    description: "Compliance docs are advisory, not blocking"
```

**Store compliance strategy for this roadmap:**

```json
{
  "compliance": {
    "enabled": true,
    "mode": "commercial-saas",
    "status": "planning",
    "blocking": true,
    "multi_tenancy": {
      "enabled": true,
      "strategy": "subdomain"
    },
    "rbac": {
      "enabled": true,
      "roles": ["user", "admin", "super_admin"]
    },
    "documentation": {
      "design_origin": "not_started",
      "routes_md": "not_started",
      "api_contract": "not_started",
      "rbac_md": "not_started"
    },
    "audit": {
      "last_audit_date": null,
      "score": null,
      "verdict": null,
      "audit_file": null
    },
    "ip_compliance": {
      "competitors_analyzed": [],
      "policy_version": "1.0"
    }
  }
}
```

### Step 2.5c: Check Build Tier Configuration (If Competitor Research Active)

**Check tech-stack.json for build tier configuration:**
```javascript
// Read build tier config from tech-stack.json
const buildTier = techStack.buildTier || {};
const tier = buildTier.tier; // "b2c_mvp" or "enterprise_b2b" or undefined
const phaseOrdering = buildTier.roadmap_phase_ordering || [];
```

**If build tier is configured**, display and apply tier-specific roadmap structure:

```
╔═══════════════════════════════════════════════════════════════╗
║  Build Tier Detected                                         ║
╠═══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Tier: {B2C MVP / Enterprise B2B}                            ║
║  Roadmap structure follows tier-specific phase ordering.     ║
║                                                              ║
║  B2C MVP (6 weeks target):                                   ║
║    Foundation → Auth → Core → Payments → Growth → Polish     ║
║                                                              ║
║  Enterprise B2B (10 weeks target):                           ║
║    Billing → Tenancy → Admin → Core → API → Compliance       ║
║                                                              ║
╚═══════════════════════════════════════════════════════════════╝
```

**Use `buildTier.roadmap_phase_ordering`** as the basis for ROADMAP.json phase structure. Each entry in the ordering array becomes a phase in the roadmap. Stubbed features (from B2C MVP tier) should generate `CCASP:STUB` placeholder phases that can be enabled later.

**If build tier NOT configured**, use default phase ordering based on feature complexity and dependencies.

---

**If compliance NOT configured**, show setup reminder:

```
╔═══════════════════════════════════════════════════════════════╗
║  Commercial Compliance Not Configured                        ║
╠═══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Commercial SaaS compliance is not set up for this project.  ║
║                                                              ║
║  To enable:                                                  ║
║    /project-impl → Step 1.5 (Commercial Mode Detection)      ║
║                                                              ║
║  Continuing without commercial compliance...                 ║
║                                                              ║
╚═══════════════════════════════════════════════════════════════╝
```

---

### Step 2.6: L2 Exploration Phase (MANDATORY - DO NOT SKIP)

**CRITICAL:** You MUST run L2 exploration BEFORE creating ROADMAP.json. This step is NOT optional.

**For each project/phase identified:**

1. **Deploy L2 Explore Agent** - Use Task tool with `subagent_type: "Explore"` and thoroughness "very thorough":
   ```
   Prompt: "Analyze the codebase for {scope description}. Find:
   1. All files that need modification (with line numbers)
   2. Related/dependency files for reference
   3. Existing code patterns to follow
   4. Test files that need updates

   Output format:
   - Files to MODIFY: path:line_number - reason
   - Files to REFERENCE: path - dependency type
   - Code patterns: snippet descriptions
   - Test files: path - coverage area"
   ```

2. **Create Exploration Directory:**
   ```bash
   mkdir -p .claude/roadmaps/{slug}/exploration
   ```

3. **Write ALL 6 Exploration Files** (use Write tool for each):

   **File 1: EXPLORATION_SUMMARY.md**
   ```markdown
   # Exploration Summary: {project_name}

   **Generated:** {timestamp}
   **Status:** complete
   **Confidence:** {high|medium|low}

   ## Overview
   {Brief description of what was found}

   ## Key Statistics
   - Files analyzed: {count}
   - Code snippets extracted: {count}
   - Phases identified: {count}
   - Tasks generated: {count}
   - Recommended agents: {list}

   ## Domain Distribution
   - frontend: {count} items
   - backend: {count} items
   - database: {count} items
   - testing: {count} items
   ```

   **File 2: CODE_SNIPPETS.md**
   ```markdown
   # Code Snippets: {slug}

   ## Snippet 1: {description}
   **File:** `{path}`
   **Lines:** {start}-{end}
   **Relevance:** {why this pattern matters}

   ```{language}
   {actual code from the file}
   ```

   ## Snippet 2: ...
   ```

   **File 3: REFERENCE_FILES.md**
   ```markdown
   # Reference Files: {slug}

   ## Files to MODIFY (Primary)
   | File | Reason | Complexity |
   |------|--------|------------|
   | `{path}` | {reason} | S/M/L |

   ## Files to REFERENCE (Dependencies)
   | File | Reason |
   |------|--------|
   | `{path}` | {dependency type} |

   ## Test Files to UPDATE
   | File | Coverage Area |
   |------|---------------|
   | `{path}` | {what it tests} |
   ```

   **File 4: AGENT_DELEGATION.md**
   ```markdown
   # Agent Delegation: {slug}

   ## Recommended Primary Agent
   **{agent_name}** - {reason for selection}

   ## Task-Agent Assignments
   | Phase | Task | Recommended Agent | Reason |
   |-------|------|-------------------|--------|
   | 1 | {task} | frontend-specialist | UI work |
   | 1 | {task} | backend-specialist | API work |

   ## Execution Sequence
   1. **{agent}** - {scope}
   2. **{agent}** - {scope}

   ## Agent Capabilities Reference
   | Agent | Domains | Tools |
   |-------|---------|-------|
   | frontend-specialist | UI, Components | Read, Write, Edit, Glob |
   | backend-specialist | API, Database | Read, Write, Edit, Bash |
   | testing-specialist | Unit, E2E | Read, Write, Bash |
   | deployment-specialist | CI/CD, Docker | Read, Bash |
   ```

   **File 5: PHASE_BREAKDOWN.md**
   ```markdown
   # Phase Breakdown: {slug}

   ## Phase 1: {name}
   **Objective:** {description}
   **Complexity:** S/M/L
   **Assigned Agent:** {agent}
   **Dependencies:** {list or None}

   ### Tasks

   #### Task 1.1: {title}
   - **Description:** {details}
   - **Files:**
     - Modify: `{path}` - {reason}
     - Reference: `{path}` - {reason}
   - **Acceptance Criteria:**
     - [ ] {criterion 1}
     - [ ] {criterion 2}
   - **Assigned Agent:** {agent}

   ### Phase 1 Validation
   - [ ] All tasks complete
   - [ ] Tests pass

   ---

   ## Phase 2: {name}
   ...
   ```

   **File 6: findings.json**
   ```json
   {
     "metadata": {
       "slug": "{slug}",
       "generatedAt": "{timestamp}",
       "version": "1.0",
       "generator": "ccasp-l2-exploration"
     },
     "summary": {
       "filesAnalyzed": 0,
       "snippetsExtracted": 0,
       "phasesIdentified": 0,
       "tasksGenerated": 0
     },
     "files": {
       "modify": [],
       "reference": [],
       "tests": []
     },
     "snippets": [],
     "phases": [],
     "delegation": {
       "primaryAgent": "",
       "taskAssignments": [],
       "executionSequence": []
     }
   }
   ```

4. **Verification Checkpoint** - STOP and verify ALL 6 files exist before continuing:
   ```
   ✓ .claude/roadmaps/{slug}/exploration/EXPLORATION_SUMMARY.md
   ✓ .claude/roadmaps/{slug}/exploration/CODE_SNIPPETS.md
   ✓ .claude/roadmaps/{slug}/exploration/REFERENCE_FILES.md
   ✓ .claude/roadmaps/{slug}/exploration/AGENT_DELEGATION.md
   ✓ .claude/roadmaps/{slug}/exploration/PHASE_BREAKDOWN.md
   ✓ .claude/roadmaps/{slug}/exploration/findings.json
   ```

**⛔ DO NOT proceed to Step 3 until ALL 6 exploration files are created.**

---

### Step 3: Create Phase Structure

For each phase, define:
- **Phase Name**: Clear, descriptive name
- **Objective**: What this phase accomplishes
- **Tasks**: 5-15 tasks per phase
- **Dependencies**: Which phases must complete first
- **Estimated Effort**: S/M/L
- **Domain**: Primary domain (frontend/backend/etc)

**Typical Phase Patterns:**

**Foundation Pattern** (for new features):
1. Foundation - Core setup, schemas, base components
2. API Layer - Backend endpoints, services
3. UI Layer - Frontend components, pages
4. Integration - Wire together, add features
5. Polish - Testing, docs, optimization

**Migration Pattern** (for refactoring):
1. Analysis - Document current state, plan changes
2. Preparation - Create safety nets, golden masters
3. Core Migration - Execute main changes
4. Validation - Testing, verification
5. Cleanup - Remove old code, update docs

**Feature Pattern** (for adding capabilities):
1. Design - Architecture, API contracts
2. Backend - Services, endpoints
3. Frontend - UI components
4. Testing - E2E, integration tests
5. Deploy - Release, monitoring

### Step 3.5: Generate Agent Mapping Per Phase

**After defining phase structure, compute agent mapping for each phase.**

For each phase in the roadmap:

1. **Read agent registry** from `.claude/config/agents.json` (if available)
2. **Match tasks to agents** by analyzing task keywords/type against agent triggers:

```javascript
// Agent matching algorithm
function computeAgentMapping(phase, agentRegistry) {
  if (!agentRegistry?.specialists?.length) return null;

  const taskAgents = phase.tasks.map(task => {
    const matched = agentRegistry.specialists.find(agent =>
      agent.triggers?.some(trigger =>
        task.description.toLowerCase().includes(trigger.toLowerCase()) ||
        task.domain === agent.domain
      )
    );
    return {
      task_id: task.id,
      agents: matched ? [matched.subagent_type] : ['l2-specialist']
    };
  });

  // Build dependency graph and group into batches
  const batches = buildDependencyBatches(phase.tasks, taskAgents);

  return {
    primary_agents: [...new Set(taskAgents.filter(ta => ta.agents[0] !== 'l2-specialist').map(ta => ta.agents[0]))],
    secondary_agents: [],
    total_batches: batches.length,
    batches: batches
  };
}

// Topological sort → group into dependency-ordered batches
function buildDependencyBatches(tasks, taskAgents) {
  const completed = new Set();
  const batches = [];

  while (completed.size < tasks.length) {
    const batch = [];
    for (const task of tasks) {
      if (completed.has(task.id)) continue;
      const deps = task.depends_on || task.blockedBy || [];
      if (deps.every(dep => completed.has(dep))) {
        const agentInfo = taskAgents.find(ta => ta.task_id === task.id);
        batch.push({
          task_id: task.id,
          agents: agentInfo?.agents || ['l2-specialist']
        });
      }
    }
    if (batch.length === 0) break; // circular dependency guard
    batch.forEach(bt => completed.add(bt.task_id));
    batches.push({
      batch: batches.length + 1,
      parallel_tasks: batch
    });
  }
  return batches;
}
```

3. **Write `agent_mapping` into each phase** of the plan reference data
4. **Generate `roadmapAgentMapping`** at the roadmap level:

```json
{
  "roadmapAgentMapping": {
    "auth-backend": {
      "primary": ["backend-fastapi-specialist"],
      "secondary": ["test-playwright-specialist"],
      "description": "Backend requires API + DB work"
    },
    "auth-frontend": {
      "primary": ["frontend-react-specialist"],
      "secondary": ["state-zustand-specialist"],
      "description": "Frontend UI components and state management"
    }
  }
}
```

**If no agent registry exists**, skip this step (backwards compatible).

---

### Step 3: Apply Intelligence Layer

Analyze selected scope/issues using the intelligence layer:

```javascript
// Group related items by domain (frontend, backend, database, testing, deployment)
// Detect dependencies from text ("depends on", "after", "requires")
// Analyze file overlap to infer ordering
// Estimate complexity (S/M/L) based on scope
// Identify parallel work opportunities
// Check if scope is too small for roadmap
```

**Complexity Estimation:**
- **S (Small)**: < 10 tasks, single domain, 2-4 hours
- **M (Medium)**: 10-30 tasks, 2-3 domains, 8-16 hours
- **L (Large)**: 30+ tasks, 3+ domains, 24-40 hours

### Step 4: Analyze Scope & Determine Phase-Dev-Plans

**CRITICAL:** Analyze the scope to determine HOW MANY phase-dev-plans are needed.

**Ask yourself:**
- How many distinct domains/areas does this cover? (frontend, backend, database, testing, deployment)
- Are there natural breakpoints where work can be parallelized?
- What is the logical grouping of tasks into independently-executable plans?

**Common patterns:**
- **Single-domain feature**: 1 phase-dev-plan (e.g., "Add user profile page")
- **Full-stack feature**: 2-3 phase-dev-plans (e.g., /auth-backend, /auth-frontend, /auth-testing)
- **Complex refactor**: 3-5 phase-dev-plans (e.g., /dashboard-ui, /dashboard-api, /dashboard-data, /dashboard-tests, /dashboard-docs)
- **Platform migration**: 4-6 phase-dev-plans (e.g., /migration-prep, /migration-backend, /migration-frontend, /migration-validation, /migration-cleanup)

**Determine plan slugs:**
```
Example: "Add authentication system"
Plan slugs:
  - auth-backend (API + database)
  - auth-frontend (UI components)
  - auth-testing (E2E tests)
```

### Step 5: Generate ROADMAP.json (NEW ARCHITECTURE)

Create the roadmap file at `.claude/roadmaps/{slug}/ROADMAP.json`:

```json
{
  "roadmap_id": "{{uuid}}",
  "slug": "{{slug}}",
  "title": "{{title}}",
  "description": "{{description}}",
  "created": "{{timestamp}}",
  "updated": "{{timestamp}}",
  "source": "manual | github-issues | github-project",
  "status": "planning | active | paused | completed",

  // NEW: Parent epic reference (if --parent-epic flag used)
  "parent_epic": {
    "epic_id": "{{parent-epic-id}}",
    "epic_slug": "{{parent-epic-slug}}",
    "epic_path": ".claude/epics/{{parent-epic-slug}}/EPIC.json"
  },

  // NEW: Phase-dev-plan references (replaces direct phase tracking)
  "phase_dev_plan_refs": [
    {
      "slug": "auth-backend",
      "path": ".claude/phase-plans/auth-backend/PROGRESS.json",
      "title": "Authentication Backend",
      "status": "pending",
      "completion_percentage": 0,
      "created": "{{timestamp}}",
      "updated": "{{timestamp}}"
    },
    {
      "slug": "auth-frontend",
      "path": ".claude/phase-plans/auth-frontend/PROGRESS.json",
      "title": "Authentication Frontend",
      "status": "pending",
      "completion_percentage": 0,
      "created": "{{timestamp}}",
      "updated": "{{timestamp}}"
    }
  ],

  // Cross-plan dependencies (e.g., frontend depends on backend)
  "cross_plan_dependencies": [
    {
      "dependent_slug": "auth-frontend",
      "depends_on_slug": "auth-backend",
      "reason": "Frontend needs backend API endpoints to be ready"
    }
  ],

  // NEW: Agent mapping per plan (computed in Step 3.5)
  "roadmapAgentMapping": {
    "auth-backend": {
      "primary": ["backend-fastapi-specialist"],
      "secondary": ["test-playwright-specialist"],
      "description": "Backend requires API + DB work"
    },
    "auth-frontend": {
      "primary": ["frontend-react-specialist"],
      "secondary": ["state-zustand-specialist"],
      "description": "Frontend UI components and state management"
    }
  },

  // NEW: Commercial compliance (if configured in Step 2.5b)
  "compliance": null,  // Set to compliance strategy object if commercial mode active

  "metadata": {
    "plan_count": 2,
    "overall_completion_percentage": 0,
    "github_integrated": false,
    "github_epic_number": null,
    "last_github_sync": null
  }
}
```

**IMPORTANT:** Use the refactored schema functions:
```javascript
import { createRoadmap, addPlanReference, createPlanReference, addCrossPlanDependency, calculateOverallCompletion } from 'src/roadmap/schema.js';

// Create roadmap with parent epic context if provided
const roadmap = createRoadmap({
  title: "Authentication System",
  description: "Add authentication to the app",
  parent_epic: parentEpic ? {
    epic_id: parentEpic.epic_id,
    epic_slug: parentEpic.slug,
    epic_path: `.claude/epics/${parentEpic.slug}/EPIC.json`
  } : null,
  compliance: complianceStrategy || null  // From Step 2.5b
});

// Add plan references
const backendPlanRef = createPlanReference({
  slug: 'auth-backend',
  title: 'Authentication Backend',
  status: 'pending',
  completion_percentage: 0
});
addPlanReference(roadmap, backendPlanRef);

const frontendPlanRef = createPlanReference({
  slug: 'auth-frontend',
  title: 'Authentication Frontend',
  status: 'pending',
  completion_percentage: 0
});
addPlanReference(roadmap, frontendPlanRef);

// Add dependencies
addCrossPlanDependency(roadmap, 'auth-frontend', 'auth-backend', 'Frontend needs backend API endpoints');
```

### Step 6: Offer to Spawn Phase-Dev-Plans

**IMPORTANT:** After creating ROADMAP.json, offer to spawn /phase-dev-plan for each plan slug.

Display a menu:
```
╔═══════════════════════════════════════════════════════════════╗
║  Roadmap Created: {title}                                      ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Phase-Dev-Plans to Create:                                   ║
║  1. auth-backend - Authentication Backend                     ║
║  2. auth-frontend - Authentication Frontend                   ║
║  3. auth-testing - E2E Tests                                  ║
║                                                               ║
║  Would you like to:                                           ║
║  A) Spawn all phase-dev-plans now (Recommended)               ║
║  B) Spawn individual plans                                    ║
║  C) Skip for now (create plans manually later)                ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

**If user chooses A or B:**

For each plan, invoke:
```
/phase-dev-plan --parent-roadmap .claude/roadmaps/{roadmap-slug}/ROADMAP.json --slug {plan-slug} --title "{plan-title}" --description "{plan-description}"
```

**Pass parent context:**
- `--parent-roadmap` flag with path to ROADMAP.json
- Plan slug and title derived from analysis
- Description from exploration findings

**Track progress:**
- Each /phase-dev-plan will create `.claude/phase-plans/{plan-slug}/PROGRESS.json`
- PROGRESS.json includes parent_context pointing back to roadmap
- When plan completes, it reports back via src/phase-dev/completion-reporter.js

**If per-phase testing enabled**, add these tasks to end of each phase:
```json
{
  "id": "{{phase}}.E2E-1",
  "description": "Run E2E verification tests for this phase",
  "details": "Execute Playwright E2E tests against {{environment}}. Verify all changes from this phase work correctly. Use Ralph Loop if tests fail.",
  "completed": false,
  "testing": {
    "type": "e2e",
    "environment": "{{testing_strategy.environment}}",
    "framework": "playwright",
    "command": "npx playwright test"
  }
}
```

**Phase-Dev-Plan JSON structure:**

```json
{
  "plan_id": "{{roadmap-slug}}-phase-1",
  "phase_id": "phase-1",
  "roadmap_id": "{{roadmap-id}}",
  "project_name": "{{phase_title}}",
  "scale": "M",
  "target_success": 0.95,
  "agent_assignments": {
    "suggested": ["frontend-react-specialist"],
    "current": []
  },
  "phases": [{
    "id": 1,
    "name": "{{phase_title}}",
    "status": "pending",
    "tasks": [
      { "id": "1.1", "description": "Task 1", "completed": false },
      {
        "id": "1.E2E",
        "description": "Run E2E verification tests",
        "completed": false,
        "testing": {
          "type": "e2e",
          "environment": "localhost",
          "framework": "playwright"
        }
      }
    ],
    "success_criteria": ["deliverable 1", "E2E tests pass"]
  }],
  "testing_config": {
    "e2e": {
      "framework": "playwright",
      "environment": "{{testing_strategy.environment}}",
      "selectors": {
        "username": "{{testing.selectors.username}}",
        "password": "{{testing.selectors.password}}",
        "loginButton": "{{testing.selectors.loginButton}}",
        "loginSuccess": "{{testing.selectors.loginSuccess}}"
      }
    },
    "ralph_loop": {
      "enabled": "{{testing_strategy.ralph_loop.enabled}}",
      "maxIterations": "{{testing_strategy.ralph_loop.maxIterations}}",
      "testCommand": "npx playwright test"
    }
  }
}
```

### Step 5.5: Enable Agent Orchestration (Auto-enabled for Roadmaps)

Roadmaps automatically enable agent orchestration for coordinated execution:

1. **Initialize Orchestrator State**
   Create `.claude/orchestrator/state.json`:
   ```json
   {
     "status": "active",
     "roadmapSlug": "{{slug}}",
     "currentPhase": "phase-1",
     "activeAgents": [],
     "completedTasks": [],
     "pendingTasks": [],
     "failedTasks": [],
     "blockedTasks": [],
     "messages": [],
     "tokenBudget": {
       "total": 200000,
       "used": 0,
       "reserved": 20000
     },
     "metrics": {
       "agentsSpawned": 0,
       "tasksCompleted": 0,
       "tasksFailed": 0,
       "tasksBlocked": 0
     }
   }
   ```

2. **Configure L2 Specialists**
   Based on roadmap domains, generate specialist configurations:
   - `l2-frontend-specialist` - UI/component tasks
   - `l2-backend-specialist` - API/service tasks
   - `l2-testing-specialist` - Test/validation tasks
   - `l2-deployment-specialist` - CI/CD tasks

3. **Set Up Enforcement Hooks**
   Ensure these hooks are active in `.claude/settings.json`:
   - `hierarchy-validator` - Enforce L1 → L2 → L3 hierarchy
   - `orchestrator-enforcer` - Suggest delegation for direct operations
   - `progress-tracker` - Auto-update PROGRESS.json on completions
   - `github-progress-sync` - Push updates to GitHub issues

4. **Add Orchestration Commands**
   Generate `/orchestration-guide` command with:
   - How to spawn L2 specialists
   - L3 worker templates
   - Completion report format
   - Error handling procedures

### Step 6: Create GitHub Issues (MANDATORY - Use issue-hierarchy-manager.js)

**IMPORTANT:** Use the GitHub Issue Hierarchy Manager to ensure all parent issues exist.

```javascript
import { ensureHierarchyIssues } from './src/github/issue-hierarchy-manager.js';

// After creating ROADMAP.json, ensure GitHub issues exist
const result = await ensureHierarchyIssues(projectRoot, 'roadmap', roadmapSlug);

if (result.success) {
  console.log(`✅ GitHub issues created/verified`);

  if (result.created.length > 0) {
    console.log(`Auto-created parent issues: ${result.created.join(', ')}`);
  }

  if (result.roadmap) {
    console.log(`Roadmap Issue: #${result.roadmap.issueNumber}`);
  }

  if (result.epic) {
    console.log(`Parent Epic Issue: #${result.epic.issueNumber}`);
  }
} else {
  console.warn(`⚠️ GitHub issue creation failed: ${result.error}`);
}
```

**What this does:**

1. **Ensures Roadmap Issue Exists (Standalone or Hierarchical)**
   - Title: `[Roadmap] {roadmap_name}`
   - Body: CCASP-META header + overview + phase-dev-plan list
   - Labels: `roadmap`
   - Stores issue number in `ROADMAP.json` → `metadata.github_epic_number`
   - **Works without `parent_epic`** for standalone roadmaps

2. **Auto-Creates Parent Epic Issue (if missing and parent exists)**
   - If roadmap has `parent_epic` reference
   - Checks if `parent_epic.github_epic_number` exists
   - If not, creates epic issue with proper CCASP-META
   - Updates EPIC.json with issue number
   - **Skipped for standalone roadmaps** (no `parent_epic`)

3. **Adds Breadcrumb Navigation (if parent exists)**
   - Links parent epic in roadmap issue body
   - Format: `**Part of Epic:** [#123](url)`
   - **Standalone roadmaps**: No breadcrumb, just roadmap issue

**CCASP-META format (handled by issue-hierarchy-manager.js):**
```html
<!-- CCASP-META
source: /create-roadmap
slug: {roadmap-slug}
issue_type: roadmap
progress_file: .claude/roadmaps/{slug}/ROADMAP.json
parent_type: epic
parent_slug: {epic-slug}
created_at: {timestamp}
-->
```

**Generated Files section (auto-included):**
| File | Type | Path |
|------|------|------|
| Roadmap Definition | JSON | .claude/roadmaps/{slug}/ROADMAP.json |
| Exploration Summary | MD | .claude/roadmaps/{slug}/exploration/EXPLORATION_SUMMARY.md |
| Code Snippets | MD | .claude/roadmaps/{slug}/exploration/CODE_SNIPPETS.md |
| Reference Files | MD | .claude/roadmaps/{slug}/exploration/REFERENCE_FILES.md |
| Agent Delegation | MD | .claude/roadmaps/{slug}/exploration/AGENT_DELEGATION.md |
| Phase Breakdown | MD | .claude/roadmaps/{slug}/exploration/PHASE_BREAKDOWN.md |
| Findings | JSON | .claude/roadmaps/{slug}/exploration/findings.json |

### Step 7: Generate Documentation

Create comprehensive documentation:

**ROADMAP_OVERVIEW.md** - High-level summary:
- Goals and objectives
- Phase descriptions
- Timeline visualization
- Success criteria

**DEPENDENCY_GRAPH.md** - Visual dependencies:
```mermaid
graph LR
  P1[Foundation] --> P2[API Layer]
  P1 --> P3[UI Layer]
  P2 --> P4[Integration]
  P3 --> P4
  P4 --> P5[Polish]
```

**ARCHITECTURE.md** (if applicable):
- Component diagrams
- Data flow
- API contracts
- Code snippets showing patterns

### Step 8: Track Roadmap Completion

**Completion tracking via child PROGRESS.json files:**

When a phase-dev-plan completes:
1. src/phase-dev/completion-reporter.js sends PHASE_DEV_COMPLETE notification
2. Update the plan reference in ROADMAP.json:
   ```javascript
   updatePlanReference(roadmap, planSlug, {
     status: 'completed',
     completion_percentage: 100
   });
   ```
3. Recalculate overall completion:
   ```javascript
   roadmap.metadata.overall_completion_percentage = calculateOverallCompletion(roadmap);
   ```
4. Save updated ROADMAP.json

**When all plans complete:**
- Roadmap status becomes 'completed'
- If roadmap has parent_epic, report ROADMAP_COMPLETE to epic
- Display completion summary

### Step 9: Display Summary

After creation, display:

```
╔═══════════════════════════════════════════════════════════════════════╗
║  ✓ Roadmap Created Successfully!                                       ║
╠═══════════════════════════════════════════════════════════════════════╣
║                                                                         ║
║  Roadmap: {{roadmap_name}}                                              ║
║  Phase-Dev-Plans: {{planCount}}                                         ║
║  Location: .claude/roadmaps/{{slug}}/ROADMAP.json                       ║
║                                                                         ║
{{#if parent_epic}}
║  Parent Epic: {{parent_epic.title}} ({{parent_epic.slug}})              ║
{{/if}}
{{#if githubIssue}}
║  GitHub Epic: #{{epicNumber}} ({{epicUrl}})                             ║
║  Child Issues: {{childCount}} created                                   ║
{{/if}}
║                                                                         ║
║  Phase-Dev-Plans:                                                       ║
{{#each phase_dev_plan_refs}}
║  - {{slug}} ({{status}})                                                ║
{{/each}}
║                                                                         ║
║  Next Steps:                                                            ║
║  1. Review exploration files in .claude/roadmaps/{{slug}}/exploration/  ║
║  2. Spawn phase-dev-plans (if not done): /phase-dev-plan --parent-...   ║
║  3. Track overall progress: /roadmap-status {{slug}}                    ║
║                                                                         ║
╚═══════════════════════════════════════════════════════════════════════╝
```

## Argument Handling

If invoked with arguments:

- `/create-roadmap` - Interactive mode selection
- `/create-roadmap {description}` - Use description as initial scope (Mode A)
- `/create-roadmap --from-github` - Import from GitHub issues (Mode B)
- `/create-roadmap --from-project {number}` - Import from GitHub Project Board
- `/create-roadmap --from-tasks` - Create roadmap from existing task list
- `/create-roadmap --split` - Split a complex phase plan into roadmap
- `/create-roadmap --parent-epic {epic-slug}` - Create roadmap as child of an epic (reads .claude/epics/{slug}/EPIC.json)

## Error Handling

If any step fails:
1. Report the specific error
2. Save partial progress to ROADMAP.json
3. Offer to retry or continue manually
4. Do not create GitHub issues until ROADMAP.json is complete

## Related Commands

- `/roadmap-status` - View overall roadmap progress dashboard
- `/roadmap-edit` - Edit roadmap structure (reorder, merge, split, remove phases)
- `/roadmap-track` - Track execution and manage phase lifecycle
- `/phase-track` - Track progress on individual phases
- `/create-phase-dev` - Create single phase development plan
- `/github-update` - Sync with GitHub Project Board

## Enforcement Rules (Epic-Hierarchy Architecture)

| Rule | Implementation | MANDATORY |
|------|----------------|-----------|
| L2 Exploration FIRST | Create all 6 exploration files BEFORE ROADMAP.json | ✅ YES |
| No roadmap without exploration | `.claude/roadmaps/{slug}/exploration/` must exist with 6 files | ✅ YES |
| Consolidated structure | All files in `.claude/roadmaps/{slug}/` | ✅ YES |
| Dynamic command created | Creates `/roadmap-{slug}` command | ✅ YES |
| Analyze scope for plan count | Determine HOW MANY phase-dev-plans needed | ✅ YES |
| Use phase_dev_plan_refs[] | Store plan references, not direct phases | ✅ YES |
| Use refactored schema functions | addPlanReference(), calculateOverallCompletion() | ✅ YES |
| Offer to spawn plans | Display menu to invoke /phase-dev-plan for each | ✅ YES |
| Track via PROGRESS.json | Each plan reports back when complete | ✅ YES |
| Parent epic support | Accept --parent-epic flag and store reference | ✅ YES |
| User selects issues via table | Mode B displays numbered table for selection | ✅ YES |
| Single-phase recommendation | Recommends `/phase-dev-plan` for small scope | ⚠️ Warning |
| Compliance docs before coding | If compliance.blocking=true, ROUTES.md + RBAC.md must exist before spawning plans | ✅ YES |

### ⛔ FAILURE CONDITIONS - DO NOT PROCEED IF:
- Exploration directory doesn't exist: `.claude/roadmaps/{slug}/exploration/`
- Any of the 6 exploration files are missing
- ROADMAP.json is created before exploration files
- Plan count not analyzed (must determine how many plans needed)
- Using legacy phases[] instead of phase_dev_plan_refs[]
- Not using refactored schema.js functions
- Parent epic slug provided but EPIC.json doesn't exist

### Validation Checklist (Run Before Completion)
```
[ ] .claude/roadmaps/{slug}/exploration/EXPLORATION_SUMMARY.md exists
[ ] .claude/roadmaps/{slug}/exploration/CODE_SNIPPETS.md exists
[ ] .claude/roadmaps/{slug}/exploration/REFERENCE_FILES.md exists
[ ] .claude/roadmaps/{slug}/exploration/AGENT_DELEGATION.md exists
[ ] .claude/roadmaps/{slug}/exploration/PHASE_BREAKDOWN.md exists
[ ] .claude/roadmaps/{slug}/exploration/findings.json exists
[ ] .claude/roadmaps/{slug}/ROADMAP.json exists
[ ] ROADMAP.json uses phase_dev_plan_refs[] (NEW architecture)
[ ] Each plan slug is valid and unique
[ ] Cross-plan dependencies are defined if needed
[ ] .claude/commands/roadmap-{slug}.md exists (dynamic command)
[ ] If --parent-epic used, parent_epic reference is stored
```

---

## Step 9: Create Dynamic Slash Command (MANDATORY)

**IMPORTANT:** After creating the roadmap, you MUST generate a dynamic slash command.

### Dynamic Command Template

Create file `.claude/commands/roadmap-{slug}.md`:

```markdown
# /roadmap-{slug} - {title}

Execute and track the **{title}** roadmap.

## Quick Reference

| Property | Value |
|----------|-------|
| Roadmap ID | {roadmap_id} |
| Phases | {phase_count} |
| Status | {status} |
| Created | {created_date} |

## Actions

### View Status
Show current progress and next available tasks:
\`\`\`
/roadmap-status {slug}
\`\`\`

### Start/Continue Execution
Begin or resume working on this roadmap:
\`\`\`
/roadmap-track {slug} start
\`\`\`

### Execute Next Phase
Start the next available phase:
\`\`\`
/roadmap-track {slug} next
\`\`\`

## Phase Summary

{phase_list_markdown}

## Files Location

All roadmap files are in: `.claude/roadmaps/{slug}/`
- `ROADMAP.json` - Main roadmap definition
- `phase-*.json` - Phase plans
- `exploration/` - Analysis and reference documents

## Testing Configuration

{{#if testing.e2e.framework}}
- E2E Framework: {{testing.e2e.framework}}
- Environment: {testing_environment}
- Ralph Loop: {ralph_enabled}
{{else}}
- E2E testing not configured
{{/if}}

## Cleanup

When this roadmap is complete, remove this command:
\`\`\`bash
rm .claude/commands/roadmap-{slug}.md
\`\`\`

---
*Dynamic command generated by /create-roadmap*
```

### Command Naming Convention

| Roadmap Type | Command Name | Example |
|--------------|--------------|---------|
| Feature roadmap | `/roadmap-{feature-slug}` | `/roadmap-user-auth` |
| Refactor roadmap | `/roadmap-{component}-refactor` | `/roadmap-dashboard-refactor` |
| Migration roadmap | `/roadmap-{migration-slug}` | `/roadmap-v2-migration` |

### Auto-Removal on Completion

When a roadmap reaches 100% completion:
1. The `/roadmap-track` command detects completion
2. Prompts: "Roadmap complete! Remove dynamic command /roadmap-{slug}?"
3. If confirmed, deletes `.claude/commands/roadmap-{slug}.md`

---

*Create Roadmap - Part of CCASP Roadmap Orchestration Framework*
