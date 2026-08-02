---
description: Quick-add a todo item with auto-paraphrasing
type: utility
complexity: low
model: haiku
argument-hint: [description of what you want to do]
allowed-tools:
  - Read
  - Write
  - AskUserQuestion
---

# /todo-add - Quick Add Todo Item

**Instantly capture a todo item. Claude auto-paraphrases to a concise 5-6 word title.**

---

## QUICK START

```bash
/todo-add fix the login redirect bug on mobile
/todo-add add dark mode toggle to settings page
/todo-add refactor the authentication middleware to use JWT
/todo-add                    # Interactive - Claude asks what to add
```

---

## EXECUTION FLOW

### Step 1: Parse Input

**If arguments provided:**
- Use them as the raw description
- Store as `RAW_INPUT`

**If no arguments:**
- Use AskUserQuestion:
  ```
  header: "Todo"
  question: "What do you want to add to your todo list?"
  ```
- Store response as `RAW_INPUT`

---

### Step 2: Auto-Paraphrase

Take the user's input and create:

**Title (5-6 words max):**
- Use imperative form: "Fix", "Add", "Refactor", "Update", "Create"
- Remove articles (a, an, the) unless absolutely necessary
- Keep it concise and actionable

**Examples:**

| User Input | Paraphrased Title |
|------------|-------------------|
| "I want to fix the login page redirect bug that happens on mobile devices" | "Fix login redirect on mobile" |
| "add a dark mode toggle to the settings page" | "Add dark mode settings toggle" |
| "refactor the authentication middleware to use JWT" | "Refactor auth middleware to JWT" |
| "create new API endpoint for user profile updates" | "Create user profile API endpoint" |

**Detail:**
- If `RAW_INPUT` is longer than 8 words, store the full original text
- Otherwise, store empty string `""`

---

### Step 3: Detect Priority

Scan `RAW_INPUT` for urgency keywords:

| Keywords | Priority |
|----------|----------|
| "urgent", "critical", "ASAP", "blocker", "emergency" | `critical` |
| "important", "high priority", "P1", "soon" | `high` |
| "nice to have", "low priority", "someday", "maybe" | `low` |
| No keywords | `medium` |

Store as `PRIORITY`.

---

### Step 4: Confirm with User

Display the paraphrased title and ask for confirmation:

```
╔═══════════════════════════════════════════════════════════════╗
║  📋 Todo Preview                                              ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Title: "Fix login redirect on mobile"                       ║
║  Priority: medium                                             ║
║                                                               ║
{{#if DETAIL}}
║  Detail: "fix the login redirect bug on mobile devices       ║
║           when using Safari"                                  ║
{{/if}}
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

**Ask user using AskUserQuestion:**
```
header: "Confirm"
question: "Add this todo?"
options:
  - label: "Yes - Add it"
    description: "Add this todo to the list"
  - label: "Edit title"
    description: "I want to customize the title"
  - label: "Cancel"
    description: "Don't add anything"
```

**Handle response:**
- **"Yes - Add it"**: Proceed to Step 5
- **"Edit title"**: Ask for custom title, enforce 5-6 word limit, then proceed
- **"Cancel"**: Exit gracefully with message "Todo not added."

---

### Step 5: Read Existing Todos

**Read `.claude/todos.json`:**

**If file exists:**
- Parse the JSON
- Store existing todos array

**If file doesn't exist:**
- Create initial structure:
  ```json
  {
    "todos": [],
    "metadata": {
      "version": "1.0.0",
      "last_modified": "",
      "total_items": 0
    }
  }
  ```

---

### Step 6: Generate Unique ID

Generate a unique 8-character lowercase alphanumeric ID.

**Algorithm:**
```javascript
const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
let id = '';
for (let i = 0; i < 8; i++) {
  id += chars[Math.floor(Math.random() * chars.length)];
}

