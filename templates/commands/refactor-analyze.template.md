---
description: Deep complexity analysis for refactoring prioritization with dependency tracing
model: sonnet
argument-hint: [file path, directory, or 'all']
---

# /refactor-analyze - Code Complexity Analysis

Analyze code complexity, detect code smells, and prioritize refactoring candidates with metrics-driven recommendations. **Now with dependency tracing and global scanning.**

## Quick Start

```bash
/refactor-analyze                     # Interactive mode - choose options
/refactor-analyze src/api/            # Analyze specific directory
/refactor-analyze src/api/client.ts   # Analyze single file
/refactor-analyze --top 10            # Show top 10 worst files
/refactor-analyze --trace-imports     # Trace full import dependency tree
/refactor-analyze --global-scan       # Find ALL large files (not just flagged)
/refactor-analyze --threshold 1000    # Custom line threshold (default: 500)
```

## Instructions for Claude

When `/refactor-analyze` is invoked, **ALWAYS start with Step 0** to present interactive options.

### Step 0: Present Interactive Options (REQUIRED)

**Use AskUserQuestion to let the user configure the analysis:**

```
questions:
  - header: "Analysis Mode"
    question: "What type of analysis do you want to run?"
    multiSelect: false
    options:
      - label: "Standard Analysis (Recommended)"
        description: "Analyze flagged files (>500 lines) with basic metrics"
      - label: "Deep Analysis + Import Tracing"
        description: "Trace full dependency tree for each file - discovers hidden large dependencies"
      - label: "Global Scan"
        description: "Find ALL files above threshold regardless of page association"
      - label: "Comprehensive (All Features)"
        description: "Global scan + import tracing + orphan detection"

  - header: "Line Threshold"
    question: "What line count threshold should trigger analysis?"
    multiSelect: false
    options:
      - label: "500 lines (Standard)"
        description: "Default threshold - catches most problem files"
      - label: "1000 lines (Large files only)"
        description: "Focus on the biggest offenders first"
      - label: "2000 lines (Critical only)"
        description: "Only truly massive files needing immediate attention"
      - label: "300 lines (Strict)"
        description: "More aggressive - catch problems earlier"

  - header: "Output Format"
    question: "How should results be organized?"
    multiSelect: false
    options:
      - label: "By Priority Score (Recommended)"
        description: "Rank all files by refactoring urgency"
      - label: "By Page/Route"
        description: "Group files by their consuming page entry points"
      - label: "By Discovery Method"
        description: "Separate direct flags, import traces, and global scan results"
```

**Then ask about report generation:**

```
questions:
  - header: "Report Output"
    question: "Do you want to generate a comprehensive file-based report?"
    multiSelect: false
    options:
      - label: "Yes - Full Report (Recommended for /create-roadmap)"
        description: "Generate organized folder structure with per-page analysis, YAML configs, and fix ordering"
      - label: "No - JSON Only"
        description: "Just output to .claude/refactor-analysis.json (quick analysis)"
```

**Based on user selections, set these flags internally:**
- `traceImports`: true if "Deep Analysis" or "Comprehensive" selected
- `globalScan`: true if "Global Scan" or "Comprehensive" selected
- `threshold`: 500, 1000, 2000, or 300 based on selection
- `groupBy`: "priority", "page", or "discovery"
- `generateFullReport`: true if "Yes - Full Report" selected

## Analysis Modes

| Mode | Flag | Description |
|------|------|-------------|
| **Standard** | (default) | Analyze flagged files >500 lines with basic metrics |
| **Import Tracing** | `--trace-imports` | Build full dependency graph for each file |
| **Global Scan** | `--global-scan` | Find ALL large files, not just page entry points |
| **Comprehensive** | both flags | Global scan + import tracing + orphan detection |

### Discovery Methods

| Method | What It Finds | Why It Matters |
|--------|---------------|----------------|
| **Direct Flag** | Files exceeding threshold | Standard detection - page entry points |
| **Global Scan** | Large utilities, adapters, templates | Finds files MISSED by page-based scanning |
| **Import Trace** | Large stores, APIs, services | Reveals hidden dependencies of pages |

### File Tiers

| Tier | Line Count | Priority | Action |
|------|------------|----------|--------|
| **Critical** | >2000 lines | P0 | Immediate refactoring required |
| **High** | 1000-2000 lines | P1 | Schedule for refactoring |
| **Medium** | 500-1000 lines | P2 | Preventive refactoring |
| **Healthy** | <500 lines | - | No action needed |

## Metrics Calculated

### Complexity Metrics

| Metric | Description | Threshold |
|--------|-------------|-----------|
| **Cyclomatic Complexity** | Control flow paths (testability) | >10 = needs refactoring |
| **Cognitive Complexity** | Mental effort to understand | >15 = needs refactoring |
| **Lines of Code (LOC)** | File/function size | >500 file, >50 function |
| **Nesting Depth** | Maximum indentation levels | >4 = needs flattening |
| **Parameter Count** | Function parameters | >5 = needs parameter object |

### Code Smell Detection

| Smell | Detection Criteria | Refactoring Pattern |
|-------|---------------------|---------------------|
| **Long Method** | LOC > 30, Cyclomatic > 10 | Extract Method |
| **Large Class/Module** | LOC > 500, Methods > 20 | Extract Class/Module |
| **Deep Nesting** | Depth > 4 | Early Return, Extract Method |
| **God Object** | High coupling, many responsibilities | Single Responsibility Split |
| **Feature Envy** | Uses external data > internal | Move Method |
| **Duplicate Code** | Similar blocks > 6 lines | Extract Function |
| **Long Parameter List** | Params > 5 | Parameter Object |

