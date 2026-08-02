---
description: Fast pre-commit quality gate - lint, type-check, test affected files
---

# Refactor Check

Quick quality validation before committing changes. Runs essential checks without full test suite.

## Checks Performed

1. **Linting** - ESLint/Pylint for code style issues
2. **Type Checking** - TypeScript/MyPy type validation
3. **Affected Tests** - Run tests for changed files only
4. **Import Validation** - Verify imports resolve correctly

## Usage

Run before committing to catch issues early:

```
/refactor-check
```

## Implementation

When invoked, execute these steps:

### Step 1: Detect Changed Files

```bash
git diff --name-only HEAD~1..HEAD
# OR for staged changes:
git diff --cached --name-only
```

### Step 2: Run Linting (Affected Files Only)

**JavaScript/TypeScript:**
```bash
npx eslint <changed-files>
```

**Python:**
```bash
pylint <changed-files>
# OR
ruff check <changed-files>
```

### Step 3: Type Checking

**TypeScript:**
```bash
npx tsc --noEmit
```

**Python:**
```bash
mypy <changed-files>
```

### Step 4: Run Affected Tests

**JavaScript/TypeScript:**
```bash
npx jest --findRelatedTests <changed-files>
# OR
npx vitest --run --reporter=verbose <changed-files>
```

**Python:**
```bash
pytest <changed-files> --collect-only -q
```

## Output Format

```
Refactor Check Results
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Files Changed: 5
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Linting: Passed (0 errors, 2 warnings)
✅ Type Check: Passed
✅ Tests: 3 passed, 0 failed
⚠️ Imports: 1 unused import detected

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Overall: PASS (ready to commit)
```

## Configuration

Add to `.claude/config/tech-stack.json`:

```json
{
  "refactorCheck": {
    "lint": true,
    "typeCheck": true,
    "testAffected": true,
    "importCheck": true
  }
}
```

## Related Commands

- `/refactor-analyze` - Deep code quality analysis
- `/refactor-cleanup` - Fix common issues automatically
- `/refactor-prep` - Pre-refactoring safety checklist
