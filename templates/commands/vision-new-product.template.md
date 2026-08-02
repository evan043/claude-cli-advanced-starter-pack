---
description: Bootstrap a brand-new product from a natural language prompt — scaffold, repo, CCASP, and epic in one command
model: opus
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Task
  - Glob
  - Grep
  - AskUserQuestion
  - WebSearch
  - WebFetch
options:
  - label: "Quick Start"
    description: "Provide a vision prompt and let the command handle everything"
  - label: "Custom"
    description: "Configure tech stack, project name, and settings manually"
---

# /vision-new-product — Greenfield Product Bootstrap

Create a brand-new product from a single natural language prompt. Automates the entire flow: directory scaffold, Git + GitHub repo, CCASP init, project implementation, and full Vision pipeline — all orchestrated as one command.

**Orchestration Flow:**
```
Prompt → Tech Stack → Scaffold → Git/GitHub → CCASP → Project-Impl → Vision-Init → Ready
  (1)      (2)          (3)        (4)         (5)       (6)            (7)          (8)
```

**What this command creates:**
- A new project directory under `~/Projects/{slug}/`
- Scaffolded codebase (Vite, Next.js, Express, etc.)
- Private GitHub repository with initial commit
- Full `.claude/` configuration (agents, hooks, commands, settings)
- VISION.json, EPIC.json, ROADMAP.json(s), PROGRESS.json(s)
- Competitive analysis, architecture diagrams, security scan
- GitHub epic issue ready for `/vision-run`

---

## HARD CONSTRAINTS (NON-NEGOTIABLE)

### FORBIDDEN — Will Cause Failure:
- **DO NOT** create a project in a directory that already exists (greenfield only)
- **DO NOT** skip user confirmation of detected tech stack
- **DO NOT** proceed to Step N+1 if Step N failed (sequential execution)
- **DO NOT** force-push or use destructive git operations
- **DO NOT** commit `.env` files or credentials

### REQUIRED — Must Follow:
1. **Validate slug uniqueness** before creating any files
2. **Confirm tech stack** with user before scaffolding
3. **Check each step's exit code** before continuing
4. **Platform-aware paths**: Windows `%USERPROFILE%\Projects\` vs Unix `~/Projects/`
5. **Display progress** after each step completes

---

## Execution Protocol

### Step 1: Gather Input

Use AskUserQuestion to collect:

1. **Natural Language Prompt** (required)
   - "What do you want to build?"
   - Example: "Build a SaaS analytics dashboard with React, FastAPI backend, Stripe billing, and real-time WebSocket updates"

2. **Project Name** (optional — generated from prompt if omitted)
   - Human-readable name, e.g., "Analytics Dashboard Pro"

3. **Project Slug** (auto-generated, kebab-case from name)
   - e.g., `analytics-dashboard-pro`

4. **Tags** (optional, comma-separated)
   - e.g., "saas, analytics, mvp"

5. **Priority** (optional, defaults to 'medium')
   - low / medium / high / critical

**Validate slug uniqueness:**

```javascript
// Determine base path (platform-aware)
const isWindows = process.platform === 'win32';
const homeDir = isWindows ? process.env.USERPROFILE : process.env.HOME;
const basePath = `${homeDir}${isWindows ? '\\' : '/'}Projects`;
const projectPath = `${basePath}${isWindows ? '\\' : '/'}${slug}`;

// Check if directory already exists
const exists = existsSync(projectPath);
if (exists) {
  console.error(`❌ Directory already exists: ${projectPath}`);
  console.log('   /vision-new-product is greenfield only — it creates new projects.');
  console.log('   For existing projects, use /vision-init instead.');
  return;
}
```

**Display gathered input:**

```
╔════════════════════════════════════════════════════════════════════════╗
║                   NEW PRODUCT CONFIGURATION                            ║
╠════════════════════════════════════════════════════════════════════════╣
║                                                                        ║
║  Prompt: {{userPrompt}}                                                ║
║  Name:   {{projectName}}                                               ║
║  Slug:   {{slug}}                                                      ║
║  Path:   {{projectPath}}                                               ║
║  Tags:   {{tags}}                                                      ║
║  Priority: {{priority}}                                                ║
║                                                                        ║
╚════════════════════════════════════════════════════════════════════════╝
```

### Step 2: Determine Tech Stack from Prompt

Parse the user's natural language prompt to detect technologies and map them to a scaffolding command:

```javascript
import { parseVisionPrompt, estimateComplexity } from '${CWD}/node_modules/claude-cli-advanced-starter-pack/src/vision/index.js';