### Coupling Metrics

| Metric | Description | Risk Level |
|--------|-------------|------------|
| **Afferent Coupling (Ca)** | External dependents | High = painful to change |
| **Efferent Coupling (Ce)** | External dependencies | High = fragile |
| **Instability (I)** | Ce / (Ce + Ca) | 1 = unstable |

### Dependency Metrics (with --trace-imports)

| Metric | Description | Insight |
|--------|-------------|---------|
| **Import Depth** | How deep in the import chain | Deep = harder to refactor |
| **Reverse Dependents** | Files that import this one | High = refactoring affects many |
| **Page Coupling** | Which route pages use this file | Maps file to user-facing feature |
| **Orphan Status** | No imports detected | Possible dead code candidate |

## Output Format

### Summary View (Default)

```
╔═══════════════════════════════════════════════════════════════╗
║  📊 Refactor Analysis - Code Health Report                     ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Files Analyzed: 142                                          ║
║  Refactoring Candidates: 23 (16%)                             ║
║  Critical Issues: 5                                           ║
║  Overall Health Score: 67/100 (Fair)                          ║
║                                                               ║
╠═══════════════════════════════════════════════════════════════╣
║  Top Refactoring Priorities                                   ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  1. src/api/client.ts                                         ║
║     • Lines: 847 | Cyclomatic: 47 | Cognitive: 62            ║
║     • Smells: Long Methods (3), Deep Nesting (2)              ║
║     • Recommended: Extract Service, Split by Domain           ║
║     • Priority Score: 94/100                                  ║
║                                                               ║
║  2. src/components/Dashboard.tsx                              ║
║     • Lines: 623 | Cyclomatic: 31 | Cognitive: 45            ║
║     • Smells: Large Component, Feature Envy                   ║
║     • Recommended: Extract Components, Custom Hooks           ║
║     • Priority Score: 87/100                                  ║
║                                                               ║
║  3. src/utils/helpers.ts                                      ║
║     • Lines: 456 | Duplication: 34%                           ║
║     • Smells: Duplicate Code, Utility Dumping Ground          ║
║     • Recommended: Split by Domain, Extract Shared            ║
║     • Priority Score: 79/100                                  ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

### Detailed View (--verbose)

```json
{
  "timestamp": "2026-02-04T12:00:00Z",
  "scope": "all",
  "flags": {
    "globalScan": true,
    "traceImports": true,
    "threshold": 500
  },
  "summary": {
    "filesAnalyzed": 347,
    "refactoringCandidates": 52,
    "criticalIssues": 8,
    "healthScore": 62,
    "healthGrade": "C",
    "discoveryBreakdown": {
      "directFlag": 23,
      "globalScan": 18,
      "importTrace": 11
    }
  },
  "hotspots": [
    {
      "rank": 1,
      "file": "src/store/epgStore.ts",
      "discoveredBy": ["directFlag", "importTrace"],
      "tier": "critical",
      "metrics": {
        "loc": 3123,
        "cyclomaticComplexity": 67,
        "cognitiveComplexity": 89,
        "maxNestingDepth": 6,
        "afferentCoupling": 18,
        "efferentCoupling": 12,
        "instability": 0.4,
        "duplicationPercentage": 5
      },
      "dependencies": {
        "imports": ["axios", "zustand", "./types"],
        "importedBy": [
          {
            "file": "src/pages/EPGViewPage.tsx",
            "instances": 12,
            "type": "store-consumer"
          },
          {
            "file": "src/components/EventCard.tsx",
            "instances": 8,
            "type": "store-consumer"
          }
        ],
        "dependencyDepth": 2,
        "totalDependents": 18
      },
      "smells": [
        {
          "type": "large_file",
          "severity": "critical",
          "message": "File exceeds 3000 lines - consider splitting by domain"
        },
        {
          "type": "high_coupling",
          "severity": "high",
          "message": "18 files depend on this store - changes impact many components"
        }
      ],
      "recommendations": [
        {
          "pattern": "split_by_domain",
          "description": "Split into epgEventStore.ts, epgScheduleStore.ts, epgSearchStore.ts",
          "affectedDependents": 18,
          "estimatedImpact": "high"
        }
      ],
      "priorityScore": 94
    }
  ],
  "groupedByDiscoveryMethod": {
    "directFlag": [
      {
        "file": "src/pages/HandwryttenExportView.tsx",
        "lines": 1372,
        "tier": "high",
        "reason": "Exceeded 500-line threshold"
      }
    ],
    "globalScan": [
      {
        "file": "src/utils/usiEventEmailTemplate.ts",
        "lines": 4474,
        "tier": "critical",
        "reason": "Found by exhaustive scan - exceeds 2000 lines",
        "importedByPages": false
      }
    ],
    "importTrace": [
      {
        "file": "src/services/SelfHostedSocketAdapter.ts",
        "lines": 3751,
        "tier": "critical",
        "discoveredVia": "src/pages/LiveStreamPage.tsx",
        "pathLength": 2,
        "reason": "Dependency of page entry point"
      }
    ]
  },
  "groupedByPage": {
    "epg": {
      "entryPoint": "src/pages/EPGViewPage.tsx",
      "entryPointLines": 245,
      "dependencies": [
        { "path": "src/store/epgStore.ts", "lines": 3123 },
        { "path": "src/api/epgApi.ts", "lines": 2033 },
        { "path": "src/components/EventsTableEditor.tsx", "lines": 2567 }
      ],
      "totalDependencyLines": 7968,
      "refactoringTargets": 3
    },
    "handwrytten": {
      "entryPoint": "src/pages/HandwryttenExportView.tsx",
      "entryPointLines": 1372,
      "dependencies": [],
      "totalDependencyLines": 1372,
      "refactoringTargets": 1
    }
  },
  "orphanedFiles": [
    {
      "file": "src/utils/legacyHelpers.ts",
      "lines": 2100,
      "importCount": 0,
      "exportCount": 15,
      "status": "no-imports-detected",
      "recommendation": "Review for removal - possible dead code"
    }
  ],
  "aggregateMetrics": {
    "avgCyclomaticComplexity": 12.3,
    "avgCognitiveComplexity": 18.7,
    "totalDuplication": 2847,
    "couplingHotspots": 8
  }
}
```

### Step 1: Determine Scope

1. If specific file: Analyze that file only
2. If directory: Analyze all source files recursively
3. If 'all' or no argument: Use flagged files from `.claude/refactor-audit.json`, or scan entire project

### Step 1.5: Global Scan (if enabled)

**When `globalScan` is true**, perform exhaustive file discovery:

```bash
# Find ALL source files and their line counts
find . -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" |
  grep -v node_modules | grep -v dist | grep -v build |
  xargs wc -l | sort -rn
