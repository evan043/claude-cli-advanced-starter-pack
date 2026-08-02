---
description: Check for CCASP updates and sync all template files
model: sonnet
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - Task
  - AskUserQuestion
---

# /update-check - CCASP Update & Sync

Comprehensive sync of ALL CCASP template files to your project.

---

## Quick Actions

| Key | Action |
|-----|--------|
| **S** | Sync All - Add new files, skip customized ones |
| **V** | View Changes - See what will be added/skipped |
| **F** | Force Sync - Replace ALL files (backup created) |
| **X** | Exit |

---

## How It Works

1. **Scans ALL template directories** (not just commands/hooks)
2. **Detects customizations** via file hash comparison
3. **Skips customized files** automatically
4. **Adds ALL new files** that don't exist locally

### File Categories Synced

| Category | Source | Destination |
|----------|--------|-------------|
| Commands | `templates/commands/*.template.md` | `.claude/commands/*.md` |
| Commands (Dev) | `templates/commands-dev/*.template.md` | `.claude/commands/*.md` |
| Agents | `templates/agents/**/*.md` | `.claude/agents/*.md` |
| Skills | `templates/skills/*/` | `.claude/skills/*/` |
| Hooks | `templates/hooks/*.template.js` | `.claude/hooks/*.js` |
| Docs | `templates/docs/*.md` | `.claude/docs/*.md` |
| Patterns | `templates/patterns/*.md` | `.claude/docs/patterns/*.md` |
| Scripts | `templates/scripts/*.js` | `.claude/scripts/*.js` |
| GitHub Templates | `templates/github/ISSUE_TEMPLATE/` | `.github/ISSUE_TEMPLATE/` |
| Workflows | `templates/workflows/*.yml` | `.github/workflows/*.yml` |
| MCP | `templates/mcp/*.js` | `.claude/mcp/*.js` |

---

## Instructions for Claude

### Step 0: Check for Sync Marker and Auto-Upgrade (CRITICAL)

**FIRST**, check if the sync marker file exists locally:

```bash
ls .claude/commands/__ccasp-sync-marker.md 2>/dev/null
```

**If the marker file is MISSING:**

Display this message:
```
⚠️  Upgrading to full 11-category sync...

Your project was initialized with an older CCASP version.
Running 'ccasp init' to enable all template categories.
```

Then **automatically run** `ccasp init`:

```bash
ccasp init
```

After init completes, display:
```
✓ Upgrade complete! Now scanning all 11 categories.
```

Then continue with Step 1.

---

### Step 1: Get Package Location and Version

```bash
# Find CCASP package location
CCASP_PATH=$(npm root -g)/claude-cli-advanced-starter-pack
# Or for local install
CCASP_PATH=./node_modules/claude-cli-advanced-starter-pack

# Get versions
INSTALLED=$(cat $CCASP_PATH/package.json 2>/dev/null | grep '"version"' | head -1)
LATEST=$(npm view claude-cli-advanced-starter-pack version 2>/dev/null)
```

Display version status:
```
CCASP Update Check
==================
Installed: v2.2.12
Latest:    v2.2.12 ✓ (up to date)
```

Or if update available:
```
CCASP Update Check
==================
Installed: v2.2.11
Latest:    v2.2.12 ← UPDATE AVAILABLE

Run: npm update -g claude-cli-advanced-starter-pack
```

### Step 2: Scan All Template Files

Scan these directories in the CCASP package:

```javascript
const TEMPLATE_DIRS = {
  commands: {
    source: 'templates/commands/',
    dest: '.claude/commands/',
    pattern: '*.template.md',
    transform: (name) => name.replace('.template.md', '.md')
  },
  commandsDev: {
    source: 'templates/commands-dev/',
    dest: '.claude/commands/',
    pattern: '*.template.md',
    transform: (name) => name.replace('.template.md', '.md')
  },
  agents: {
    source: 'templates/agents/',
    dest: '.claude/agents/',
    pattern: '**/*.md',
    transform: (name) => name // Keep as-is
  },
  skills: {
    source: 'templates/skills/',
    dest: '.claude/skills/',
    pattern: '*/',
    transform: (name) => name // Directory copy
  },
  hooks: {
    source: 'templates/hooks/',
    dest: '.claude/hooks/',
    pattern: '*.template.js',
    transform: (name) => name.replace('.template.js', '.js')
  },
  docs: {
    source: 'templates/docs/',
    dest: '.claude/docs/',
    pattern: '*.md',
    transform: (name) => name.replace('.template.md', '.md')
  },
  patterns: {
    source: 'templates/patterns/',
    dest: '.claude/docs/patterns/',
    pattern: '*.md',
    transform: (name) => name
  },
  scripts: {
    source: 'templates/scripts/',
    dest: '.claude/scripts/',
    pattern: '*.js',
    transform: (name) => name
  },
  githubTemplates: {
    source: 'templates/github/ISSUE_TEMPLATE/',
    dest: '.github/ISSUE_TEMPLATE/',
    pattern: '*.yml',
    transform: (name) => name
  },
  workflows: {
    source: 'templates/workflows/',
    dest: '.github/workflows/',
    pattern: '*.yml',
    transform: (name) => name
  },
  mcp: {
    source: 'templates/mcp/',
    dest: '.claude/mcp/',
    pattern: '*.js',
    transform: (name) => name
  }
};
```