const parsedPrompt = parseVisionPrompt(userPrompt);
const complexity = estimateComplexity(parsedPrompt);
const technologies = parsedPrompt.technologies || [];
```

**Tech stack → scaffolding command mapping:**

| Detection | Scaffolding Command |
|-----------|---------------------|
| React (no Next.js) | `npm create vite@latest {slug} -- --template react-ts` |
| Next.js | `npx create-next-app@latest {slug} --ts --tailwind --app` |
| Vue | `npm create vite@latest {slug} -- --template vue-ts` |
| Svelte | `npm create vite@latest {slug} -- --template svelte-ts` |
| FastAPI + React | React scaffold + `mkdir backend && cd backend && python -m venv venv` |
| Express / Node.js | `npm init -y` + `npm install express typescript @types/express` |
| Fallback (no match) | `npm init -y` |

**Selection logic:**
```javascript
function selectScaffold(technologies) {
  const techs = technologies.map(t => t.toLowerCase());

  if (techs.includes('next.js') || techs.includes('nextjs')) {
    return { frontend: 'nextjs', command: `npx create-next-app@latest ${slug} --ts --tailwind --app` };
  }
  if (techs.includes('vue')) {
    return { frontend: 'vue', command: `npm create vite@latest ${slug} -- --template vue-ts` };
  }
  if (techs.includes('svelte')) {
    return { frontend: 'svelte', command: `npm create vite@latest ${slug} -- --template svelte-ts` };
  }
  if (techs.includes('react')) {
    return { frontend: 'react', command: `npm create vite@latest ${slug} -- --template react-ts` };
  }

  // Backend-only detection
  if (techs.includes('express') || techs.includes('node')) {
    return { backend: 'express', command: `npm init -y` };
  }

  // Fallback
  return { frontend: 'vanilla', command: `npm init -y` };
}

const scaffold = selectScaffold(technologies);

// Check for full-stack (frontend + backend)
const hasBackend = techs.some(t => ['fastapi', 'express', 'django', 'flask', 'nest', 'nestjs'].includes(t));
const hasFrontend = scaffold.frontend != null;
const isFullStack = hasFrontend && hasBackend;
```

**Display detected stack and ask for confirmation:**

```
╔════════════════════════════════════════════════════════════════════════╗
║                   DETECTED TECH STACK                                  ║
╠════════════════════════════════════════════════════════════════════════╣
║                                                                        ║
║  Frontend: {{scaffold.frontend || 'None detected'}}                    ║
║  Backend:  {{backendFramework || 'None detected'}}                     ║
║  Full-Stack: {{isFullStack ? 'Yes' : 'No'}}                           ║
║  Complexity: {{complexity.level}} (score: {{complexity.score}})        ║
║                                                                        ║
║  Scaffold Command:                                                     ║
║    {{scaffold.command}}                                                 ║
║                                                                        ║
╚════════════════════════════════════════════════════════════════════════╝
```

Use AskUserQuestion to confirm:
```
header: "Tech Stack"
question: "Proceed with the detected tech stack, or override?"
options:
  - label: "Confirm (Recommended)"
    description: "Use the detected stack above"
  - label: "Override"
    description: "Choose a different framework/scaffold manually"
  - label: "Abort"
    description: "Cancel product creation"
```

If user selects "Override", ask for their preferred frontend and backend frameworks, then rebuild the scaffold command.

### Step 3: Create Project Directory + Scaffold

```javascript
// Ensure ~/Projects/ base directory exists
// Bash: mkdir -p ~/Projects  (Unix)
// Bash: mkdir "%USERPROFILE%\Projects" (Windows, if not exists)

console.log(`📁 Creating project: ${projectPath}`);
```

**Run scaffolding command:**

```javascript
// Navigate to base path and run scaffold
// Bash: cd ~/Projects && {scaffold.command}
// The scaffold command creates the {slug}/ directory itself

console.log(`🏗️  Scaffolding with: ${scaffold.command}`);
// Execute via Bash tool