```

**Categorize files into tiers:**

| Tier | Line Count | Priority | Action |
|------|------------|----------|--------|
| **Critical (Tier 1)** | >2000 lines | P0 | Immediate refactoring required |
| **High (Tier 2)** | 1000-2000 lines | P1 | Schedule for refactoring |
| **Medium (Tier 3)** | 500-1000 lines | P2 | Preventive refactoring |
| **Healthy (Tier 4)** | <500 lines | - | No action needed |

**Track discovery method for each file:**
```javascript
file.discoveryMethod = "global-scan"  // Found by exhaustive scan
file.tier = determineTier(file.loc)
```

### Step 1.6: Import Tracing (if enabled)

**When `traceImports` is true**, build a dependency graph:

```javascript
// For each flagged/scanned file, trace its import tree
function traceImports(filePath, visited = new Set()) {
  if (visited.has(filePath)) return [];
  visited.add(filePath);

  const content = readFile(filePath);
  const imports = parseImports(content);
  const dependencies = [];

  for (const imp of imports) {
    // Resolve relative imports to absolute paths
    const resolvedPath = resolveImport(imp, filePath);

    // Skip node_modules, only trace local files
    if (isLocalFile(resolvedPath)) {
      dependencies.push({
        path: resolvedPath,
        importedAs: imp.specifiers,
        importType: imp.type  // 'named', 'default', 'namespace'
      });

      // Recursively trace (with depth limit)
      dependencies.push(...traceImports(resolvedPath, visited));
    }
  }

  return dependencies;
}

// Parse import statements from file content
function parseImports(content) {
  const imports = [];

  // ES6 imports: import X from 'Y', import { X } from 'Y'
  const es6Regex = /import\s+(?:(\w+)|{([^}]+)}|\*\s+as\s+(\w+))?\s*(?:,\s*{([^}]+)})?\s*from\s*['"]([^'"]+)['"]/g;

  // Dynamic imports: import('Y')
  const dynamicRegex = /import\(['"]([^'"]+)['"]\)/g;

  // Require: const X = require('Y')
  const requireRegex = /require\(['"]([^'"]+)['"]\)/g;

  // Match all patterns and extract paths
  // ... extraction logic

  return imports;
}
```

**Build reverse dependency map (who imports this file?):**

```javascript
const reverseDepMap = {};  // file -> [files that import it]

for (const [file, deps] of Object.entries(dependencyMap)) {
  for (const dep of deps) {
    if (!reverseDepMap[dep.path]) {
      reverseDepMap[dep.path] = [];
    }
    reverseDepMap[dep.path].push({
      importedBy: file,
      instances: dep.importedAs.length
    });
  }
}
```

**Identify page entry points and their dependency trees:**

```javascript
// Find page entry points (files in pages/ or routes/ directories)
const pageEntryPoints = files.filter(f =>
  f.includes('/pages/') ||
  f.includes('/routes/') ||
  f.match(/Page\.tsx$/) ||
  f.match(/View\.tsx$/)
);

// For each page, build complete dependency tree
const pageDependencyTrees = {};
for (const page of pageEntryPoints) {
  pageDependencyTrees[page] = {
    entryPoint: page,
    dependencies: traceImports(page),
    totalDependencies: 0,
    largeDependencies: []  // Dependencies > threshold
  };

  // Flag large dependencies discovered via tracing
  for (const dep of pageDependencyTrees[page].dependencies) {
    if (getLineCount(dep.path) > threshold) {
      pageDependencyTrees[page].largeDependencies.push({
        path: dep.path,
        lines: getLineCount(dep.path),
        discoveryMethod: "import-trace"
      });
    }
  }
}
```

### Step 2: Calculate Metrics Per File

For each source file:

```javascript
// Pseudo-code for metrics calculation
const metrics = {
  loc: countLines(file),
  cyclomaticComplexity: countDecisionPoints(file) + 1,
  cognitiveComplexity: calculateCognitive(file), // Weighted nesting
  maxNestingDepth: findMaxIndentation(file),

  // Function-level
  functions: file.functions.map(fn => ({
    name: fn.name,
    loc: fn.lines,
    params: fn.parameters.length,
    cyclomatic: countDecisionPoints(fn),
    startLine: fn.start,
    endLine: fn.end
  })),

  // Dependencies (from imports)
  afferentCoupling: countImportedBy(file),
  efferentCoupling: countImports(file),
  instability: efferent / (efferent + afferent)
};
```

### Step 3: Detect Code Smells

Apply detection rules:

```javascript
const smells = [];

