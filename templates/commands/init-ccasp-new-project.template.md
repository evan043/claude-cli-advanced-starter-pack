---
description: Initialize CCASP for new project
model: sonnet
---

# Initialize CCASP New Project

You are setting up a fresh project with CCASP (Claude CLI Advanced Starter Pack) Full preset. This command is for Happy Engineering users who cannot run the terminal wizard.

## Prerequisites Check

First, verify this is an appropriate target:

1. **Check current directory** - Run `ls -la` to see what exists
2. **Confirm empty or minimal** - Should be empty or have only basic files (README, .gitignore)
3. **Confirm with user** - If files exist, ask if they want to proceed

If the directory has significant code, recommend using `/project-implementation-for-ccasp` instead.

## Step 1: Collect Project Intent

**CRITICAL**: Before deploying anything, gather the user's project vision. This information flows through the entire workflow.

Use AskUserQuestion to ask:

### 1.1 Project Name
**Question**: "What should this project be called?"
- This becomes the project directory name and package name

### 1.2 Project Description
**Question**: "Describe what you're building in 1-2 sentences."
- Example: "A newsletter management system for tracking subscriber engagement"
- This description informs scaffolding, CLAUDE.md, and task generation

### 1.3 Project Type
**Question**: "What type of project is this?"
**Options**:
- **Web Application** - Frontend UI (React, Vue, Svelte)
- **API/Backend** - REST or GraphQL server
- **Full-Stack** - Frontend + Backend together
- **CLI Tool** - Command-line application
- **Desktop App** - Cross-platform (Tauri, Electron)

### 1.4 Primary Tech Preferences (Optional)
**Question**: "Any specific technologies you want to use?"
**Options** (multiSelect):
- **TypeScript** (recommended)
- **React**
- **FastAPI/Python**
- **Node.js/Express**
- **Let Claude choose based on project type**

### Save Project Intent

Create `project-goals.json` in the current directory:
```json
{
  "name": "{{user_input.name}}",
  "description": "{{user_input.description}}",
  "type": "{{user_input.type}}",
  "techPreferences": ["{{user_input.tech}}"],
  "createdAt": "{{timestamp}}",
  "source": "init-ccasp-new-project"
}
```

This file is used by:
- `/project-explorer` for scaffolding decisions
- `/project-implementation-for-ccasp` for tech stack validation
- `/create-task-list` for initial task generation
- CLAUDE.md generation

---

## Step 2: Vision & Epic System Toggle (Optional)

Use AskUserQuestion to ask:

**Question**: "Enable Vision & Epic system?"

**Explanation to show**:
```
Vision & Epics are OPTIONAL strategic planning layers (disabled by default).

Hierarchy when enabled:
  Vision (Why)     -> Years      [AI-managed, OKRs]
    └── Epics      -> 1-4 weeks  [User-managed initiatives]
          └── (links to Roadmaps)

Note: Roadmaps, Phase Dev Plans, and Task Lists ALWAYS work
independently - they don't require Vision & Epic.

Enable Vision & Epic if you want:
- OKR-based strategic planning
- Epic issue management with GitHub
- Testing schedules with RALPH loop
- Progress tracking across initiatives
```

**Options**:
- **Yes** - Enable Vision & Epic with all commands/hooks
- **No** - Use Roadmaps/Phases/Tasks independently (recommended for most projects)

## Step 3: Create Epic (if Vision enabled)

If user chose "Yes" for Vision & Epic:

Use AskUserQuestion to ask:

**Question**: "Create an Epic for this new project?"

**Options**:
- **Yes** - I'll provide Epic details now
- **Later** - Set up CCASP first, create Epic later via /github-epic-menu

If "Yes", gather:
1. Epic title (brief name)
2. Business objective (what this achieves)
3. Success criteria (2-3 measurable outcomes)

## Step 4: Deploy Full Preset

Create the `.claude/` directory structure with ALL 16 optional features enabled:

### Features to Deploy (Full Preset)