### Step 3: Detect Customizations via Compiled Cache Comparison

**IMPORTANT:** Compare local files against the **compiled cache** (not raw templates).
The compiled cache at `~/.ccasp/compiled/{slug}/` has all `{{placeholder}}` values already resolved by the template engine, so hash comparison is accurate.

First, ensure the compiled cache is fresh:

```bash
# Refresh compiled cache for this project
ccasp template-sync
```

Then determine the compiled cache location:

```bash
# The compiled cache path is stored in .ccasp-meta.json
# Find the project slug from registered projects
COMPILED_DIR=$(node -e "
  const fs = require('fs');
  const path = require('path');
  const home = require('os').homedir();
  const reg = JSON.parse(fs.readFileSync(path.join(home, '.ccasp', 'projects.json'), 'utf8'));
  const cwd = process.cwd().replace(/\\\\/g, '/').replace(/\/+$/, '').toLowerCase();
  const project = reg.projects?.find(p => p.path.replace(/\\\\/g, '/').replace(/\/+$/, '').toLowerCase() === cwd);
  if (project?.slug) { console.log(path.join(home, '.ccasp', 'compiled', project.slug)); }
  else {
    // Derive slug from path
    const name = path.basename(cwd).replace(/[^a-z0-9-]/g, '-').replace(/-+/g, '-').replace(/^-|-$/g, '');
    const hash = require('crypto').createHash('md5').update(cwd).digest('hex').slice(0, 6);
    console.log(path.join(home, '.ccasp', 'compiled', name + '-' + hash));
  }
")
```

For each file that exists BOTH locally and in the compiled cache:

```bash
# Get MD5 hash of local file
LOCAL_HASH=$(md5sum .claude/commands/deploy-full.md | cut -d' ' -f1)

# Get MD5 hash from compiled cache (placeholders already resolved)
COMPILED_HASH=$(md5sum "$COMPILED_DIR/commands/deploy-full.md" | cut -d' ' -f1)

# If hashes differ, file is customized
if [ "$LOCAL_HASH" != "$COMPILED_HASH" ]; then
  echo "CUSTOMIZED: deploy-full.md"
fi
```

This eliminates false positives from placeholder differences — the compiled cache matches exactly what `ccasp init` deployed.

### Step 4: Build Sync Plan

Categorize all files into:

1. **NEW** - Template exists, local file doesn't → Will be added
2. **UNCHANGED** - Hashes match → Will be skipped (no action needed)
3. **CUSTOMIZED** - Hashes differ → Will be skipped (preserved)
4. **LOCAL_ONLY** - Local file exists, no template → Preserved (user created)

### Step 5: Display Sync Plan

```
CCASP Sync Plan
===============

NEW (will be added):
  Commands:  3 files
    + /research-competitor
    + /tunnel-start
    + /tunnel-stop

  Agents:    2 files
    + github-issue-sync-worker.md
    + orchestrator.md

  Hooks:     1 file
    + progress-sync.js

CUSTOMIZED (will be skipped):
  Commands:  5 files
    ~ /create-task-list (modified)
    ~ /menu (modified)
    ~ /pr-merge (modified)
    ~ /phase-dev-plan (modified)
    ~ /deploy-full (modified)

UNCHANGED: 42 files (no action needed)
LOCAL ONLY: 3 files (preserved)

Summary: 6 files to add, 5 customized (skipped), 42 unchanged
```

### Step 6: Ask for Confirmation

Use AskUserQuestion:

```
What would you like to do?

Options:
- Sync (add 6 new files, skip customized)
- View details (see full file list)
- Force sync (replace ALL files, backup created)
- Exit
```

### Step 7: Execute Sync

**For "Sync" option:**

```bash
# Create directories if needed
mkdir -p .claude/commands .claude/agents .claude/skills .claude/hooks .claude/docs/patterns .claude/scripts .claude/mcp .github/ISSUE_TEMPLATE .github/workflows

# Copy each NEW file
for file in $NEW_FILES; do
  cp "$CCASP_PATH/templates/$source" ".claude/$dest"
  echo "Added: $dest"
done

# Update INDEX.md with new commands
# (Append new command entries, don't overwrite)
```

**For "Force Sync" option:**

