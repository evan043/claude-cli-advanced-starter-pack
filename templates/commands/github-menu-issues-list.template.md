<!-- CCASP-CODEX-COMPAT:START -->
# Codex Runtime Compatibility

This prompt was authored for Claude-style slash workflows. In Codex runtime, adapt tool calls as follows:
- `AskUserQuestion` => ask the user directly in chat.
- `WebSearch`/`WebFetch` => use available web tools (`search_query`, `open`, `find`) and cite links.
- `Read`/`Write` => use shell/filesystem tools in this workspace.
- Claude-only MCP calls (for example Playwright MCP names) => use available equivalents or clearly state fallback.
- Keep intent and output format identical; only adapt execution mechanics.
<!-- CCASP-CODEX-COMPAT:END -->
---
description: Mobile-friendly menu of open GitHub issues sorted by date
type: utility
complexity: simple
model: haiku
allowed-tools:
  - Bash
  - AskUserQuestion
---

# /github-menu-issues-list - Quick Issues View

**Mobile-friendly list of open GitHub issues with single-character selection.**

---

## EXECUTION

### Step 1: Fetch and Display Issues

Run this command to get open issues:

```bash
gh issue list --state open --json number,title,createdAt,labels --limit 20
```

### Step 2: Format for Mobile Display

Display issues in this compact format (sorted newest to oldest):

```
╔═══════════════════════════════════════╗
║  📋 Open Issues                       ║
╠═══════════════════════════════════════╣
║                                       ║
║  [A] #123 - Fix login redirect bug    ║
║      01/30 • P1 • frontend            ║
║                                       ║
║  [B] #122 - Add dark mode toggle      ║
║      01/29 • P2 • feature             ║
║                                       ║
║  [C] #121 - Update API docs           ║
║      01/28 • P3 • docs                ║
║                                       ║
║  [D] #120 - Refactor auth module      ║
║      01/27 • P2 • backend             ║
║                                       ║
╠═══════════════════════════════════════╣
║  [R] Refresh  [X] Exit                ║
╚═══════════════════════════════════════╝
```

**Format Rules:**
- Title: Max 30 chars, truncate with `...` if longer
- Date: `MM/DD` format (createdAt)
- Priority: Extract from labels (P0, P1, P2, P3) or show `-`
- Labels: Show first non-priority label, max 10 chars
- Sort: Newest first (by createdAt descending)

### Step 3: Ask User Selection

Use AskUserQuestion with single-letter options:

```
header: "Select"
question: "Pick an issue (A-Z) or action:"
options:
  - label: "A"
    description: "#123 - Fix login redirect bug"
  - label: "B"
    description: "#122 - Add dark mode toggle"
  - label: "C"
    description: "#121 - Update API docs"
  - label: "R"
    description: "Refresh list"
```

### Step 4: Handle Selection

**If user selects an issue (A-Z):**

First, fetch full issue details including body:

```bash
gh issue view [NUMBER] --json number,title,body,createdAt,labels,url
```

**Detect Issue Format:**

Check if the issue body contains BOTH of these indicators of `/github-task` format:
- `## Acceptance Criteria` OR `## Task Checklist` section
- `## Suggested Implementation` OR `## Implementation Approach` section

**If PROPERLY FORMATTED** (created by `/github-task`):

Show issue details with format indicator:

```
╔═══════════════════════════════════════╗
║  Issue #123  ✓ Task-Ready             ║
╠═══════════════════════════════════════╣
║                                       ║
║  Fix login redirect bug               ║
║                                       ║
║  Created: 01/30/2026                  ║
║  Labels: P1, frontend, bug            ║
║  URL: github.com/.../issues/123       ║
║                                       ║
║  Format: Task-ready (has checklist)   ║
║                                       ║
╠═══════════════════════════════════════╣
║  [S] Start (use existing tasks)       ║
║  [V] View details  [B] Back  [X] Exit ║
╚═══════════════════════════════════════╝
```

