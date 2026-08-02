---
description: Start working on a GitHub issue by number with full workflow
type: utility
complexity: simple
model: haiku
argument-hint: <issue-number>
allowed-tools:
  - Bash
  - AskUserQuestion
  - Task
---

# /create-task-list-for-issue - Quick Issue Start

**Start working on a GitHub issue by number. Confirms details, then runs full `/create-task-list` workflow.**

---

## USAGE

```bash
/create-task-list-for-issue 123
/create-task-list-for-issue #45
/create-task-list-for-issue 7
```

---

## EXECUTION

### Step 1: Parse Issue Number

Extract issue number from `$ARGUMENTS`:
- Strip `#` prefix if present
- Validate it's a positive integer

```
If no issue number provided:
  → Use AskUserQuestion: "Which issue number would you like to work on?"
```

---

### Step 2: Fetch Issue Details

```bash
gh issue view [NUMBER] --json number,title,body,createdAt,labels,url
```

---

### Step 3: Detect Issue Format

Check if the issue body contains BOTH of these indicators of `/github-task` format:
- `## Acceptance Criteria` OR `## Task Checklist` section
- `## Suggested Implementation` OR `## Implementation Approach` section

**Set `IS_TASK_READY`** = true if both indicators found, false otherwise.

---

### Step 4: Display Issue Confirmation

**If IS_TASK_READY = true:**

```
╔═══════════════════════════════════════════════════════════════╗
║  Issue #[NUMBER]  ✓ Task-Ready                                ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  [Issue Title - max 50 chars]                                 ║
║                                                               ║
║  Created: [MM/DD/YYYY]                                        ║
║  Labels: [label1, label2, ...]                                ║
║  URL: [github url]                                            ║
║                                                               ║
║  Format: Has task checklist - will use existing tasks         ║
║                                                               ║
║  Tasks found:                                                 ║
║    • [Task 1 from checklist]                                  ║
║    • [Task 2 from checklist]                                  ║
║    • ... ([N] total)                                          ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

**If IS_TASK_READY = false:**

```
╔═══════════════════════════════════════════════════════════════╗
║  Issue #[NUMBER]  ⚠ Needs Analysis                            ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  [Issue Title - max 50 chars]                                 ║
║                                                               ║
║  Created: [MM/DD/YYYY]                                        ║
║  Labels: [label1, label2, ...]                                ║
║  URL: [github url]                                            ║
║                                                               ║
║  Format: No task checklist - will generate via exploration    ║
║                                                               ║
║  Description preview:                                         ║
║    [First 100 chars of issue body...]                         ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

### Step 5: Confirm and Proceed

```
header: "Start"
question: "Start working on this issue?"
options:
  - label: "Y - Yes, proceed"
    description: "Run full /create-task-list workflow"
  - label: "V - View full details"
    description: "Show complete issue body first"
  - label: "N - Cancel"
    description: "Return without starting"
```

**If user selects V (View):**
- Run `gh issue view [NUMBER]` and display full body
- Then re-ask the confirmation question (Y/N only)

**If user selects N (Cancel):**
- Exit command

**If user selects Y (Yes):**
- Proceed to Step 6

---

### Step 6: Run Full /create-task-list Workflow

**If IS_TASK_READY = true:**

Display:
```
╔═══════════════════════════════════════════════════════════════╗
║  📋 Starting Issue #[NUMBER] (Task-Ready)                     ║
╠═══════════════════════════════════════════════════════════════╣
║  Using existing task checklist from issue                     ║
║  Running full /create-task-list workflow for:                 ║
║    • Codebase exploration & context                           ║
║    • Testing configuration (Ralph loop, E2E)                  ║
║    • Workflow setup (branch, board sync)                      ║
╚═══════════════════════════════════════════════════════════════╝
```

Run: `/create-task-list for issue #[NUMBER] --use-existing-tasks`

---

**If IS_TASK_READY = false:**

Display:
```
╔═══════════════════════════════════════════════════════════════╗
║  📋 Starting Issue #[NUMBER] (Needs Analysis)                 ║
╠═══════════════════════════════════════════════════════════════╣
║  Running full /create-task-list workflow for:                 ║
║    • Task generation via codebase exploration                 ║
║    • Testing configuration (Ralph loop, E2E)                  ║
║    • Workflow setup (branch, board sync)                      ║
║    • Option to update issue with generated tasks              ║
╚═══════════════════════════════════════════════════════════════╝
```

Run: `/create-task-list for issue #[NUMBER]`

After `/create-task-list` completes and generates tasks, ask:

```
header: "Update"
question: "Update GitHub issue with generated task list?"
options:
  - label: "Y - Yes, update issue"
    description: "Add task checklist to issue body"
  - label: "N - No, just implement"
    description: "Keep issue as-is, start work"
```

If user selects Y:
```bash
# Append task checklist to issue body
gh issue edit [NUMBER] --body "$(gh issue view [NUMBER] --json body -q .body)

## Task Checklist (Auto-generated)

- [ ] Task 1
- [ ] Task 2
..."
```

---

### Step 7: After Task Completion - Close Issue Prompt

**CRITICAL: After ALL TodoWrite tasks are marked complete AND a commit is created, ALWAYS offer to close the issue.**

This step triggers when:
1. All tasks in TodoWrite are marked `completed`
2. A git commit has been made with changes

Display completion summary:

```
╔═══════════════════════════════════════════════════════════════╗
║  ✅ All Tasks Completed                                       ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Issue: #[NUMBER] - [TITLE]                                   ║
║  Commit: [SHORT_SHA] - [COMMIT_MSG_FIRST_LINE]                ║
║  Tasks: [X] completed                                         ║
║                                                               ║
╠═══════════════════════════════════════════════════════════════╣
║  [C] Close issue with comment                                 ║
║  [P] Push to origin + close issue                             ║
║  [K] Keep issue open                                          ║
╚═══════════════════════════════════════════════════════════════╝
```

Then ask:

```
header: "Issue"
question: "All tasks complete. Close issue #[NUMBER]?"
options:
  - label: "C - Close with comment"
    description: "Add completion summary and close"
  - label: "P - Push + Close"
    description: "Push commit to origin, then close"
  - label: "K - Keep open"
    description: "Leave issue open for follow-up"
```

**Handle Close Actions:**

**C (Close with comment):**
```bash
gh issue close [NUMBER] --comment "All tasks completed in commit [SHA].

## Completed Tasks
- ✅ Task 1
- ✅ Task 2
...

Ready for release."
```

**P (Push + Close):**
```bash
git push origin HEAD
gh issue close [NUMBER] --comment "All tasks completed and pushed in commit [SHA].

## Completed Tasks
- ✅ Task 1
- ✅ Task 2
...

Ready for release."
```

**K (Keep open):**
Display: "Issue #[NUMBER] kept open for follow-up."

---

## ERROR HANDLING

| Error | Action |
|-------|--------|
| Issue not found | Display "Issue #[N] not found" and exit |
| gh not authenticated | Show `gh auth login` instructions |
| Invalid issue number | Ask user to provide valid number |
| Network error | Show retry option |

---

## RELATED COMMANDS

- `/menu-issues-list` - Browse all open issues with menu
- `/create-task-list` - Create task list from any prompt
- `/github-task-start` - Start working on issue (simpler flow)
- `/github-update` - Sync with project board