1. **tokenManagement** - Token budget monitoring
2. **happyMode** - Happy Engineering integration
3. **githubIntegration** - GitHub Project Board connection
4. **phasedDevelopment** - Phase dev plans with PROGRESS.json
5. **deploymentAutomation** - Full-stack deployment workflows
6. **tunnelServices** - Local dev server tunneling
7. **advancedHooks** - Extended hook suite
8. **skillTemplates** - Agent/hook/RAG skill creators
9. **refactoring** - Code quality tools
10. **testing** - Advanced testing capabilities
11. **ralphLoop** - Continuous test-fix cycles
12. **refactorAudit** - Refactor monitoring system
13. **autoStackAgents** - Stack-specific agent generation
14. **projectExplorer** - Fresh project scaffolding
15. **roadmapSystem** - Multi-phase roadmap management
16. **agentOrchestration** - L1/L2/L3 agent hierarchy

### Directory Structure to Create

```
.claude/
├── commands/           # Slash commands (40+)
├── skills/            # Skill packages
│   ├── agent-creator/
│   ├── hook-creator/
│   ├── rag-agent-creator/
│   └── panel/
├── agents/            # Agent definitions
│   └── example-agent.md
├── hooks/             # Enforcement hooks
├── docs/              # Documentation
└── settings.json      # Configuration
```

### Commands to Deploy

Deploy ALL slash commands from the Full preset:

**Navigation**: menu, ccasp-panel
**Testing**: e2e-test, ralph, create-smoke-test
**Refactoring**: refactor-workflow, refactor-analyze, golden-master, refactor-check, refactor-cleanup, refactor-prep
**GitHub**: github-task, menu-issues-list, create-task-list-for-issue, github-update, github-task-start
**Planning**: phase-dev-plan, phase-track, create-task-list, create-roadmap, roadmap-status, roadmap-track, roadmap-edit
**Claude Code**: create-agent, create-hook, create-skill, claude-audit, generate-agents, codebase-explorer, orchestration-guide
**Setup**: project-explorer, project-implementation-for-ccasp, update-check, update-smart, detect-tech-stack
**Deployment**: deploy-full, tunnel-start, tunnel-stop
**Token**: context-audit
**Happy**: happy-start

### If Vision & Epic Enabled

Also deploy:
- `/github-epic-menu`
- `/create-github-epic`
- `/github-epic-status`
- `/github-epic-edit`
- `/github-epic-track`

Create additional directories:
```
.claude/
├── github-epics/      # Epic definitions
├── phase-plans/       # Linked phase plans
└── testing-issues/    # Testing schedules
```

### settings.json Template

Create `.claude/settings.json`:

```json
{
  "hooks": {
    "pre-tool-use": [
      ".claude/hooks/context-guardian.js",
      ".claude/hooks/phase-dev-enforcer.js"
    ],
    "post-tool-use": [
      ".claude/hooks/progress-tracker.js"
    ],
    "session-start": [
      ".claude/hooks/session-id-generator.js",
      ".claude/hooks/happy-mode-detector.js"
    ]
  },
  "features": {
    "tokenManagement": true,
    "happyMode": true,
    "githubIntegration": true,
    "phasedDevelopment": true,
    "deploymentAutomation": true,
    "tunnelServices": true,
    "advancedHooks": true,
    "skillTemplates": true,
    "refactoring": true,
    "testing": true,
    "ralphLoop": true,
    "refactorAudit": true,
    "autoStackAgents": true,
    "projectExplorer": true,
    "roadmapSystem": true,
    "agentOrchestration": true
  },
  "vision_epics": {
    "enabled": false,
    "require_tech_stack": true,
    "require_scaffolded_project": true
  }
}
```

If Vision & Epic enabled, set `vision_epics.enabled: true`.

## Step 5: Create CLAUDE.md

Generate a starter CLAUDE.md file:

```markdown
# Project Name

## Overview
[Project description - to be filled after scaffolding]

## Quick Start
\`\`\`bash
# Commands will be populated after tech stack detection
\`\`\`

## Key Locations
- Source: `src/`
- Tests: `tests/`
- Config: `.claude/`

## CCASP Commands

| Command | Description |
|---------|-------------|
| `/menu` | Interactive command menu |
| `/create-task-list` | AI-powered task generation |
| `/phase-dev-plan` | Phased development planning |
| `/project-explorer` | Scaffold project structure |

## Tech Stack
[Run /detect-tech-stack after project setup]

---
*Initialized with CCASP Full preset*
```