// Verify scaffold succeeded
// Bash: ls ~/Projects/{slug}/package.json  (or equivalent)
if (!scaffoldSuccess) {
  console.error('❌ Scaffolding failed. Check the command output above.');
  // Offer: Retry / Use fallback (npm init -y) / Abort
  return;
}

console.log(`✅ Step 3 complete — project scaffolded at ${projectPath}`);
```

**For full-stack projects (FastAPI + frontend):**

```javascript
if (isFullStack && backendFramework === 'fastapi') {
  // After frontend scaffold, create backend structure
  // Bash: cd ~/Projects/{slug} && mkdir -p backend
  // Bash: cd ~/Projects/{slug}/backend && python -m venv venv
  // Write: ~/Projects/{slug}/backend/requirements.txt with FastAPI deps
  // Write: ~/Projects/{slug}/backend/main.py with minimal FastAPI app
  console.log('  ✓ Backend directory created with FastAPI skeleton');
}

if (isFullStack && backendFramework === 'express') {
  // Bash: cd ~/Projects/{slug} && mkdir -p backend && cd backend && npm init -y
  // Bash: cd ~/Projects/{slug}/backend && npm install express typescript @types/express
  console.log('  ✓ Backend directory created with Express skeleton');
}
```

### Step 4: Initialize Git + Create Private GitHub Repo

```javascript
console.log('🔧 Initializing Git repository...');

// Check if scaffolder already ran git init
// Bash: cd ~/Projects/{slug} && git status 2>/dev/null
// If not a git repo yet:
// Bash: cd ~/Projects/{slug} && git init

// Stage all files and create initial commit
// Bash: cd ~/Projects/{slug} && git add -A && git commit -m "$(cat <<'EOF'
// Initial scaffold: {projectName}
//
// Tech stack: {scaffold.frontend || ''} {backendFramework || ''}
// Created by /vision-new-product
//
// Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
// EOF
// )"

console.log('  ✓ Initial commit created');
```

**Create private GitHub repository:**

```javascript
console.log('📦 Creating GitHub repository...');

// Bash: cd ~/Projects/{slug} && gh repo create {slug} --private --source=. --push
// Capture the repo URL from gh output

if (!repoCreateSuccess) {
  console.error('⚠️  GitHub repo creation failed. Continuing without remote.');
  console.log('   You can create it later: gh repo create {slug} --private --source=. --push');
  // Don't abort — local project is still valid
} else {
  console.log(`  ✓ GitHub repo created: https://github.com/{username}/{slug}`);
  console.log('  ✓ Code pushed to remote');
}
```

**Store repo URL for Step 8 summary:**
```javascript
const repoUrl = `https://github.com/${username}/${slug}`;
```

### Step 5: Install CCASP + Run Init

```javascript
console.log('📦 Installing CCASP...');

// Bash: cd ~/Projects/{slug} && npm install --save-dev claude-cli-advanced-starter-pack

if (!installSuccess) {
  console.error('❌ CCASP installation failed.');
  console.log('   Try manually: cd ~/Projects/{slug} && npm install --save-dev claude-cli-advanced-starter-pack');
  return;
}

console.log('  ✓ CCASP installed');

// Run ccasp init with standard preset (non-interactive)
console.log('🔧 Running CCASP init (standard preset)...');

// Bash: cd ~/Projects/{slug} && npx ccasp init --preset standard

console.log('  ✓ .claude/ structure created');
console.log(`✅ Step 5 complete — CCASP initialized`);
```

**The `ccasp init --preset standard` creates:**
```
.claude/
├── commands/          # Slash commands
├── hooks/             # Enforcement hooks
├── agents/            # Agent definitions
├── settings.json      # Claude Code settings
├── config/            # Project configuration
│   └── tech-stack.json
└── CLAUDE.md          # Project instructions
```

### Step 6: Run /project-implementation-for-ccasp

Invoke the existing project implementation command to complete CCASP setup:

```javascript
console.log('🔧 Running project implementation...');
console.log('   This handles: tech-stack detection, agent generation, CLAUDE.md, GitHub board, MCP discovery');

