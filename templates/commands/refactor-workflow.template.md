---
description: Guided refactoring workflow with branch, task list, and GitHub issue
model: sonnet
argument-hint: [file path or 'flagged']
---

# /refactor-workflow - Guided Refactoring Workflow

Start a comprehensive refactoring workflow with branch management, task list creation, GitHub issue tracking, and specialist agent deployment.

## Quick Start

```bash
/refactor-workflow                    # Refactor all flagged files
/refactor-workflow src/api/client.ts  # Refactor specific file
/refactor-workflow --list             # View all flagged files
/refactor-workflow --dismiss          # Dismiss current suggestions
```

## Workflow Overview

```
╔═══════════════════════════════════════════════════════════════╗
║  🔄 Refactor Workflow                                          ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Step 1: Analyze file(s) for refactoring opportunities        ║
║  Step 2: Create feature branch (refactor/filename-cleanup)    ║
║  Step 3: Generate task list with specific refactor tasks      ║
║  Step 4: Create GitHub issue to track progress                ║
║  Step 5: Deploy specialist agent for tech stack               ║
║  Step 6: Execute refactoring with commits per logical unit    ║
║  Step 7: Run tests to verify no regressions                   ║
║  Step 8: Create PR for review                                 ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

## Refactoring Patterns

### Common Refactoring Opportunities

| Pattern | Description | Target |
|---------|-------------|--------|
| **Extract Function** | Break large functions into smaller ones | Functions > 50 lines |
| **Extract Component** | Split large components into smaller pieces | Components > 200 lines |
| **Extract Module** | Move related code to separate files | Files > 500 lines |
| **Extract Service** | Separate business logic from UI/API | Mixed concerns |
| **Simplify Conditionals** | Replace complex if/else with guard clauses | Deep nesting > 3 levels |
| **Remove Duplication** | Create shared utilities | Similar code blocks |

### Tech Stack Specific Patterns

{{#if frontend.framework}}
#### {{frontend.framework}} Frontend Patterns

| Pattern | When to Apply |
|---------|---------------|
{{#if (eq frontend.framework "react")}}
| Extract Custom Hook | Reusable stateful logic |
| Split Component | Component > 150 lines |
| Memoization | Performance optimization |
| Context Extraction | Prop drilling > 3 levels |
{{/if}}
{{#if (eq frontend.framework "vue")}}
| Extract Composable | Reusable composition logic |
| Split Component | Component > 150 lines |
| Computed Extraction | Complex computed properties |
{{/if}}
{{/if}}

{{#if backend.framework}}
#### {{backend.framework}} Backend Patterns

| Pattern | When to Apply |
|---------|---------------|
{{#if (eq backend.framework "fastapi")}}
| Extract Router | Route file > 200 lines |
| Extract Service | Business logic in routes |
| Extract Repository | Database queries in services |
| Dependency Injection | Tightly coupled components |
{{/if}}
{{#if (eq backend.framework "express")}}
| Extract Middleware | Repeated request handling |
| Extract Controller | Route handlers > 50 lines |
| Extract Service | Business logic in controllers |
{{/if}}
{{/if}}

## Configuration

### Refactor Audit State

The refactor audit state is stored in `.claude/refactor-audit.json`:

```json
{
  "flaggedFiles": [
    {
      "path": "src/api/client.ts",
      "lines": 847,
      "techStack": "react",
      "recommendedAgent": "frontend-react-specialist"
    }
  ],
  "lastAudit": "2026-01-31T12:00:00Z",
  "dismissed": []
}
```

### Line Threshold

Default threshold is 500 lines. Files exceeding this are flagged for review.

## Instructions for Claude

When `/refactor-workflow` is invoked:

### Step 1: Load Flagged Files

1. Read `.claude/refactor-audit.json` for flagged files
2. If specific file provided, validate it exists
3. If no files flagged and no file specified, scan for large files

```bash
# Read audit state
cat .claude/refactor-audit.json
```

### Step 2: Analyze Files

For each file to refactor:

1. **Read the file** to understand structure
2. **Identify refactoring opportunities**:
   - Functions/methods > 50 lines
   - Classes/components > 200 lines
   - Deep nesting > 3 levels
   - Duplicate code blocks
   - Mixed concerns (UI + logic, API + business)

3. **Generate refactoring plan**:
   ```
   File: src/api/client.ts (847 lines)

   Opportunities:
   1. Extract fetchWithRetry() → src/utils/http.ts
   2. Extract AuthManager class → src/services/auth.ts
   3. Split API methods by domain:
      - src/api/users.ts
      - src/api/products.ts
      - src/api/orders.ts
   4. Extract types → src/types/api.ts
   ```

### Step 3: Confirm Approach

**Ask user to confirm using AskUserQuestion:**

```
header: "Refactor Plan"
question: "I've analyzed the file(s). How would you like to proceed?"
options:
  - label: "Full Workflow (Recommended)"
    description: "Branch + task list + GitHub issue + refactor"
  - label: "Quick Refactor"
    description: "Refactor in current branch, no issue"
  - label: "View Detailed Plan"
    description: "Show all refactoring opportunities first"
  - label: "Cancel"
    description: "Don't refactor now"