// Long Method
for (const fn of metrics.functions) {
  if (fn.loc > 30 || fn.cyclomatic > 10) {
    smells.push({
      type: 'long_method',
      location: `${fn.name}:${fn.startLine}-${fn.endLine}`,
      severity: fn.loc > 50 ? 'high' : 'medium'
    });
  }
}

// Deep Nesting
if (metrics.maxNestingDepth > 4) {
  smells.push({
    type: 'deep_nesting',
    severity: metrics.maxNestingDepth > 6 ? 'high' : 'medium'
  });
}

// Large File
if (metrics.loc > 500) {
  smells.push({
    type: 'large_file',
    severity: metrics.loc > 800 ? 'high' : 'medium'
  });
}

// Long Parameter List
for (const fn of metrics.functions) {
  if (fn.params > 5) {
    smells.push({
      type: 'long_parameter_list',
      location: fn.name,
      severity: fn.params > 7 ? 'high' : 'medium'
    });
  }
}
```

### Step 4: Calculate Priority Score

```javascript
// Priority Formula (0-100)
const priorityScore = Math.min(100, (
  (metrics.cyclomaticComplexity / 50) * 30 +  // 30% weight
  (metrics.cognitiveComplexity / 60) * 30 +   // 30% weight
  (metrics.efferentCoupling / 30) * 20 +      // 20% weight
  (changeFrequency === 'high' ? 20 :
   changeFrequency === 'medium' ? 10 : 0)     // 20% weight
));
```

### Step 5: Generate Recommendations

Based on detected smells and metrics, recommend specific refactoring patterns:

| Condition | Recommendation |
|-----------|----------------|
| Long methods + High coupling | Extract Service |
| Large file + Multiple domains | Split by Domain |
| Deep nesting | Early Returns, Extract Method |
| Long parameter list | Introduce Parameter Object |
| Duplicate code | Extract Shared Function |
| High efferent coupling | Dependency Injection |

{{#if agents.available}}
### Step 6: Recommend Specialist Agent

Based on file type and detected patterns:

| File Pattern | Recommended Agent |
|--------------|-------------------|
{{#if agents.frontend}}| `.tsx`, `.jsx`, `.vue` | {{agents.frontend.name}} |{{/if}}
{{#if agents.backend}}| `.py` (FastAPI), `.ts` (Express) | {{agents.backend.name}} |{{/if}}
{{#if agents.database}}| `.prisma`, migrations | {{agents.database.name}} |{{/if}}
{{/if}}

### Step 6.5: Detect Orphaned Files (if globalScan or traceImports enabled)

**Identify files that are large but have no consumers:**

```javascript
// Orphan = large file with no reverse dependencies
const orphanedFiles = [];

for (const file of allLargeFiles) {
  const importedBy = reverseDepMap[file.path] || [];

  if (importedBy.length === 0) {
    // Check if it has exports (could be entry point or dead code)
    const exports = parseExports(file.path);

    orphanedFiles.push({
      file: file.path,
      lines: file.loc,
      importCount: 0,
      exportCount: exports.length,
      status: exports.length > 0 ? "unused-exports" : "no-exports",
      recommendation: determineOrphanRecommendation(file, exports)
    });
  }
}

