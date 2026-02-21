<!-- CCASP-CODEX-COMPAT:START -->
# Codex Runtime Compatibility

This prompt was authored for Claude-style slash workflows. In Codex runtime, adapt tool calls as follows:
- `AskUserQuestion` => ask the user directly in chat.
- `WebSearch`/`WebFetch` => use available web tools (`search_query`, `open`, `find`) and cite links.
- `Read`/`Write` => use shell/filesystem tools in this workspace.
- Claude-only MCP calls (for example Playwright MCP names) => use available equivalents or clearly state fallback.
- Keep intent and output format identical; only adapt execution mechanics.
<!-- CCASP-CODEX-COMPAT:END -->
<!-- CODEX-OVERRIDE:START -->
# vision-status — Codex Runtime

Check the status of your current Vision.

```bash
# Check vision progress files
cat .claude/visions/*/PROGRESS.json 2>/dev/null || echo "No visions found"

# List all visions
ls .claude/visions/ 2>/dev/null || echo "No .claude/visions directory"
```

I'll read and summarize the vision status from your local files.
<!-- CODEX-OVERRIDE:END -->
---
description: View Vision status, progress, and alignment metrics
options:
  - label: "All Visions"
    description: "List all Visions with summary"
  - label: "Specific Vision"
    description: "Detailed status for one Vision"
  - label: "Quick Status"
    description: "Compact view with key metrics only"
---

# Vision Status - Progress & Alignment Dashboard

Display comprehensive status for Visions including orchestrator stage, roadmap progress, drift events, security scans, and agent status.

**Vision Architecture:**
```
VISION (L0+) → EPIC (L0) → ROADMAP (L1) → PHASE-DEV (L2) → TASKS (L3)
```

---

## Execution Protocol

### Step 1: Load Vision Data

```javascript
import { listVisions, loadVision, getVisionStatus, getRegisteredVisions, getVisionCount, describePlanType } from '${CWD}/node_modules/claude-cli-advanced-starter-pack/src/vision/index.js';

const visionSlug = args[0];

if (!visionSlug) {
  // Use registry for fast listing (falls back to filesystem)
  let visions;
  try {
    visions = getRegisteredVisions(projectRoot);
  } catch {
    visions = listVisions(projectRoot);
  }

  if (visions.length === 0) {
    console.log('No Visions found. Create one with /vision-init');
    return;
  }

  const { total, active } = getVisionCount(projectRoot);
  console.log(`Total: ${total} vision(s), ${active} active\n`);

  // Display summary for each, including plan type
  for (const v of visions) {
    const status = getVisionStatus(projectRoot, v.slug);
    const planType = v.plan_type || 'unknown';
    const planLabel = planType !== 'unknown' ? describePlanType(planType).label : 'Unknown';
    // Display with plan type indicator...
  }
} else {
  // Load specific vision
  const vision = await loadVision(projectRoot, visionSlug);
  const status = getVisionStatus(projectRoot, visionSlug);
  const planType = vision.plan_type || vision.decision?.planType || 'unknown';
  const planLabel = planType !== 'unknown' ? describePlanType(planType).label : 'Unknown';
  // Display detailed status with plan type...
}
```

### Step 2: List All Visions (Default)

```
╔═══════════════════════════════════════════════════════════════════════════╗
║                         VISION MODE DASHBOARD                              ║
╠═══════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  Visions: {{total}} total, {{active}} active                                ║
║                                                                             ║
╠═══════════════════════════════════════════════════════════════════════════╣
{{#each visions}}
║                                                                             ║
║  🚀 {{title}} ({{slug}})                                                    ║
║  ────────────────────────────────────────────────────────────────────────── ║
║                                                                             ║
║  Status: {{statusEmoji}} {{status}}                                         ║
║  Plan Type: {{planLabel}} ({{planType}})                                    ║
║  Stage: {{orchestrator.stage}}                                              ║
║  Progress: [{{progressBar}}] {{completion_percentage}}%                     ║
║  Alignment: [{{alignmentBar}}] {{alignmentPct}}%                            ║
║  Priority: {{priorityBadge}}                                                ║
║                                                                             ║
║  Quick Actions:                                                             ║
║    • /vision-status {{slug}} - View details                                 ║
║    • /vision-run {{slug}} - Execute                                         ║
║    • /vision-adjust {{slug}} - Adjust plan                                  ║
║                                                                             ║
{{/each}}
╚═══════════════════════════════════════════════════════════════════════════╝
```

**Status Emoji Legend:**

| Status | Emoji | Description |
|--------|-------|-------------|
| not_started | 📝 | Vision created, not yet executing |
| analyzing | 🔍 | Running analysis phase |
| architecting | 🏗️ | Generating architecture |
| orchestrating | 🎭 | Creating roadmaps and agents |
| executing | ⚡ | Autonomous execution in progress |
| validating | ✅ | Running tests and verification |
| completed | 🎉 | MVP complete |
| failed | ❌ | Execution failed |
| paused | ⏸️ | Paused for manual review |

### Step 3: Detailed Vision Status