```bash
# Create backup first
BACKUP_DIR=".claude/backups/$(date +%Y-%m-%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r .claude/commands "$BACKUP_DIR/"
cp -r .claude/agents "$BACKUP_DIR/"
cp -r .claude/skills "$BACKUP_DIR/"
cp -r .claude/hooks "$BACKUP_DIR/"
echo "Backup created: $BACKUP_DIR"

# Preserve config files
cp .claude/config/*.json "$BACKUP_DIR/config/" 2>/dev/null
cp .claude/settings*.json "$BACKUP_DIR/" 2>/dev/null

# Run full init
ccasp init --force

# Restore config
cp "$BACKUP_DIR/config/"*.json .claude/config/ 2>/dev/null
cp "$BACKUP_DIR/settings"*.json .claude/ 2>/dev/null

echo "Force sync complete. Backup at: $BACKUP_DIR"
```

### Step 8: Post-Sync Summary

```
Sync Complete
=============
Added:     6 files
Skipped:   5 files (customized)
Unchanged: 42 files

New commands available:
  /research-competitor - Competitive analysis
  /tunnel-start - Start tunnel service
  /tunnel-stop - Stop tunnel service

RESTART REQUIRED: Exit and restart Claude Code to use new commands.
```

### Step 9: Optional Dependency Check

Check for site-intel optional enhancement packages that unlock advanced features:

```bash
# Check for each optional package in node_modules
for pkg in lighthouse @axe-core/playwright ts-morph; do
  if [ -d "node_modules/$pkg" ]; then
    echo "INSTALLED: $pkg"
  else
    echo "MISSING: $pkg"
  fi
done
```

Display status:

```
Optional Dependencies (Site Intelligence)
==========================================
These packages unlock advanced site-intel features.
Base site-intel works without them.

  lighthouse              — Lighthouse performance auditing
  @axe-core/playwright    — Accessibility auditing (axe-core)
  ts-morph                — Codebase route tracing

Status:
  ● lighthouse              INSTALLED
  ○ @axe-core/playwright    NOT INSTALLED
  ○ ts-morph                NOT INSTALLED

Missing 2 optional packages.
Install with: npm install -D @axe-core/playwright ts-morph
```

If all 3 are installed, show:
```
Optional Dependencies: All 3 site-intel enhancements installed ✓
```

If any are missing, use AskUserQuestion:
```
Would you like to install the missing optional dependencies?

Options:
- Install all missing (npm install -D <packages>)
- Skip for now
```

If user chooses to install, run:
```bash
npm install -D <missing-packages>
```

Use a 5-minute timeout since lighthouse is a large package.

---

## Customization Detection Logic

### Hash-Based Detection (Primary)

```javascript
function isCustomized(localPath, templatePath) {
  // File doesn't exist locally - not customized, it's NEW
  if (!existsSync(localPath)) return false;

  // File doesn't exist in template - LOCAL_ONLY
  if (!existsSync(templatePath)) return 'local_only';

  // Compare file hashes
  const localHash = md5(readFileSync(localPath));
  const templateHash = md5(readFileSync(templatePath));

  return localHash !== templateHash;
}
```

## File-Specific Notes

### Commands
- Remove `.template` from filename
- Most are self-contained, no placeholders
- INDEX.md should be MERGED not replaced

### Agents
- Nested directory structure (agents/frontend/react.md)
- Flatten to .claude/agents/ or preserve structure based on project config

### Skills
- Entire directory (skill.md + skill.json + assets/)
- Copy directory recursively
- Check skill.json for customization

### Hooks
- Remove `.template` from filename
- Some have PROJECT_ROOT placeholders
- Must update settings.json to register

### Docs
- Reference documentation
- Usually safe to overwrite unless user added content

---

## Error Handling

### Package Not Found
```
Error: CCASP package not found.
Install with: npm install -g claude-cli-advanced-starter-pack
```

### Permission Denied
```
Error: Cannot write to .claude/ directory.
Check permissions or run with appropriate access.
```

### Partial Failure
```
Sync partially complete:
  Added: 4/6 files
  Failed: 2 files
    - agents/orchestrator.md (permission denied)
    - hooks/progress-sync.js (already locked)

Retry failed files? [Y/n]
```

---

## State Tracking

Update `.claude/config/ccasp-state.json` after sync:

```json
{
  "lastSyncTimestamp": "2026-02-04T12:00:00Z",
  "lastSyncVersion": "2.2.12",
  "filesAdded": ["research-competitor.md", "tunnel-start.md"],
  "filesSkipped": ["create-task-list.md", "menu.md"],
  "customizedFiles": [
    {
      "path": ".claude/commands/create-task-list.md",
      "localHash": "abc123...",
      "templateHash": "def456...",
      "detectedAt": "2026-02-04T12:00:00Z"
    }
  ]
}
```

---

## Terminal Alternative

```bash
# Quick sync (same as option S)
ccasp sync

# Force sync (same as option F)
ccasp init --force

# Check what would be synced (dry run)
ccasp sync --dry-run
```

---

*Part of Claude CLI Advanced Starter Pack v2.2.12+*