function determineOrphanRecommendation(file, exports) {
  // Entry points (index.ts, main.ts) are expected orphans
  if (file.path.match(/(index|main)\.(ts|js)$/)) {
    return "Entry point - expected to have no importers";
  }

  // Test files
  if (file.path.match(/\.(test|spec)\.(ts|tsx|js|jsx)$/)) {
    return "Test file - expected to have no importers";
  }

  // Otherwise, potential dead code
  if (exports.length === 0) {
    return "No exports, no imports - likely dead code, safe to remove";
  }

  return "Has exports but no importers - review for removal or missing integration";
}
```

### Step 7: Save Analysis Results

Write results to `.claude/refactor-analysis.json`:

```javascript
{
  "timestamp": new Date().toISOString(),
  "scope": scope,  // "all", "directory", or specific file
  "flags": {
    "globalScan": globalScan,
    "traceImports": traceImports,
    "threshold": threshold
  },
  "summary": {
    "filesAnalyzed": totalFiles,
    "refactoringCandidates": candidates.length,
    "criticalIssues": criticalCount,
    "healthScore": calculateHealthScore(),
    "healthGrade": determineGrade(healthScore),
    "discoveryBreakdown": {
      "directFlag": directFlagCount,
      "globalScan": globalScanCount,
      "importTrace": importTraceCount
    }
  },
  "hotspots": rankedHotspots,
  "groupedByDiscoveryMethod": {
    "directFlag": directFlagFiles,
    "globalScan": globalScanFiles,
    "importTrace": importTraceFiles
  },
  "groupedByPage": pageDependencyTrees,
  "orphanedFiles": orphanedFiles,
  "smellCounts": aggregateSmellCounts,
  "aggregateMetrics": aggregateMetrics
}
```

### Step 7.5: Generate Comprehensive Report Structure (if generateFullReport)

**When `generateFullReport` is true**, create a well-organized folder structure for `/create-roadmap` consumption:

```
.claude/refactor-analysis/
├── filetree.py                           # Script to regenerate folder tree
├── folder_tree.txt                       # Current folder structure
├── README.md                             # Report overview and usage guide
└── refactor-analysis-{MM-DD-YYYY}/       # Dated analysis folder
    ├── _index.yaml                       # Master index with all pages and priorities
    ├── _fix-order-global.yaml            # Global recommended fix order (dependency-aware)
    ├── _summary.md                       # Executive summary for roadmap generation
    │
    ├── By-Page/                          # Per-page analysis (main organization)
    │   ├── _page-index.yaml              # Index of all pages with dependency weights
    │   ├── epg/
    │   │   ├── page-summary.yaml         # Page overview, total lines, health score
    │   │   ├── fix-order.yaml            # Recommended fix order for THIS page
    │   │   ├── entry-point.md            # Entry point file analysis
    │   │   ├── dependencies/
    │   │   │   ├── epgStore.yaml         # Each dependency as YAML
    │   │   │   ├── epgApi.yaml
    │   │   │   └── EventsTableEditor.yaml
    │   │   └── dependency-graph.md       # Visual dependency tree (mermaid)
    │   ├── handwrytten/
    │   │   ├── page-summary.yaml
    │   │   ├── fix-order.yaml
    │   │   └── ...
    │   ├── campaigns/
    │   ├── availability/
    │   └── ... (one folder per page/route)
    │
    ├── By-Discovery/                     # Grouped by how files were found
    │   ├── direct-flag/
    │   │   └── *.yaml                    # Files found by threshold
    │   ├── global-scan/
    │   │   └── *.yaml                    # Files found by exhaustive scan
    │   └── import-trace/
    │       └── *.yaml                    # Files found via dependency tracing
    │
    ├── By-Tier/                          # Grouped by severity
    │   ├── tier-1-critical/              # >2000 lines
    │   │   └── *.yaml
    │   ├── tier-2-high/                  # 1000-2000 lines
    │   │   └── *.yaml
    │   └── tier-3-medium/                # 500-1000 lines
    │       └── *.yaml
    │
    ├── Orphaned/                         # Potential dead code
    │   ├── _orphan-index.yaml
    │   └── *.yaml
    │
    └── YAML-Directory/                   # Flat YAML directory (all files)
        ├── _all-files.yaml               # Complete list
        └── {sanitized-filename}.yaml     # One YAML per analyzed file
```

**Generate the fix order for each page (CRITICAL for near-zero breakage):**

```javascript
// For each page, calculate safe refactoring order
function calculateFixOrder(page, dependencies, reverseDepMap) {
  const fixOrder = [];
  const visited = new Set();

  // Step 1: Find leaf dependencies (files with no dependents within this page)
  // These are SAFE to refactor first - nothing in the page depends on them
  const leafDeps = dependencies.filter(dep => {
    const dependents = reverseDepMap[dep.path] || [];
    // Filter to only dependents within this page's tree
    const pageInternal = dependents.filter(d =>
      dependencies.some(pd => pd.path === d.importedBy)
    );
    return pageInternal.length === 0;
  });

  // Step 2: Topological sort - refactor from leaves to root
  function addToOrder(file, depth = 0) {
    if (visited.has(file.path)) return;
    visited.add(file.path);

    // First, add all files this one depends on
    const fileDeps = dependencies.filter(d =>
      file.imports?.includes(d.path)
    );
    for (const dep of fileDeps) {
      addToOrder(dep, depth + 1);
    }

    // Then add this file
    fixOrder.push({
      order: fixOrder.length + 1,
      path: file.path,
      lines: file.lines,
      tier: file.tier,
      reason: determineFixReason(file, depth),
      safeToRefactor: depth === 0 ? "YES - leaf dependency" :
                       `AFTER completing items 1-${fixOrder.length}`,
      estimatedBreakageRisk: calculateBreakageRisk(file, reverseDepMap),
      prerequisites: fileDeps.map(d => d.path)
    });
  }

  // Start with leaves, then work up
  for (const leaf of leafDeps) {
    addToOrder(leaf);
  }

  // Add entry point last (most dangerous to refactor)
  if (!visited.has(page.entryPoint)) {
    fixOrder.push({
      order: fixOrder.length + 1,
      path: page.entryPoint,
      lines: page.entryPointLines,
      tier: determineTier(page.entryPointLines),
      reason: "Entry point - refactor LAST after all dependencies stabilized",
      safeToRefactor: `AFTER completing items 1-${fixOrder.length}`,
      estimatedBreakageRisk: "HIGH - affects all page functionality",
      prerequisites: dependencies.map(d => d.path)
    });
  }

  return fixOrder;
}

function calculateBreakageRisk(file, reverseDepMap) {
  const dependents = reverseDepMap[file.path] || [];
  if (dependents.length === 0) return "NONE - no dependents";
  if (dependents.length <= 2) return "LOW - few dependents";
  if (dependents.length <= 5) return "MEDIUM - several dependents";
  return `HIGH - ${dependents.length} files depend on this`;
}
```

**Page Summary YAML format (`page-summary.yaml`):**

```yaml
# Page: EPG (Event Planning Grid)
# Generated: 2026-02-04T12:00:00Z
# Analysis Mode: Comprehensive

