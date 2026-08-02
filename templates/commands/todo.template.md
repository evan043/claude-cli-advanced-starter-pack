---
description: View, navigate, and work on todo items with AI-powered intent routing
type: utility
complexity: medium
model: sonnet
argument-hint: "[list|work|complete|delete] [item-id]"
allowed-tools:
  - Read
  - Write
  - Grep
  - Glob
  - Task
  - AskUserQuestion
  - Bash
  - Skill
---

# /todo - Smart Todo Manager

View, navigate, and work on your todo items. AI-powered intent detection suggests the best workflow for each item.

## QUICK START

```bash
/todo                    # Show interactive menu
/todo list               # List all todos
/todo work a1b2c3d4      # Start working on item by ID
/todo complete a1b2c3d4  # Mark item as completed
/todo delete a1b2c3d4    # Delete an item
```

## EXECUTION FLOW

### Step 1: Read Todos

Read `.claude/todos.json`. If file doesn't exist, display:

```
No todos found. Add one with /todo-add
```

And stop execution.

### Step 2: Parse Arguments

| Argument | Action |
|----------|--------|
| (none) | Show interactive menu |
| `list` | Show all todos with status indicators |
| `work [id]` | Start "Work on item" flow |
| `complete [id]` | Mark item as completed |
| `delete [id]` | Delete item (with confirmation) |

### Step 3: Interactive Menu (Default)

If no arguments provided, show the todo list and menu:

```
╔═══════════════════════════════════════════════════╗
║  Todo List (5 items)                              ║
╠═══════════════════════════════════════════════════╣
║                                                   ║
║  PENDING (3)                                      ║
║  ○ [a1b2] Fix login redirect on mobile            ║
║  ○ [c3d4] Add dark mode settings toggle           ║
║  ○ [e5f6] Refactor auth middleware JWT    ★ high  ║
║                                                   ║
║  IN PROGRESS (1)                                  ║
║  ◉ [g7h8] Build user dashboard charts             ║
║                                                   ║
║  COMPLETED (1)                                    ║
║  ✓ [i9j0] Setup CI/CD pipeline                    ║
║                                                   ║
╚═══════════════════════════════════════════════════╝
```

Then use AskUserQuestion with these options:

1. "Work on an item" - Start the AI intent detection flow
2. "View item details" - Show full detail for a specific item
3. "Complete an item" - Mark as done
4. "Delete an item" - Remove from list
5. "Add new item" - Suggest using /todo-add

### Step 4: List View

When showing the list, use these status indicators:

- `○` pending
- `◉` in_progress
- `✓` completed
- `★` for high/critical priority (show after title)

Show ID prefix (first 4 chars) in brackets for easy reference.

Group by status: PENDING first, then IN PROGRESS, then COMPLETED.

### Step 5: "Work on Item" Flow (AI-Powered Intent Detection)

This is the core feature - intelligent routing to the right workflow.

When user selects "Work on an item":

#### 5.1 Select Item

Ask which item (show the list, let them pick by ID or description match).

#### 5.2 Read Item Details

Read the item's title, detail, priority, and tags.

#### 5.3 Analyze Intent

Claude analyzes the item and determines what workflow would be most appropriate.

**Intent Detection Logic:**

Consider these factors:

- **Scope Keywords:**
  - Large scope: "build", "create", "implement", "develop", "design", "architecture", "system", "platform"
  - Small scope: "fix", "update", "tweak", "adjust", "change", "modify"

- **Complexity Indicators:**
  - Complex: "refactor", "redesign", "migrate", "integrate", "multi-", "full-stack"
  - Simple: "button", "color", "text", "copy", "label"

- **Domain Keywords:**
  - Planning level: "plan", "roadmap", "strategy", "epic", "milestone"
  - Execution level: "code", "test", "deploy", "commit"

#### 5.4 Present Recommendation

Show ONE primary suggestion with clear reasoning:

```
I think you want to: "Build a complete user dashboard with charts and analytics"

This looks like a multi-phase feature that would benefit from:

  → Phase Development Plan (Recommended)
    This has 3-4 distinct phases: data layer, chart components,
    dashboard layout, and polish. A phased plan would break it
    down systematically.

Other options:
  • Vision     - For autonomous MVP development (larger scope)
  • Epic       - For GitHub Epic with sub-issues (project tracking)
  • Roadmap    - For multi-milestone planning (long-term)
  • Task List  - For simple checklist (smaller scope)
  • Just do it - Skip planning, start coding directly

How would you like to proceed?
```

#### 5.5 User Choice

Let the user:

- Accept the recommendation (press enter or say "yes")
- Pick a different option from the list
- Say "elaborate" or "tell me more" to provide additional context
- Say "just do it" to skip planning and start immediately

#### 5.6 Route to Workflow