```
╔════════════════════════════════════════════════════════════════════════════╗
║                          VISION STATUS REPORT                               ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  {{title}}                                                                  ║
║  Slug: {{slug}}                                                             ║
║  Status: {{statusEmoji}} {{status}}                                         ║
║  Plan Type: {{planLabel}} ({{planType}})                                    ║
║  Priority: {{priorityBadge}}                                                ║
║                                                                             ║
║  Progress: [{{progressBar}}] {{completion_percentage}}%                     ║
║  Alignment: [{{alignmentBar}}] {{alignmentPct}}%                            ║
║                                                                             ║
╠════════════════════════════════════════════════════════════════════════════╣
║  🎛️ Orchestrator                                                            ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  Current Stage: {{orchestrator.stage}}                                      ║
║  Stage History: {{orchestrator.stage_history.length}} transitions           ║
║                                                                             ║
║  Stages Completed:                                                          ║
{{#each stageHistory}}
║    {{#if completed}}✓{{else}}○{{/if}} {{stage}}                             ║
{{/each}}
║                                                                             ║
╠════════════════════════════════════════════════════════════════════════════╣
║  💭 Original Vision                                                         ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  {{prompt.original}}                                                        ║
║                                                                             ║
║  Intent: {{prompt.intent}}                                                  ║
║  Complexity: {{metadata.estimated_complexity}}                              ║
║  Features: {{metadata.features.length}}                                     ║
║                                                                             ║
╠════════════════════════════════════════════════════════════════════════════╣
║  📊 Analysis Results                                                        ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  Similar Apps: {{analysis.similarApps.length}}                              ║
║  NPM Packages: {{analysis.npmPackages.length}}                              ║
║  PIP Packages: {{analysis.pipPackages.length}}                              ║
║  MCP Servers: {{analysis.mcpServers.length}}                                ║
║  Tool Recommendations: {{analysis.toolRecommendations.length}}              ║
║                                                                             ║
╠════════════════════════════════════════════════════════════════════════════╣
║  🏗️ Architecture                                                            ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  Diagrams: {{architecture.diagrams | keys | length}}                        ║
║  Components: {{architecture.componentList.length}}                          ║
║  API Endpoints: {{architecture.apiContracts ? 'Generated' : 'None'}}        ║
║  State Stores: {{architecture.stateDesign?.stores.length || 0}}             ║
║                                                                             ║
╠════════════════════════════════════════════════════════════════════════════╣
║  🗺️ Roadmaps                                                                ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  Total: {{execution_plan.roadmaps.length}}                                  ║
║  Completed: {{roadmaps_completed}}                                          ║
║  In Progress: {{roadmaps_in_progress}}                                      ║
║  Pending: {{roadmaps_pending}}                                              ║
║                                                                             ║
{{#each execution_plan.roadmaps}}
║  {{order}}. {{title}}                                                       ║
║     Status: {{statusBadge}} | Progress: {{completion_percentage}}%          ║
║                                                                             ║
{{/each}}
╠════════════════════════════════════════════════════════════════════════════╣
║  🤖 Agents                                                                  ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
{{#if agents.length}}
{{#each agents}}
║  • {{domain}}: {{name}} ({{status}})                                        ║
{{/each}}
{{else}}
║  No agents created yet.                                                     ║
{{/if}}
║                                                                             ║
╠════════════════════════════════════════════════════════════════════════════╣
║  👁️ Observer                                                                ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  Current Alignment: [{{alignmentBar}}] {{alignmentPct}}%                    ║
║  Drift Events: {{observer.drift_events.length}}                             ║
║  Adjustments Made: {{observer.adjustments_made}}                            ║
║                                                                             ║
{{#if (lt observer.current_alignment 0.9)}}
║  ⚠️ ALIGNMENT BELOW TARGET (90%)                                            ║
║     Consider running /vision-adjust {{slug}}                                ║
║                                                                             ║
{{/if}}
{{#if observer.drift_events.length}}
║  Recent Drift:                                                              ║
{{#each observer.drift_events (limit 3)}}
║    • {{detected_at}}: {{area}} ({{severity}})                               ║
{{/each}}
║                                                                             ║
{{/if}}
╠════════════════════════════════════════════════════════════════════════════╣
║  🛡️ Security                                                                ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  Last Scan: {{security.lastScan || 'Never'}}                                ║
║  Vulnerabilities: {{security.vulnerabilityCount || 0}}                      ║
║  Blocked Packages: {{security.blockedPackages.length || 0}}                 ║
║                                                                             ║
{{#if security.blockedPackages.length}}
║  Blocked:                                                                   ║
{{#each security.blockedPackages (limit 3)}}
║    • {{name}}: {{severity}}                                                 ║
{{/each}}
║                                                                             ║
{{/if}}
╠════════════════════════════════════════════════════════════════════════════╣
║  📅 Timeline                                                                ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  Created: {{created_at}}                                                    ║
║  Updated: {{updated_at}}                                                    ║
║  Duration: {{duration}}                                                     ║
║                                                                             ║
╠════════════════════════════════════════════════════════════════════════════╣
║  📋 Next Actions                                                            ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
{{#if (eq status 'not_started')}}
║  → Start execution: /vision-run {{slug}}                                    ║
{{else if (eq status 'analyzing')}}
║  → Analysis in progress, wait for completion                                ║
{{else if (eq status 'architecting')}}
║  → Architecture generation in progress                                      ║
{{else if (eq status 'orchestrating')}}
║  → Ready to execute: /vision-run {{slug}}                                   ║
{{else if (eq status 'executing')}}
║  → Execution in progress                                                    ║
║  → Monitor or pause: /vision-pause {{slug}}                                 ║
{{else if (eq status 'validating')}}
║  → Validation in progress                                                   ║
{{else if (eq status 'completed')}}
║  → Vision completed! Review output                                          ║
{{else if (eq status 'paused')}}
║  → Resume: /vision-run {{slug}}                                             ║
║  → Adjust: /vision-adjust {{slug}}                                          ║
{{else if (eq status 'failed')}}
║  → Review errors and adjust: /vision-adjust {{slug}}                        ║
║  → Retry: /vision-run {{slug}}                                              ║
{{/if}}
║                                                                             ║
╠════════════════════════════════════════════════════════════════════════════╣
║  📁 Files                                                                   ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                             ║
║  Vision: .claude/visions/{{slug}}/VISION.json                               ║
{{#if checkpoints.length}}
║  Checkpoints: {{checkpoints.length}}                                        ║
{{/if}}
║                                                                             ║
╚════════════════════════════════════════════════════════════════════════════╝
```