page:
  name: epg
  route: /epg
  entryPoint: src/pages/EPGViewPage.tsx

metrics:
  entryPointLines: 245
  totalDependencyLines: 7968
  totalFilesInTree: 12
  criticalFiles: 3
  highFiles: 4
  mediumFiles: 5
  healthScore: 42
  healthGrade: D

dependencies:
  - path: src/store/epgStore.ts
    lines: 3123
    tier: critical
    discoveredBy: import-trace
  - path: src/api/epgApi.ts
    lines: 2033
    tier: critical
    discoveredBy: import-trace
  - path: src/components/EventsTableEditor.tsx
    lines: 2567
    tier: critical
    discoveredBy: import-trace

refactoringEstimate:
  totalFiles: 12
  totalLines: 8213
  estimatedEffort: "3-4 weeks"
  recommendedApproach: "Bottom-up (leaf dependencies first)"
```

**Fix Order YAML format (`fix-order.yaml`):**

```yaml
# Fix Order for: EPG Page
# Strategy: Bottom-up (leaf dependencies first) for near-zero breakage
#
# IMPORTANT: Follow this order exactly to minimize breaking changes.
# Each item should be fully tested before moving to the next.

page: epg
totalSteps: 8
estimatedTotalEffort: "3-4 weeks"
breakageStrategy: "bottom-up-leaf-first"

fixOrder:
  - order: 1
    path: src/store/epgStore/types.ts
    lines: 245
    tier: medium
    safeToRefactor: "YES - leaf dependency (type definitions)"
    breakageRisk: NONE
    prerequisites: []
    suggestedActions:
      - "Extract shared types to separate files"
      - "Add JSDoc comments for complex types"
    estimatedEffort: "2-4 hours"

  - order: 2
    path: src/store/epgStore/selectors.ts
    lines: 312
    tier: medium
    safeToRefactor: "YES - depends only on types.ts"
    breakageRisk: LOW
    prerequisites:
      - src/store/epgStore/types.ts
    suggestedActions:
      - "Memoize expensive selectors"
      - "Split into domain-specific selector files"
    estimatedEffort: "4-6 hours"

  - order: 3
    path: src/api/epgApi.ts
    lines: 2033
    tier: critical
    safeToRefactor: "AFTER completing items 1-2"
    breakageRisk: MEDIUM
    prerequisites:
      - src/store/epgStore/types.ts
    suggestedActions:
      - "Split into epgEventsApi.ts, epgScheduleApi.ts"
      - "Extract error handling to shared utility"
      - "Add request/response types"
    estimatedEffort: "2-3 days"

  # ... more items

  - order: 8
    path: src/pages/EPGViewPage.tsx
    lines: 245
    tier: medium
    safeToRefactor: "LAST - after all dependencies stabilized"
    breakageRisk: HIGH
    prerequisites:
      - src/store/epgStore.ts
      - src/api/epgApi.ts
      - src/components/EventsTableEditor.tsx
    suggestedActions:
      - "Extract sub-components if >300 lines after dep refactoring"
      - "Add error boundaries"
      - "Implement loading states"
    estimatedEffort: "1-2 days"

testing:
  afterEachStep:
    - "Run unit tests for modified file"
    - "Run integration tests for page"
    - "Manual smoke test of affected features"
  afterAllSteps:
    - "Full E2E test suite"
    - "Performance comparison (before/after)"
```

**Global Fix Order YAML (`_fix-order-global.yaml`):**

```yaml
# Global Refactoring Order
# Generated: 2026-02-04T12:00:00Z
#
# This is the recommended order to refactor ALL critical files across
# the entire codebase with minimal breakage risk.
#
# Strategy: Shared dependencies first, then page-specific code

totalFiles: 52
totalCriticalFiles: 8
estimatedTotalEffort: "8-12 weeks"

phases:
  - phase: 1
    name: "Shared Infrastructure"
    description: "Refactor core utilities and adapters used across multiple pages"
    estimatedEffort: "2-3 weeks"
    files:
      - path: src/services/SelfHostedSocketAdapter.ts
        lines: 3751
        usedByPages: ["live-stream", "vibe-remote", "cli-dashboard"]
        priority: 1
        reason: "Core infrastructure - refactor first to stabilize foundation"

      - path: src/utils/usiEventEmailTemplate.ts
        lines: 4474
        usedByPages: ["campaigns", "handwrytten"]
        priority: 2
        reason: "Shared utility - affects multiple pages"

  - phase: 2
    name: "Core Stores"
    description: "Refactor large state management stores"
    estimatedEffort: "2-3 weeks"
    files:
      - path: src/store/epgStore.ts
        lines: 3123
        usedByPages: ["epg"]
        priority: 1

      - path: src/store/happyStore.ts
        lines: 2468
        usedByPages: ["dashboard", "reports"]
        priority: 2

      - path: src/store/campaignStore.ts
        lines: 1756
        usedByPages: ["campaigns"]
        priority: 3

  - phase: 3
    name: "Large Components"
    description: "Split oversized React components"
    estimatedEffort: "2-3 weeks"
    files:
      - path: src/components/EventEmailPreviewModal.tsx
        lines: 4328
        usedByPages: ["campaigns", "epg"]
        priority: 1

      - path: src/components/EmailTemplateModal.tsx
        lines: 3781
        usedByPages: ["campaigns"]
        priority: 2

  - phase: 4
    name: "Page Entry Points"
    description: "Refactor page components (LAST - after dependencies stable)"
    estimatedEffort: "2-3 weeks"
    files:
      - path: src/pages/HandwryttenExportView.tsx
        lines: 1372
        priority: 1

      - path: src/pages/ReportGeneratorView.tsx
        lines: 1069
        priority: 2