// IMPORTANT: This is a slash command invocation within Claude Code.
// Use: Skill tool to invoke /project-implementation-for-ccasp
// OR: Read and execute the template instructions inline.
//
// The command will:
// 1. Detect tech stack → save to .claude/config/tech-stack.json
// 2. Generate agents → save to .claude/agents/agents.json
// 3. Audit/create CLAUDE.md
// 4. Configure GitHub Project Board integration
// 5. Discover and recommend MCP servers
// 6. Set up testing configuration
//
// For a brand-new scaffolded project, this will work with the
// minimal existing files (package.json, scaffold boilerplate).

console.log(`✅ Step 6 complete — project implementation configured`);
```

**Expected output for new project:**
- `tech-stack.json` with detected frameworks from scaffold
- `agents.json` with L1 orchestrator + domain-specific agents
- `CLAUDE.md` with project-specific instructions
- Testing config stubs

### Step 7: Run /vision-init with Original Prompt

Pass the original natural language prompt into the full Vision pipeline:

```javascript
console.log('🚀 Running Vision Init with your original prompt...');
console.log('   This is the deep analysis phase: PRD, competitive analysis, architecture, planning');

// The /vision-init command handles the full pipeline:
//
// Step 1: Parse prompt → features, intent, technologies
// Step 1b: Check existing visions (will be empty for new project)
// Step 1c: Decision engine → determine plan type
// Step 2: Initialize orchestrator → create VISION.json
// Step 2b: Generate PRD
// Step 2c: Deep competitive feature extraction (MANDATORY web search)
//   - 3+ web searches for comparable apps
//   - Top 5 competitor feature page extraction
//   - Feature matrix with frequency analysis
//   - User asked about feature enrichment
// Step 3: Tool & dependency analysis
// Step 4: Architecture generation (diagrams, components, API contracts)
// Step 4b: HTML mockup preview (if frontend detected)
// Step 5: Security scan
// Step 6: Planning hierarchy (EPIC.json → ROADMAP.json → PROGRESS.json)
// Step 7: Create agents
// Step 8: Session restart check
// Step 9: Summary
//
// Pass these values from Step 1:
//   - userPrompt (the original natural language prompt)
//   - projectName (for the vision title)
//   - tags (for vision metadata)
//   - priority (for vision priority)

// Invoke /vision-init with the gathered input.
// Use: Skill tool to invoke /vision-init
// OR: Follow the vision-init template instructions inline,
//     starting from Step 1c (skip input gathering — we already have it).
```

**Files created by /vision-init:**
```
.claude/visions/{slug}/
├── VISION.json
└── competitive-analysis.json

.claude/epics/{slug}/
└── EPIC.json

.claude/roadmaps/{slug}-roadmap-{n}/
├── ROADMAP.json
└── exploration/
    ├── EXPLORATION_SUMMARY.md
    ├── CODE_SNIPPETS.md
    ├── REFERENCE_FILES.md
    ├── AGENT_DELEGATION.md
    ├── PHASE_BREAKDOWN.md
    └── findings.json