## Step 6: Hand Off - Complete Workflow

After CCASP setup is complete, inform the user:

```
╔════════════════════════════════════════════════════════════════╗
║  CCASP Full Preset Deployed Successfully!                       ║
╠════════════════════════════════════════════════════════════════╣
║                                                                 ║
║  Project: {{project.name}}                                      ║
║  Type: {{project.type}}                                         ║
║  Features Enabled: 16/16 (Full)                                 ║
║  Vision & Epic: [Enabled/Disabled]                              ║
║                                                                 ║
║  Directory Created: .claude/                                    ║
║    ├── commands/    (40+ slash commands)                        ║
║    ├── skills/      (skill packages)                            ║
║    ├── agents/      (agent definitions)                         ║
║    ├── hooks/       (enforcement hooks)                         ║
║    └── docs/        (documentation)                             ║
║                                                                 ║
║  Project Intent Saved: project-goals.json                       ║
║                                                                 ║
╠════════════════════════════════════════════════════════════════╣
║  IMPORTANT: Restart Claude Code to load new commands!           ║
╠════════════════════════════════════════════════════════════════╣
║                                                                 ║
║  Recommended Workflow:                                          ║
║  1. Restart Claude Code CLI                                     ║
║  2. Run /project-explorer (uses your project-goals.json)        ║
║  3. Run /project-implementation-for-ccasp (tech stack setup)    ║
║                                                                 ║
╚════════════════════════════════════════════════════════════════╝
```

### Handoff Options

Ask user via AskUserQuestion:

**Question**: "How would you like to proceed?"

**Options**:
- **Continue now** - Run /project-explorer immediately (project-goals.json already saved)
- **Restart first** - I'll restart Claude Code, then run /project-explorer manually
- **Skip scaffolding** - I'll set up the project structure manually

### If "Continue now":

1. **Invoke `/project-explorer`** which will:
   - Read `project-goals.json` for project intent
   - Skip questions already answered (name, description, type)
   - Ask remaining questions (database, features, deployment)
   - Scaffold project structure
   - Install dependencies

2. **After scaffolding completes**, automatically invoke `/project-implementation-for-ccasp`:
   - Detect actual tech stack from scaffolded files
   - Generate comprehensive CLAUDE.md
   - Offer GitHub Project Board setup
   - Recommend MCP servers for the stack
   - Generate stack-specific agents

### Full Workflow Summary

```
/init-ccasp-new-project
    │
    ├─► Step 1: Collect project intent → project-goals.json
    ├─► Step 2: Vision & Epic toggle
    ├─► Step 3: Epic creation (optional)
    ├─► Step 4: Deploy CCASP Full preset → .claude/
    ├─► Step 5: Create starter CLAUDE.md
    │
    └─► Handoff to:
          │
          ├─► /project-explorer
          │     └─► Scaffold project based on intent
          │
          └─► /project-implementation-for-ccasp
                ├─► Detect actual tech stack
                ├─► Enhance CLAUDE.md
                ├─► Configure GitHub
                └─► Setup MCPs
```

This ensures the user's project vision flows through:
1. **Scaffolding** - Correct structure for their project type
2. **Tech Stack** - Proper detection and configuration
3. **Documentation** - CLAUDE.md matches their intent
4. **Task Planning** - `/create-task-list` uses project context

## Step 7: Epic Creation (if requested)

If user requested Epic creation in Step 3:

1. Create Epic JSON in `.claude/github-epics/<slug>.json`
2. Create GitHub issue with Epic label (if gh CLI authenticated)
3. Set up PROGRESS.json with Epic reference
4. Display Epic summary

## Error Handling

If any step fails:
1. Report specific error
2. Suggest manual fix
3. Offer to retry or skip to next step
4. Save progress for resume

## Related Commands

- `/project-explorer` - Scaffold project structure
- `/github-epic-menu` - Manage Epics (if enabled)
- `/detect-tech-stack` - Detect and configure tech stack
- `/menu` - Access all commands

---

*Init CCASP New Project - Part of CCASP v2.2.0*