// Check for collision with existing IDs
while (existingTodos.some(t => t.id === id)) {
  // Regenerate if collision
}
```

Store as `TODO_ID`.

---

### Step 7: Add New Item

Create new todo object:

```json
{
  "id": "a1b2c3d4",
  "title": "Fix login redirect on mobile",
  "detail": "fix the login redirect bug on mobile devices when using Safari",
  "status": "pending",
  "priority": "medium",
  "tags": [],
  "created_at": "2026-02-06T12:00:00Z",
  "updated_at": "2026-02-06T12:00:00Z",
  "completed_at": null,
  "routed_to": null,
  "route_ref": null
}
```

**Field descriptions:**
- `id`: Unique 8-char identifier
- `title`: Paraphrased 5-6 word title
- `detail`: Original verbose description (if >8 words)
- `status`: Always `"pending"` for new items
- `priority`: `"critical"` | `"high"` | `"medium"` | `"low"`
- `tags`: Empty array (user can add later via `/todo`)
- `created_at`: ISO 8601 timestamp
- `updated_at`: ISO 8601 timestamp (same as created_at initially)
- `completed_at`: `null` (set when marked complete)
- `routed_to`: `null` (for future agent routing)
- `route_ref`: `null` (for future task list references)

Append to `todos` array.

---

### Step 8: Update Metadata

Update metadata:
```json
{
  "version": "1.0.0",
  "last_modified": "2026-02-06T12:00:00Z",
  "total_items": 5
}
```

- `last_modified`: Current timestamp
- `total_items`: Length of todos array

---

### Step 9: Write Updated File

Write the complete updated JSON back to `.claude/todos.json`:

```json
{
  "todos": [
    {
      "id": "a1b2c3d4",
      "title": "Fix login redirect on mobile",
      ...
    },
    ...
  ],
  "metadata": {
    "version": "1.0.0",
    "last_modified": "2026-02-06T12:00:00Z",
    "total_items": 5
  }
}
```

---

### Step 10: Confirm Success

Display success message with statistics:

```
╔═══════════════════════════════════════════════════════════════╗
║  ✅ Todo Added                                                 ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  "Fix login redirect on mobile"                              ║
║                                                               ║
║  ID: a1b2c3d4                                                 ║
║  Priority: medium                                             ║
║                                                               ║
╠═══════════════════════════════════════════════════════════════╣
║  Total todos: 5                                               ║
║    • 3 pending                                                ║
║    • 1 in progress                                            ║
║    • 1 completed                                              ║
╠═══════════════════════════════════════════════════════════════╣
║  Quick actions:                                               ║
║    /todo          - View & manage todos                       ║
║    /todo-add      - Add another item                          ║
╚═══════════════════════════════════════════════════════════════╝
```

**Statistics calculation:**
- Count todos by status: `pending`, `in-progress`, `completed`
- Display counts in the summary

---

## RULES

1. **Title MUST be 5-6 words max.** No exceptions.
2. **Use imperative form**: "Fix", "Add", "Refactor", "Update", "Create"
3. **No articles** (a, an, the) in titles unless absolutely necessary for clarity
4. **Store original verbose text** in `detail` field if input >8 words
5. **Never overwrite existing todos** - always append
6. **Generate unique IDs** that don't collide with existing ones
7. **Auto-detect priority** from urgency keywords
8. **Always confirm** before adding (unless user provides explicit instruction to skip)

---

## PRIORITY DETECTION EXAMPLES

| Input | Detected Priority |
|-------|-------------------|
| "urgent fix for production bug" | `critical` |
| "blocker: login not working" | `critical` |
| "important: update API docs" | `high` |
| "P1 - refactor auth flow" | `high` |
| "nice to have: add animations" | `low` |
| "someday implement caching" | `low` |
| "add dark mode toggle" | `medium` (default) |

---

## ERROR HANDLING

| Situation | Action |
|-----------|--------|
| `.claude/todos.json` is invalid JSON | Show error, offer to backup and create new file |
| User provides >10 word title in edit mode | Ask to shorten to 5-6 words |
| ID collision (rare) | Regenerate new ID automatically |
| File write fails | Display error with file path and permission hints |

---

## RELATED COMMANDS

- `/todo` - View and manage all todos (interactive dashboard)
- `/todo-complete [id]` - Mark a todo as complete
- `/todo-start [id]` - Mark a todo as in-progress
- `/todo-delete [id]` - Delete a todo
- `/create-task-list` - Convert todo into full task list with GitHub integration

---

*Generated from CCASP command template*