.claude/phase-plans/{slug}-roadmap-{n}-phase-{m}/
└── PROGRESS.json
```

### Step 8: Final Summary + Session Restart

Display comprehensive summary of everything created:

```
╔════════════════════════════════════════════════════════════════════════╗
║             NEW PRODUCT CREATED SUCCESSFULLY! 🚀                       ║
╠════════════════════════════════════════════════════════════════════════╣
║                                                                        ║
║  Product: {{projectName}}                                              ║
║  Slug: {{slug}}                                                        ║
║  Path: {{projectPath}}                                                 ║
║                                                                        ║
╠════════════════════════════════════════════════════════════════════════╣
║  📁 Project Structure                                                  ║
╠════════════════════════════════════════════════════════════════════════╣
║                                                                        ║
║  Scaffold: {{scaffold.frontend || scaffold.backend}}                   ║
║  GitHub Repo: {{repoUrl || 'Not created'}}                             ║
║  CCASP: Installed + initialized (standard preset)                      ║
║  Tech Stack: .claude/config/tech-stack.json                            ║
║  Agents: .claude/agents/agents.json                                    ║
║                                                                        ║
╠════════════════════════════════════════════════════════════════════════╣
║  🔍 Vision Pipeline Results                                            ║
╠════════════════════════════════════════════════════════════════════════╣
║                                                                        ║
║  Vision: .claude/visions/{{visionSlug}}/VISION.json                    ║
║  Epic: .claude/epics/{{visionSlug}}/EPIC.json                          ║
║  Roadmaps: {{roadmapCount}} created                                    ║
║  Phase Plans: {{phasePlanCount}} created                               ║
║  GitHub Epic Issue: #{{epicIssueNumber || 'N/A'}}                      ║
║                                                                        ║
║  Competitive Analysis:                                                 ║
║    Apps Analyzed: {{competitiveAppsCount}}                              ║
║    Features Discovered: {{competitiveFeaturesCount}}                    ║
║                                                                        ║
║  Architecture:                                                         ║
║    Components: {{componentCount}}                                      ║
║    Diagrams: {{diagramCount}}                                          ║
║                                                                        ║
╠════════════════════════════════════════════════════════════════════════╣
║  ⚠️  SESSION RESTART REQUIRED                                           ║
╠════════════════════════════════════════════════════════════════════════╣
║                                                                        ║
║  Hooks and commands need activation in the new project directory.      ║
║                                                                        ║
║  Next steps:                                                           ║
║                                                                        ║
║  1. cd {{projectPath}}                                                 ║
║  2. Restart Claude Code CLI                                            ║
║  3. /vision-run {{visionSlug}}                                         ║
║                                                                        ║
║  Other useful commands after restart:                                   ║
║    /vision-status {{visionSlug}}    — Check vision status              ║
║    /vision-adjust {{visionSlug}}    — Adjust the plan                  ║
║    /roadmap-track                   — Track roadmap progress           ║
║    /feature-audit                   — Verify features after first phase║
║                                                                        ║
╚════════════════════════════════════════════════════════════════════════╝
```

---

## Error Handling

Each step checks success before proceeding. On failure:

1. **Log error details** with the failing command and output
2. **Offer recovery options** via AskUserQuestion:
   ```
   header: "Step Failed"
   question: "Step {{stepNumber}} ({{stepName}}) failed. How to proceed?"
   options:
     - label: "Retry"
       description: "Run this step again"
     - label: "Skip"
       description: "Skip this step and continue (may cause issues in later steps)"
     - label: "Abort"
       description: "Stop here — partial work preserved in {{projectPath}}"
   ```
3. **Never delete partial work** — the project directory and any completed steps are preserved
4. **Log step status** for debugging:
   ```javascript
   const stepLog = {
     step1_input: 'completed',
     step2_techstack: 'completed',
     step3_scaffold: 'failed',  // <-- this step failed
     step4_git: 'skipped',
     step5_ccasp: 'skipped',
     step6_projectimpl: 'skipped',
     step7_vision: 'skipped',
     step8_summary: 'skipped'
   };
   // Write to ~/Projects/{slug}/.claude/vision-new-product-log.json
   ```

## Argument Handling

- `/vision-new-product` — Interactive mode (default)
- `/vision-new-product {prompt}` — Quick start with prompt (still confirms tech stack)
- `/vision-new-product --name "My App"` — Pre-set project name
- `/vision-new-product --tags "saas,mvp"` — Pre-set tags
- `/vision-new-product --priority high` — Pre-set priority

## Validation Checklist

Before marking complete, verify:

```
[ ] User prompt collected and parsed
[ ] Project slug validated (no collision)
[ ] Tech stack detected from prompt
[ ] User confirmed or overrode tech stack
[ ] Project directory created at ~/Projects/{slug}/
[ ] Scaffolding command ran successfully
[ ] Git initialized with initial commit
[ ] GitHub private repo created (or graceful skip)
[ ] CCASP installed and initialized
[ ] /project-implementation-for-ccasp completed
    [ ] tech-stack.json generated
    [ ] agents.json generated
    [ ] CLAUDE.md created
[ ] /vision-init completed with original prompt
    [ ] VISION.json created
    [ ] Deep competitive feature extraction (Step 2c of vision-init)
    [ ] EPIC.json created
    [ ] ROADMAP.json(s) created
    [ ] PROGRESS.json(s) created
    [ ] GitHub epic issue created (if configured)
[ ] Final summary displayed
[ ] Session restart notice shown
```

## Related Commands

- `/vision-init` — Initialize vision for an existing project
- `/vision-run` — Start autonomous execution of a vision
- `/vision-status` — Check vision progress
- `/project-implementation-for-ccasp` — CCASP project setup (invoked internally)

---

*Vision New Product — Part of CCASP Vision Mode Autonomous Development Framework (Phase 7)*
