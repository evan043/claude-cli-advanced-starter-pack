---
description: Pre-refactoring safety checklist - ensure safe refactoring conditions
---

# Refactor Prep

Comprehensive safety checklist before starting any refactoring work. Ensures you can safely make changes and recover if needed.

## Usage

```
/refactor-prep
/refactor-prep --scope src/components
/refactor-prep --quick  # Abbreviated checklist
```

## Safety Checklist

### 1. Git Status
- [ ] Working directory is clean
- [ ] On correct branch (not main/master)
- [ ] Remote is up to date

### 2. Test Coverage
- [ ] All tests passing
- [ ] Affected code has test coverage
- [ ] E2E tests available for critical paths

### 3. Backup Points
- [ ] Create rollback commit/tag
- [ ] Document current behavior
- [ ] Screenshot/record current UI state

### 4. Dependencies
- [ ] No pending dependency updates
- [ ] Lock file is committed
- [ ] Build succeeds

### 5. Documentation
- [ ] Refactoring scope defined
- [ ] Breaking changes identified
- [ ] Migration plan documented

## Implementation

### Step 1: Git Safety Check

```bash
# Check working directory
git status

# Verify branch
git branch --show-current

# Check sync with remote
git fetch && git status -uno
```

### Step 2: Test Status

```bash
# Run full test suite
npm test

# Check coverage for affected files
npm run coverage -- --collectCoverageFrom="src/components/**"
```

### Step 3: Create Rollback Point

```bash
# Tag current state
git tag pre-refactor-$(date +%Y%m%d)

# Create backup branch
git branch backup/pre-refactor-$(date +%Y%m%d)
```

### Step 4: Build Verification

```bash
# Clean build
rm -rf node_modules/.cache dist/
npm run build

# Type check
npm run typecheck
```

## Output Report

```
Refactor Prep Checklist
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Git Status:
  ✅ Working directory clean
  ✅ On branch: feature/refactor-components
  ✅ Up to date with origin

Tests:
  ✅ All 145 tests passing
  ⚠️ Affected files have 67% coverage (target: 80%)
  ✅ E2E tests passing

Backup:
  ✅ Created tag: pre-refactor-20260130
  ✅ Created branch: backup/pre-refactor-20260130

Build:
  ✅ TypeScript: No errors
  ✅ Build: Success

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Ready Score: 95%

Recommendations:
  1. Consider adding tests for src/components/Modal.tsx (0% coverage)
  2. Document expected behavior changes

Proceed with refactoring? [Y/N]
```

## Scope Analysis

When `--scope` is provided:

1. **Identify Files** - List all files in scope
2. **Find Dependencies** - Map imports and exports
3. **Calculate Impact** - Estimate affected components
4. **Suggest Order** - Recommend refactoring sequence

```
Scope Analysis: src/components/
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Files in Scope: 23
Direct Dependencies: 45
Potential Impact: 67 files

Dependency Graph:
  Button.tsx
    ├── Used by: 12 components
    ├── Tests: 3 files
    └── Risk: Medium

  Modal.tsx
    ├── Used by: 8 components
    ├── Tests: 0 files
    └── Risk: High (no tests!)

Recommended Order:
  1. Add tests for Modal.tsx (reduce risk)
  2. Refactor leaf components first (Button, Icon)
  3. Work up to container components
  4. Update integration tests last
```

## Quick Mode

Use `--quick` for abbreviated checklist:

```
Quick Refactor Prep
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Git clean
✅ Tests passing
✅ Backup created: pre-refactor-20260130
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Ready to refactor!
```

## Recovery Commands

If refactoring goes wrong:

```bash
# Return to pre-refactor state
git checkout pre-refactor-20260130

# Or restore from backup branch
git checkout backup/pre-refactor-20260130

# Delete failed changes
git reset --hard backup/pre-refactor-20260130
```

## Related Commands

- `/refactor-check` - Pre-commit quality gate
- `/refactor-cleanup` - Auto-fix common issues
- `/refactor-analyze` - Deep code analysis
