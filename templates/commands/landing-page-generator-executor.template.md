---
description: Landing Page Generator - Phase Executor
model: sonnet
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Task
  - Glob
  - Grep
---

# Landing Page Generator - Phase Executor

{{#if panel_config}}
**Panel config gate:** If `panel_config.features.landing_page_generator === false`, skip this entire command.
Display: "Landing page generator executor skipped (disabled in panel config)."
{{/if}}

You are executing phases of the Landing Page Generator feature integration.

## Execution Protocol

### Step 1: Load Progress State

Read `.claude/docs/landing-page-generator/PROGRESS.json` to determine current state.

### Step 2: Identify Next Phase

Find the first phase with `status: "pending"` or `status: "in_progress"`.

### Step 3: Load Exploration Context

Read the relevant exploration files before executing:
- `.claude/exploration/landing-page-generator/PHASE_BREAKDOWN.md` - Detailed task specs
- `.claude/exploration/landing-page-generator/CODE_SNIPPETS.md` - Code patterns to follow
- `.claude/exploration/landing-page-generator/REFERENCE_FILES.md` - Files to create/modify
- `.claude/exploration/landing-page-generator/AGENT_DELEGATION.md` - Agent assignments

### Step 4: Execute Phase Tasks

For each pending task in the current phase:

1. **Update task status** to `in_progress` in PROGRESS.json
2. **Execute the task** following the PHASE_BREAKDOWN.md specification
3. **Verify acceptance criteria** for the task
4. **Update task status** to `completed` in PROGRESS.json

### Step 5: Phase Completion

When all tasks in a phase are complete:
1. Update phase status to `completed` in PROGRESS.json
2. Update `updated_at` timestamp
3. Display completion summary
4. Check if next phase can begin

## Phase Reference

| Phase | Name | Key Output |
|-------|------|------------|
| 1 | Core Slash Command Templates | 3 template files in `templates/commands/` |
| 2 | Screenshot Pipeline Skill | Skill package in `templates/skills/screenshot-pipeline/` |
| 3 | Feature Registration & Menu | Modifications to `src/commands/init/` |
| 4 | Documentation & Validation | README updates, deployment verification |

## Source Vision Reference

The feature spec comes from the existing Vision project (if available):
- Architecture: `.claude/visions/landing-page-image-generator/architecture.md`
- Wireframes: `.claude/visions/landing-page-image-generator/wireframes.md`
- Roadmap: `.claude/visions/landing-page-image-generator/ROADMAP.json`

**IMPORTANT:** Generalize all project-specific content. Routes, viewports, device frames, and deployment targets must use template placeholders or be configurable.

## Agent Delegation

Delegate tasks to specialized agents based on domain:

- **Frontend tasks** (React components, UI) → `l2-frontend-specialist`
- **Backend tasks** (API endpoints, config) → `l2-backend-specialist`
- **Testing tasks** (Playwright, validation) → `l2-testing-specialist`
- **General tasks** (documentation, README) → `general-purpose`

Use the `Task` tool with `subagent_type` matching the agent from AGENT_DELEGATION.md.

## FORBIDDEN

- Do NOT hardcode project-specific routes or feature names
- Do NOT skip PROGRESS.json updates between tasks
- Do NOT proceed to next phase before current phase passes acceptance criteria
- Do NOT launch background agents without explicit context in the task spec

## Argument Handling

- `/landing-page-generator-executor` - Execute next pending phase
- `/landing-page-generator-executor phase-1` - Execute specific phase
- `/landing-page-generator-executor status` - Show current progress

## Status Display Format

When showing status:

```
╔═══════════════════════════════════════════════════════╗
║  LANDING PAGE GENERATOR - PROGRESS                    ║
╠═══════════════════════════════════════════════════════╣
║  Overall Status: {status}                             ║
║  Current Phase: {current_phase_name}                  ║
║  Completed: {completed_phases}/{total_phases}         ║
╠═══════════════════════════════════════════════════════╣
║  Phase Breakdown                                      ║
╠═══════════════════════════════════════════════════════╣
║  Phase 1: Core Slash Command Templates               ║
║    Status: {status}                                   ║
║    Tasks: {completed}/{total}                         ║
║                                                       ║
║  Phase 2: Screenshot Pipeline Skill Package          ║
║    Status: {status}                                   ║
║    Tasks: {completed}/{total}                         ║
║                                                       ║
║  Phase 3: Feature Registration & Menu Integration    ║
║    Status: {status}                                   ║
║    Tasks: {completed}/{total}                         ║
║                                                       ║
║  Phase 4: Documentation & Validation                 ║
║    Status: {status}                                   ║
║    Tasks: {completed}/{total}                         ║
╚═══════════════════════════════════════════════════════╝
```

## Example Execution Flow

1. User runs: `/landing-page-generator-executor`
2. You read PROGRESS.json → find Phase 1 is pending
3. You load PHASE_BREAKDOWN.md → understand Phase 1 tasks
4. You execute Task 1.1:
   - Update PROGRESS.json: Task 1.1 → "in_progress"
   - Create `templates/commands/landing-page-generator.template.md`
   - Verify template has valid frontmatter and placeholders
   - Update PROGRESS.json: Task 1.1 → "completed"
5. Repeat for Tasks 1.2, 1.3
6. When all Phase 1 tasks completed:
   - Update PROGRESS.json: Phase 1 → "completed"
   - Display summary
   - Ask user if they want to continue to Phase 2

---

*Part of Claude CLI Advanced Starter Pack - Landing Page Generator Integration*