Then ask:

```
header: "Action"
question: "What would you like to do?"
options:
  - label: "S - Start working"
    description: "Execute task checklist from issue"
  - label: "V - View details"
    description: "Show full issue body"
  - label: "B - Back"
    description: "Return to issues list"
```

**If NOT PROPERLY FORMATTED** (generic issue):

Show issue details with exploration indicator:

```
╔═══════════════════════════════════════╗
║  Issue #123  ⚠ Needs Analysis         ║
╠═══════════════════════════════════════╣
║                                       ║
║  Fix login redirect bug               ║
║                                       ║
║  Created: 01/30/2026                  ║
║  Labels: P1, frontend, bug            ║
║  URL: github.com/.../issues/123       ║
║                                       ║
║  Format: Needs task list generation   ║
║                                       ║
╠═══════════════════════════════════════╣
║  [S] Start (explore + generate tasks) ║
║  [V] View details  [B] Back  [X] Exit ║
╚═══════════════════════════════════════╝
```

Then ask:

```
header: "Action"
question: "What would you like to do?"
options:
  - label: "S - Start working"
    description: "Run /create-task-list to analyze and generate tasks"
  - label: "V - View details"
    description: "Show full issue body"
  - label: "B - Back"
    description: "Return to issues list"
```

### Step 5: Handle "Start Working" - ALWAYS Run Full /create-task-list Process

**BOTH PATHS run the full `/create-task-list` workflow**, including:
- Agent-based codebase exploration
- Testing options (Ralph loop, E2E framework selection)
- Environment configuration from tech-stack.json
- Workflow options (branch, worktree, project board)

The only difference is whether we **generate** a new task list or **use** the existing one from the issue.

---

**For PROPERLY FORMATTED issues (S action):**

Run `/create-task-list for issue #[NUMBER] --use-existing-tasks`

This executes the full `/create-task-list` process but:
1. **Skips task generation** - uses the existing `## Task Checklist` from issue body
2. **Runs codebase exploration** - agents analyze relevant files for context
3. **Asks testing questions** - Ralph loop, E2E framework, test environment
4. **Asks workflow questions** - branch creation, worktree, project board sync
5. **Creates TodoWrite entries** from the issue's existing checklist
6. **Begins implementation** with full context

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

---

**For NOT PROPERLY FORMATTED issues (S action):**

Run `/create-task-list for issue #[NUMBER]`

This executes the full `/create-task-list` process:
1. **Generates task list** - agents explore codebase and create tasks
2. **Runs codebase exploration** - deep analysis of relevant files
3. **Asks testing questions** - Ralph loop, E2E framework, test environment
4. **Asks workflow questions** - branch creation, worktree, project board sync
5. **Creates TodoWrite entries** from generated tasks
6. **Offers to update GitHub issue** with the generated task list
7. **Begins implementation** with full context

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

After task list is generated, ask:

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

**Other Actions:**
- **V (View)**: Run `gh issue view [NUMBER]` and display full body
- **B (Back)**: Return to Step 2
- **R (Refresh)**: Re-fetch issues and display
- **X (Exit)**: End command

---

### Step 6: After Task Completion - Close Issue Prompt

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

## MOBILE OPTIMIZATION

- Single character inputs (A, B, C, S, V, X)
- Compact display fits small screens
- No scrolling needed for main list
- Clear visual hierarchy with boxes
- Truncated titles prevent overflow

---

## ERROR HANDLING

| Error | Action |
|-------|--------|
| No issues found | Display "No open issues" message |
| gh not authenticated | Show `gh auth login` instructions |
| Network error | Show retry option |

---

## RELATED COMMANDS

- `/create-task-list-for-issue` - Start issue by number directly
- `/create-task-list` - Create task list from issue
- `/github-task-start` - Start working on issue
- `/github-update` - Sync with project board