### Step 4: Quick Status Mode

For `--quick` flag:

```
╔═══════════════════════════════════════════════════════════════╗
║  VISION: {{title}}                                            ║
╠═══════════════════════════════════════════════════════════════╣
║  Status: {{status}} | Stage: {{stage}}                        ║
║  Progress: [{{progressBar}}] {{completion}}%                  ║
║  Alignment: {{alignment}}% | Drift: {{drift_count}}           ║
║  Roadmaps: {{completed}}/{{total}} | Security: {{vulns}}      ║
╠═══════════════════════════════════════════════════════════════╣
║  Next: {{next_action}}                                        ║
╚═══════════════════════════════════════════════════════════════╝
```

### Step 5: JSON Output Mode

For `--json` flag:

```javascript
const status = getVisionStatus(projectRoot, visionSlug);
const vision = await loadVision(projectRoot, visionSlug);

const output = {
  slug: vision.slug,
  title: vision.title,
  status: vision.status,
  orchestrator: {
    stage: vision.orchestrator?.stage,
    stage_count: vision.orchestrator?.stage_history?.length || 0
  },
  completion_percentage: status.completion_percentage,
  alignment: status.observer?.current_alignment || 1.0,
  roadmaps: {
    total: status.roadmaps?.total || 0,
    completed: status.roadmaps?.completed || 0,
    in_progress: status.roadmaps?.in_progress || 0,
    pending: status.roadmaps?.pending || 0
  },
  observer: {
    drift_events: status.observer?.drift_events || 0,
    adjustments: status.observer?.adjustments || 0
  },
  security: {
    vulnerabilities: vision.security?.vulnerabilityCount || 0,
    blocked: vision.security?.blockedPackages?.length || 0
  },
  agents: vision.agents?.length || 0,
  created: vision.created_at,
  updated: vision.updated_at
};

console.log(JSON.stringify(output, null, 2));
```

## CLI Alternative

```bash
# List all visions
ccasp vision list

# Status of specific vision
ccasp vision status <slug>

# Quick status
ccasp vision status <slug> --quick

# JSON output
ccasp vision status <slug> --json
```

## Argument Handling

- `/vision-status` - List all Visions
- `/vision-status {slug}` - Detailed status
- `/vision-status {slug} --quick` - Compact view
- `/vision-status {slug} --json` - JSON output

## Helper Functions

```javascript
// Generate progress bar
function generateProgressBar(percentage, width = 20) {
  const filled = Math.round((percentage / 100) * width);
  const empty = width - filled;
  return '█'.repeat(filled) + '░'.repeat(empty);
}

// Get status emoji
function getStatusEmoji(status) {
  const emojis = {
    not_started: '📝',
    analyzing: '🔍',
    architecting: '🏗️',
    orchestrating: '🎭',
    executing: '⚡',
    validating: '✅',
    completed: '🎉',
    failed: '❌',
    paused: '⏸️'
  };
  return emojis[status] || '❓';
}

// Calculate duration
function calculateDuration(start, end = new Date()) {
  const diff = new Date(end) - new Date(start);
  const hours = Math.floor(diff / (1000 * 60 * 60));
  const days = Math.floor(hours / 24);

  if (days > 0) return `${days}d ${hours % 24}h`;
  if (hours > 0) return `${hours}h`;
  return 'Less than 1h';
}
```

## Related Commands

- `/vision-init` - Initialize new Vision
- `/vision-run` - Start execution
- `/vision-adjust` - Adjust Vision plan
- `/roadmap-track` - Track specific roadmap
- `ccasp vision list` - List all visions with plan types
- `ccasp vision cleanup` - Remove stale/failed visions

---

*Vision Status - Part of CCASP Vision Mode Autonomous Development Framework (Phase 7)*