rollbackPlan:
  strategy: "Feature branch per phase"
  checkpoints:
    - "After each phase, merge to main with feature flag"
    - "Monitor error rates for 48 hours before next phase"
```

**Generate filetree.py script:**

```python
#!/usr/bin/env python3
"""
Regenerate the folder tree for refactor-analysis reports.
Run from project root: python .claude/refactor-analysis/filetree.py
"""

import os
from pathlib import Path
from datetime import datetime

def generate_tree(directory, prefix="", output_lines=None):
    if output_lines is None:
        output_lines = []

    entries = sorted(Path(directory).iterdir(), key=lambda e: (e.is_file(), e.name))

    for i, entry in enumerate(entries):
        is_last = i == len(entries) - 1
        connector = "└── " if is_last else "├── "

        output_lines.append(f"{prefix}{connector}{entry.name}")

        if entry.is_dir():
            extension = "    " if is_last else "│   "
            generate_tree(entry, prefix + extension, output_lines)

    return output_lines

if __name__ == "__main__":
    script_dir = Path(__file__).parent
    tree_lines = [f"# Generated: {datetime.now().isoformat()}", ""]
    tree_lines.extend(generate_tree(script_dir))

    output_path = script_dir / "folder_tree.txt"
    output_path.write_text("\\n".join(tree_lines))
    print(f"Generated: {output_path}")
```

**Generate README.md:**

```markdown
# Refactor Analysis Report

Generated: {timestamp}
Analysis Mode: {mode}
Threshold: {threshold} lines

## Quick Links

- [Executive Summary](./{dated-folder}/_summary.md)
- [Global Fix Order](./{dated-folder}/_fix-order-global.yaml)
- [Page Index](./{dated-folder}/By-Page/_page-index.yaml)

## Usage with /create-roadmap

This report is designed to be consumed by `/create-roadmap`:

\`\`\`bash
/create-roadmap .claude/refactor-analysis/{dated-folder}/
\`\`\`

## Report Structure

| Folder | Purpose |
|--------|---------|
| `By-Page/` | Per-page analysis with fix ordering |
| `By-Discovery/` | Files grouped by how they were found |
| `By-Tier/` | Files grouped by severity |
| `Orphaned/` | Potential dead code |
| `YAML-Directory/` | Flat list of all analyzed files |

## Fix Order Strategy

Each page includes a `fix-order.yaml` that specifies the **exact order**
to refactor files for near-zero breakage:

1. **Leaf dependencies first** - Files with no internal dependents
2. **Work up the tree** - Refactor dependencies before dependents
3. **Entry point last** - Page component refactored after all deps stable

## Regenerating This Report

\`\`\`bash
/refactor-analyze --comprehensive --threshold {threshold}
\`\`\`
```

### Step 8: Display Results Summary

**Show a summary table based on user's groupBy preference:**

```
╔═══════════════════════════════════════════════════════════════════════════╗
║  📊 Refactor Analysis - Comprehensive Report                               ║
╠═══════════════════════════════════════════════════════════════════════════╣
║                                                                           ║
║  Files Analyzed: 347                                                      ║
║  Refactoring Candidates: 52 (15%)                                         ║
║  Critical Issues: 8                                                       ║
║  Health Score: 62/100 (Fair)                                              ║
║                                                                           ║
╠═══════════════════════════════════════════════════════════════════════════╣
║  Discovery Breakdown                                                       ║
╠═══════════════════════════════════════════════════════════════════════════╣
║                                                                           ║
║  Direct Flag (>500 lines):     23 files                                   ║
║  Global Scan (comprehensive):  18 files (would have been MISSED!)         ║
║  Import Trace (dependencies):  11 files (hidden behind pages)             ║
║                                                                           ║
╠═══════════════════════════════════════════════════════════════════════════╣
║  Critical Files (>2000 lines) - Tier 1                                    ║
╠═══════════════════════════════════════════════════════════════════════════╣
║                                                                           ║
║  1. src/utils/usiEventEmailTemplate.ts          4,474 lines  [global-scan]║
║  2. src/components/EventEmailPreviewModal.tsx   4,328 lines  [global-scan]║
║  3. src/components/EmailTemplateModal.tsx       3,781 lines  [global-scan]║
║  4. src/services/SelfHostedSocketAdapter.ts     3,751 lines  [import-trace]║
║  5. src/store/epgStore.ts                       3,123 lines  [direct-flag]║
║                                                                           ║
╠═══════════════════════════════════════════════════════════════════════════╣
║  Orphaned Files (potential dead code)                                      ║
╠═══════════════════════════════════════════════════════════════════════════╣
║                                                                           ║
║  • src/utils/legacyHelpers.ts (2,100 lines) - No importers detected       ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
```

### Step 9: Ask User How to Proceed

**If `generateFullReport` was true, show report location:**

