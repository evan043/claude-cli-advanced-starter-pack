---
description: Full-stack feature truth verification - audit what was actually built vs what was planned
options:
  - label: "Full Audit"
    description: "Verify all features against the codebase with truth table, confidence, and gaps"
  - label: "Gaps Only"
    description: "Show only gaps - recently completed but untested or low-confidence features"
  - label: "Generate Tests"
    description: "Auto-generate missing Playwright smoke tests and backend contract tests"
  - label: "Dashboard"
    description: "Run audit then open Feature Truth tab in the site-intel dashboard"
---

# Feature Audit - Full-Stack Truth Verification

Verify what was ACTUALLY built against what was PLANNED. Maps the CCASP planning hierarchy (Epic → Roadmap → Phase → Task) to verifiable features and checks 6 truth dimensions per feature.

## Arguments

- `/feature-audit` — Full audit (default: Full Audit)
- `/feature-audit --feature "auth"` — Audit a single feature by name
- `/feature-audit --gaps-only` — Show only gaps (recently completed but untested)
- `/feature-audit --generate-tests` — Auto-generate missing smoke + contract tests
- `/feature-audit --dashboard` — Run audit then open dashboard to Feature Truth tab
- `/feature-audit --roadmap <slug>` — Filter to specific roadmap

## What It Verifies (6 Truth Dimensions)

| Dimension | Points | What It Checks |
|-----------|--------|----------------|
| UI Exists | 20 | Route in catalog + component file on disk |
| Backend Exists | 20 | API endpoint in backend routers |
| API Wired | 20 | Frontend code references backend endpoint |
| Data Persists | 15 | Database model/migration exists |
| Permissions | 15 | Auth middleware on endpoint |
| Error Handling | 15 | Error boundaries, try-catch, error toasts |
| Smoke Test | +5 | Existing Playwright test covers this feature |
| Contract Test | +5 | Existing backend contract test covers this API |

**Max Score: 115 (before recency multiplier)**

### Recency Multiplier
- 0-7 days since completion: **1.2x**
- 8-14 days: **1.1x**
- 15-30 days: **1.0x**
- 31+ days: **0.9x**

### Confidence Levels
- **High**: ≥ 85
- **Medium**: 60-84
- **Low**: < 60

## Instructions

### Step 1: Parse Arguments

```javascript
const args = '$ARGUMENTS'.trim();
const gapsOnly = args.includes('--gaps-only');
const generateTests = args.includes('--generate-tests');
const openDashboard = args.includes('--dashboard');
const featureFilter = args.match(/--feature\s+"([^"]+)"/)?.[1] || null;
const roadmapFilter = args.match(/--roadmap\s+(\S+)/)?.[1] || null;
```

If no arguments and user selected an option:
- "Full Audit" → run full audit
- "Gaps Only" → set gapsOnly = true
- "Generate Tests" → set generateTests = true
- "Dashboard" → set openDashboard = true

### Step 2: Run Feature Audit

```javascript
import { runFeatureAudit } from '${CWD}/node_modules/claude-cli-advanced-starter-pack/src/site-intel/feature-audit/index.js';

const projectRoot = '${CWD}';
const result = await runFeatureAudit(projectRoot, {
  epicSlug: null,
  roadmapSlug: roadmapFilter,
  generateTests: generateTests,
});
```

### Step 3: Display Results