```

### Step 4: Create Branch (If Full Workflow)

```bash
# Create refactor branch
git checkout -b refactor/{{file-slug}}-cleanup

# Example: refactor/api-client-cleanup
```

### Step 5: Generate Task List

Use TodoWrite to create refactoring tasks:

```javascript
// Example task list for large file refactor
[
  {
    content: "Extract utility functions to src/utils/",
    status: "pending",
    activeForm: "Extracting utilities"
  },
  {
    content: "Split component/class into smaller modules",
    status: "pending",
    activeForm: "Splitting modules"
  },
  {
    content: "Update imports in dependent files",
    status: "pending",
    activeForm: "Updating imports"
  },
  {
    content: "Add/update tests for extracted code",
    status: "pending",
    activeForm: "Updating tests"
  },
  {
    content: "Run tests to verify no regressions",
    status: "pending",
    activeForm: "Running tests"
  }
]
```

### Step 6: Create GitHub Issue (If Full Workflow)

{{#if versionControl.projectBoard.number}}
Create GitHub issue with refactoring details:

```bash
gh issue create \
  --title "refactor: Split large file {{filename}}" \
  --body "$(cat <<'EOF'
## Refactoring Target

**File:** `{{filepath}}`
**Lines:** {{lineCount}}
**Tech Stack:** {{techStack}}

## Refactoring Plan

{{refactoringPlan}}

## Acceptance Criteria

- [ ] File split into logical modules
- [ ] All tests pass
- [ ] No functionality changes
- [ ] Imports updated in all dependent files

## Recommended Agent

🤖 **{{recommendedAgent}}**

---
*Created by Refactor Workflow*
EOF
)" \
  --repo {{versionControl.owner}}/{{versionControl.repo}} \
  --label "refactor"
```
{{else}}
> ℹ️ GitHub integration not configured. Skip issue creation or configure via `/menu`.
{{/if}}

### Step 7: Deploy Specialist Agent

{{#if agents.available}}
Based on the file's tech stack, deploy the appropriate specialist agent:

| Tech Stack | Agent |
|------------|-------|
{{#if agents.frontend}}| React/Vue/Angular | {{agents.frontend.name}} |{{/if}}
{{#if agents.backend}}| FastAPI/Express/NestJS | {{agents.backend.name}} |{{/if}}
{{#if agents.database}}| Prisma/PostgreSQL | {{agents.database.name}} |{{/if}}

```
Deploy Task: subagent_type="{{recommendedAgent}}"
  prompt: "Refactor {{filepath}} by:
    1. {{refactorTask1}}
    2. {{refactorTask2}}
    3. {{refactorTask3}}
    Ensure all tests pass and imports are updated."
  description: "Tech stack specialist refactoring"
```
{{else}}
> ℹ️ No agent registry found. Use generic refactoring approach.
> Run `ccasp generate-agents` to create tech stack specific agents.
{{/if}}

### Step 8: Execute Refactoring

For each refactoring task:

1. **Extract/Split code** using Edit tool
2. **Create new files** if needed using Write tool
3. **Update imports** in dependent files
4. **Commit logical units**:
   ```bash
   git add <files>
   git commit -m "refactor({{module}}): extract {{component}} to separate file"
   ```

### Step 9: Verify & Complete

1. **Run tests**:
   ```bash
   {{#if testing.e2e.testCommand}}
   {{testing.e2e.testCommand}}
   {{else}}
   npm test
   {{/if}}
   ```

2. **If tests fail**, use Ralph Loop:
   ```
   /ralph
   ```

3. **Create PR** (if on feature branch):
   ```bash
   gh pr create \
     --title "refactor: {{refactorSummary}}" \
     --body "Closes #{{issueNumber}}"
   ```

4. **Update refactor audit state**:
   - Remove refactored files from flaggedFiles
   - Add to completed history

### Step 10: Summary

Display completion summary:

```
╔═══════════════════════════════════════════════════════════════╗
║  ✅ Refactoring Complete                                       ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Files refactored: 1                                          ║
║  New files created: 4                                         ║
║  Lines reduced: 847 → 156 (main file)                         ║
║  Tests: All passing                                           ║
║                                                               ║
║  Changes:                                                     ║
║  • src/api/client.ts (847 → 156 lines)                        ║
║  • + src/api/users.ts (new, 142 lines)                        ║
║  • + src/api/products.ts (new, 198 lines)                     ║
║  • + src/utils/http.ts (new, 87 lines)                        ║
║  • + src/services/auth.ts (new, 264 lines)                    ║
║                                                               ║
║  PR: #45 - refactor: Split api/client.ts into modules         ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

## Related Commands

- `/refactor-check` - Pre-commit quality gate
- `/refactor-cleanup` - Fix lint errors and format code
- `/refactor-prep` - Pre-refactoring safety checklist
- `/ralph` - Continuous test-fix loop for regressions

---

*Generated from tech-stack.json template*