```
╔═══════════════════════════════════════════════════════════════════════════╗
║  📁 Comprehensive Report Generated                                         ║
╠═══════════════════════════════════════════════════════════════════════════╣
║                                                                           ║
║  Location: .claude/refactor-analysis/refactor-analysis-{MM-DD-YYYY}/      ║
║                                                                           ║
║  Files Created:                                                           ║
║  • {pageCount} page analysis folders (By-Page/)                           ║
║  • {fileCount} individual YAML files (YAML-Directory/)                    ║
║  • Global fix order (_fix-order-global.yaml)                              ║
║  • Executive summary (_summary.md)                                        ║
║                                                                           ║
║  Ready for: /create-roadmap .claude/refactor-analysis/{dated-folder}/     ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
```

**Use AskUserQuestion:**

```
header: "Analysis Complete"
question: "Found {candidateCount} refactoring candidates ({criticalCount} critical). How would you like to proceed?"
options:
  - label: "Generate Roadmap from Report (Recommended)"
    description: "Run /create-roadmap with the generated report folder"
  - label: "View Fix Order for Specific Page"
    description: "Display the recommended refactoring sequence for a page"
  - label: "Start Refactoring Critical Files"
    description: "Begin with Tier 1 files (>2000 lines) using /refactor-workflow"
  - label: "Export to GitHub Issues"
    description: "Create issues for each refactoring candidate with discovery context"
  - label: "Review Orphaned Files"
    description: "Investigate potential dead code for removal"
```

**If user selects "View Fix Order for Specific Page":**

```
header: "Select Page"
question: "Which page's fix order would you like to view?"
options:
  - label: "EPG ({epgLines} total lines, {epgFiles} files)"
    description: "Event Planning Grid - highest dependency weight"
  - label: "Campaigns ({campaignLines} total lines, {campaignFiles} files)"
    description: "Campaign Management"
  - label: "Handwrytten ({handwryttenLines} total lines, {handwryttenFiles} files)"
    description: "Handwrytten Export"
  # ... dynamically generated from pages with refactoring candidates
```

Then display the contents of that page's `fix-order.yaml` in a formatted table.

## Tech Stack Integration

{{#if frontend.framework}}
### {{frontend.framework}} Analysis

Additional metrics for {{frontend.framework}}:
- Component render complexity
- Prop drilling depth
- Hook dependency arrays
- Re-render triggers
{{/if}}

{{#if backend.framework}}
### {{backend.framework}} Analysis

Additional metrics for {{backend.framework}}:
{{#if (eq backend.framework "fastapi")}}
- Route handler complexity
- Dependency injection depth
- Pydantic model nesting
{{/if}}
{{#if (eq backend.framework "express")}}
- Middleware chain length
- Route handler complexity
- Error handling coverage
{{/if}}
{{/if}}

## Related Commands

- `/refactor-workflow` - Execute refactoring with full workflow
- `/golden-master` - Generate characterization tests
- `/refactor-scope` - Find specific refactoring opportunities
- `/refactor-audit` - View flagged files from hook

## Example Workflows

### Full Codebase Audit with Report Generation

```bash
# Run comprehensive analysis with full report
/refactor-analyze
# Select: "Comprehensive (All Features)"
# Select: "1000 lines (Large files only)"
# Select: "By Page/Route"
# Select: "Yes - Full Report (Recommended for /create-roadmap)"
```

**Output:**
```
.claude/refactor-analysis/
├── filetree.py
├── folder_tree.txt
├── README.md
└── refactor-analysis-02-04-2026/
    ├── _index.yaml
    ├── _fix-order-global.yaml
    ├── _summary.md
    ├── By-Page/
    │   ├── epg/
    │   │   ├── page-summary.yaml
    │   │   ├── fix-order.yaml        # ← Per-page refactoring order
    │   │   └── dependencies/
    │   ├── handwrytten/
    │   ├── campaigns/
    │   └── ... (34 pages)
    ├── By-Tier/
    │   ├── tier-1-critical/          # 8 files >2000 lines
    │   ├── tier-2-high/              # 15 files 1000-2000 lines
    │   └── tier-3-medium/            # 29 files 500-1000 lines
    └── YAML-Directory/               # 52 individual YAML files
```

**Then generate roadmap:**
```bash
/create-roadmap .claude/refactor-analysis/refactor-analysis-02-04-2026/
```

### Quick Analysis (JSON Only)

```bash
# Fast analysis without file generation
/refactor-analyze
# Select: "Standard Analysis"
# Select: "500 lines (Standard)"
# Select: "By Priority Score"
# Select: "No - JSON Only"
```

Output: `.claude/refactor-analysis.json`

### Page-Focused Refactoring

```bash
# Analyze specific page and its dependencies
/refactor-analyze src/pages/EPGViewPage.tsx
# Select: "Deep Analysis + Import Tracing"
```

This maps:
- `EPGViewPage.tsx` → `epgStore.ts` (3,123 lines)
- `EPGViewPage.tsx` → `epgApi.ts` (2,033 lines)
- `EPGViewPage.tsx` → `EventsTableEditor.tsx` (2,567 lines)

Total dependency weight: **7,968 lines** for one page!

### Zero-Breakage Refactoring Workflow

1. **Generate comprehensive report:**
   ```bash
   /refactor-analyze  # Select: Comprehensive + Full Report
   ```

2. **Review fix order for target page:**
   ```bash
   cat .claude/refactor-analysis/refactor-analysis-{date}/By-Page/epg/fix-order.yaml
   ```

3. **Follow the order exactly:**
   - Start with `order: 1` (leaf dependencies)
   - Test after each file
   - Entry point is always LAST

4. **Track progress:**
   ```bash
   /refactor-workflow --page epg --step 1
   ```

---

*Generated from tech-stack.json template*