If no features found:
```
╔══════════════════════════════════════════════════════════════╗
║  FEATURE AUDIT - No Features Found                          ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  No planning hierarchy detected.                             ║
║  Run one of these first to create trackable features:        ║
║                                                              ║
║    /vision-init   — Full autonomous MVP from prompt           ║
║    /phase-dev-plan — Phased development plan                  ║
║    /create-roadmap — Multi-phase roadmap                      ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

If features found, display the Feature Truth Table:

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  FEATURE AUDIT REPORT                                                       ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  Features: {{summary.total_features}}                                        ║
║  Fully Verified: {{summary.fully_verified}}                                  ║
║  Gaps Found: {{summary.gaps_found}} ({{summary.high_priority_gaps}} high)    ║
║  Avg Confidence: {{summary.average_confidence}}                              ║
╠══════════════════════════════════════════════════════════════════════════════╣

FEATURE TRUTH TABLE
┌─────────────────────────────┬────┬─────┬─────┬──────┬──────┬───────┬───────┐
│ Feature                     │ UI │ API │Wire │ Data │ Auth │ Error │ Score │
├─────────────────────────────┼────┼─────┼─────┼──────┼──────┼───────┼───────┤
{{#each features}}
│ {{padRight name 27}}        │ {{icon truth_table.ui_exists.verified}}  │ {{icon truth_table.backend_exists.verified}}   │ {{icon truth_table.api_wired.verified}}   │ {{icon truth_table.data_persists.verified}}    │ {{icon truth_table.permissions.verified}}    │ {{icon truth_table.error_handling.verified}}     │ {{padLeft confidence.final_score 5}} │
{{/each}}
└─────────────────────────────┴────┴─────┴─────┴──────┴──────┴───────┴───────┘

Legend:  ✅ = Verified   ❌ = Not Found   ❓ = Unknown
```

**Display each feature row** using these icons:
- `true` → ✅
- `false` → ❌
- `undefined/null` → ❓

**Color the confidence score:**
- High (≥85): GREEN
- Medium (60-84): YELLOW
- Low (<60): RED

### Step 4: Display Gaps (if any)

```
╠══════════════════════════════════════════════════════════════════════════════╣
║  GAPS ({{gaps.length}} found)                                                ║
╠══════════════════════════════════════════════════════════════════════════════╣
{{#each gaps}}
║  [{{priority}}] {{feature_name}}                                              ║
║    Type: {{gap_type}}                                                         ║
║    Reason: {{reason}}                                                         ║
{{#each actions}}
║    → {{description}}                                                          ║
{{/each}}
║                                                                              ║
{{/each}}
```

### Step 5: Show Generated Tests (if --generate-tests)

If test generation was requested, show what was generated:

```
╠══════════════════════════════════════════════════════════════════════════════╣
║  GENERATED TESTS                                                             ║
╠══════════════════════════════════════════════════════════════════════════════╣
{{#each generatedTests}}
║  {{#if written}}✅{{else}}❌{{/if}} {{feature_name}}                         ║
║    File: {{testFilePath}}                                                     ║
║    Endpoint: {{endpoint.method}} {{endpoint.path}}                            ║
{{/each}}
╚══════════════════════════════════════════════════════════════════════════════╝
```

### Step 6: Dashboard (if --dashboard)

If dashboard was requested:

```javascript
import { startDashboard } from '${CWD}/node_modules/claude-cli-advanced-starter-pack/src/site-intel/dashboard/index.js';

const server = await startDashboard({ projectRoot: '${CWD}', port: 3847 });
console.log('Dashboard running at http://localhost:3847');
console.log('Open the "Feature Truth" tab to explore results.');
```

### Step 7: Next Steps

Always show recommended next steps:

```
╠══════════════════════════════════════════════════════════════════════════════╣
║  NEXT STEPS                                                                  ║
╠══════════════════════════════════════════════════════════════════════════════╣
{{#if (gt summary.high_priority_gaps 0)}}
║  ⚠️  {{summary.high_priority_gaps}} HIGH-PRIORITY gaps need attention:        ║
║     /feature-audit --gaps-only          View all gaps                         ║
║     /feature-audit --generate-tests     Auto-generate missing tests           ║
{{/if}}
║  /feature-audit --dashboard             View Feature Truth tab                ║
║  /create-smoke-test                      Generate Playwright smoke tests      ║
║  /site-intel dev-scan                   Run full dev scan for route health    ║
╚══════════════════════════════════════════════════════════════════════════════╝
```
