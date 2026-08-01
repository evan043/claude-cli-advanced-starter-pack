---
description: Daily maintenance automation - fix lint errors, remove unused imports, format code
---

# Refactor Cleanup

Automated maintenance to keep codebase clean. Fixes common issues without manual intervention.

## Cleanup Actions

1. **Auto-fix Lint Errors** - Apply ESLint/Ruff --fix
2. **Remove Unused Imports** - Clean up import statements
3. **Format Code** - Apply Prettier/Black formatting
4. **Sort Imports** - Organize import order
5. **Remove Dead Code** - Delete unused functions (optional)

## Usage

Run as part of daily maintenance:

```
/refactor-cleanup
```

Or target specific cleanup:

```
/refactor-cleanup --lint-only
/refactor-cleanup --format-only
/refactor-cleanup --imports-only
```

## Implementation

### Step 1: Auto-fix Lint Errors

**JavaScript/TypeScript:**
```bash
npx eslint . --fix --ext .js,.jsx,.ts,.tsx
```

**Python:**
```bash
ruff check --fix .
# OR
autopep8 --in-place --recursive .
```

### Step 2: Remove Unused Imports

**JavaScript/TypeScript:**
```bash
npx eslint . --fix --rule 'unused-imports/no-unused-imports: error'
# Requires: npm install -D eslint-plugin-unused-imports
```

**Python:**
```bash
autoflake --in-place --remove-all-unused-imports --recursive .
```

### Step 3: Format Code

**JavaScript/TypeScript:**
```bash
npx prettier --write "**/*.{js,jsx,ts,tsx,json,md}"
```

**Python:**
```bash
black .
# OR
ruff format .
```

### Step 4: Sort Imports

**JavaScript/TypeScript:**
```bash
npx eslint . --fix --rule 'import/order: error'
```

**Python:**
```bash
isort .
```

## Output Format

```
Refactor Cleanup Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Lint Fixes Applied:
  ✓ 12 auto-fixable errors resolved
  ⚠️ 3 errors require manual fix (see below)

Unused Imports Removed:
  ✓ src/components/Button.tsx: removed 2 imports
  ✓ src/utils/helpers.ts: removed 1 import

Code Formatted:
  ✓ 45 files formatted

Imports Sorted:
  ✓ 23 files reorganized

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Summary: 15 files modified

Manual Fixes Required:
  1. src/api/client.ts:45 - no-explicit-any
  2. src/hooks/useAuth.ts:12 - react-hooks/exhaustive-deps
  3. src/pages/Home.tsx:78 - no-unused-vars
```

## Configuration

Add to `.claude/config/tech-stack.json`:

```json
{
  "refactorCleanup": {
    "autoFixLint": true,
    "removeUnusedImports": true,
    "formatCode": true,
    "sortImports": true,
    "removeDeadCode": false
  }
}
```

## Safety Features

- **Git Check**: Warns if uncommitted changes exist
- **Backup**: Creates `.cleanup-backup` branch before major changes
- **Dry Run**: Use `--dry-run` to preview changes
- **Exclude**: Respects `.gitignore` and custom exclude patterns

## Related Commands

- `/refactor-check` - Pre-commit quality gate
- `/refactor-analyze` - Deep code analysis
- `/refactor-prep` - Pre-refactoring checklist