| Route | Action | When to Suggest |
|-------|--------|-----------------|
| Vision | Run `/vision-init` with the todo item as prompt | Large autonomous features (multi-component MVP) |
| Epic | Run `/create-github-epic` with the todo item | Project tracking with sub-issues needed |
| Roadmap | Run `/create-roadmap` with the todo item | Multi-milestone, long-term planning |
| Phase-Dev | Run `/phase-dev-plan` with the todo item | 3-5 distinct development phases |
| Task List | Run `/create-task-list` with the todo item | Simple checklist for small features |
| Just do it | Create inline TodoWrite tasks and start | Trivial changes, quick fixes |

**When routing:**

1. Show the command being executed: `Routing to Phase Development Plan...`
2. Pass the todo item's title and detail as the prompt/context
3. Let that workflow take over completely

#### 5.7 Update Todo Item

After routing (or if they start working directly):

1. Update the todo item in todos.json:
   ```json
   {
     "status": "in_progress",
     "routed_to": "phase-dev",
     "route_ref": "user-dashboard-charts",
     "updated_at": "2026-02-06T14:30:00Z"
   }
   ```

2. Write back to todos.json

3. Confirm: `Updated todo status to "in_progress" and routed to Phase Development Plan`

### Step 6: Complete Item

When completing an item:

1. Find the item by ID (or ask user to select if ID not provided)
2. Update the item:
   ```json
   {
     "status": "completed",
     "completed_at": "2026-02-06T15:00:00Z",
     "updated_at": "2026-02-06T15:00:00Z"
   }
   ```
3. Write back to todos.json
4. Display: `✓ Completed: "Fix login redirect on mobile"`
5. Show stats: `You have X pending items remaining`

### Step 7: Delete Item

When deleting an item:

1. Find the item by ID
2. Show full item details
3. Ask for confirmation: "Are you sure you want to delete this item? (yes/no)"
4. If confirmed:
   - Remove from todos array
   - Update metadata.total_items counter
   - Write back to todos.json
5. Display: `Deleted: "Fix login redirect on mobile"`

### Step 8: View Item Details

When viewing details:

Show full item with all fields:

```
╔═══════════════════════════════════════════════════╗
║  Todo Item Details                                ║
╠═══════════════════════════════════════════════════╣
║                                                   ║
║  ID:       a1b2c3d4e5f6                           ║
║  Title:    Fix login redirect on mobile           ║
║  Detail:   fix the login redirect bug on mobile   ║
║            devices when using Safari browser      ║
║  Status:   pending                                ║
║  Priority: medium                                 ║
║  Created:  2026-02-06 12:00                       ║
║  Updated:  2026-02-06 12:00                       ║
║  Tags:     bug, mobile, safari                    ║
║  Routed:   (not yet)                              ║
║                                                   ║
╚═══════════════════════════════════════════════════╝

What would you like to do?
  1. Work on this item
  2. Complete this item
  3. Delete this item
  4. Back to menu
```

## INTENT DETECTION EXAMPLES

### Example 1: Large Feature

**Todo:** "Build user dashboard with charts and analytics"

**Analysis:**
- "Build" suggests creation (not fix)
- "Dashboard" + "charts" + "analytics" = multiple components
- Likely needs data layer, UI components, integration

**Recommendation:** Phase Development Plan (3-4 phases)

### Example 2: Quick Fix

**Todo:** "Fix button color on login page"

**Analysis:**
- "Fix" suggests small change
- "Button color" is trivial scope
- Single file, single component

**Recommendation:** Just do it (inline tasks)

### Example 3: Architectural Change

**Todo:** "Refactor auth middleware to use JWT"

**Analysis:**
- "Refactor" suggests complexity
- "Auth middleware" affects multiple routes
- Security implications need testing

**Recommendation:** Task List with testing phase

### Example 4: Product Initiative

**Todo:** "Add dark mode to entire application"

**Analysis:**
- "Entire application" = large scope
- Multiple components, theming system
- User settings, persistence needed

**Recommendation:** Epic (with sub-issues for each component)

## RULES

1. Always read .claude/todos.json before any operation
2. Always write back to todos.json after any modification
3. Show helpful next-step suggestions after each action
4. The "Work on item" intent detection should be thoughtful and consider scope, complexity, and domain
5. Never auto-route without user confirmation - always present the recommendation and let them choose
6. Keep the menu concise and navigable
7. Use consistent formatting for all displays (box drawing characters)
8. When showing lists, truncate long titles to fit in the display box
9. Always show item count in the header: "Todo List (5 items)"
10. Group completed items at the bottom, pending at the top

## ERROR HANDLING

- If todos.json doesn't exist, guide user to /todo-add
- If invalid item ID provided, show error and list valid IDs
- If todos.json is corrupted, show error and suggest manual inspection
- If routing fails, keep todo item in original state and show error

## NEXT STEPS SUGGESTIONS

After each operation, suggest logical next actions:

- After completing: "Great! You have X pending items. Run /todo to pick the next one."
- After deleting: "Item removed. Run /todo list to see remaining items."
- After routing: "Your item is now being processed by [workflow]. Check back with /todo to see progress."
- After viewing details: "Ready to work on this? Choose an option above or run /todo work [id]"
