---
description: GitHub Epic management dashboard
model: sonnet
---

# GitHub Epic Menu - Epic Management Dashboard

You are an Epic management specialist using the CCASP GitHub Epic System. Display and manage GitHub Epics with a mobile and desktop-friendly interface.

## Concepts

**Epic vs Roadmap:**
- **Epic** = A large unit of work (the "what" - a major feature or initiative)
- **Roadmap** = Timeline of where all work is going (the "when" - scheduling and sequencing)

**Hierarchy:**
```
Vision (Why)
  |
Roadmap (When)
  |
Epic (What)
  |
Stories / Tasks (How)
```

## Execution Protocol

### Step 1: Detect Display Mode

Check environment for display mode:
- **Desktop**: Full-width tables, detailed views, Mermaid graphs
- **Mobile**: Compact single-char menus, abbreviated tables, scrollable lists

Detect via:
- `HAPPY_CLI` environment variable
- `happyMode.enabled` in tech-stack.json
- Terminal width < 80 characters

### Step 2: Load Epics

Load all epics from:
- `.claude/github-epics/` directory (new location)
- `.claude/roadmaps/` directory (legacy, migrate if found)

For each epic, gather:
- Slug, title, description
- Phase count and completion percentage
- GitHub integration status
- Last updated timestamp

### Step 3: Display Epic Menu

#### Desktop Mode (width >= 80)

```
+============================================================================+
|                        GITHUB EPIC MANAGEMENT                               |
+============================================================================+

Epics Overview:
+----+----------------------+--------+----------+---------+------------------+
| #  | Epic Name            | Phases | Progress | GitHub  | Last Updated     |
+----+----------------------+--------+----------+---------+------------------+
| 1  | AI Agent Orchestrator| 5      | 40%      | #123    | 2024-01-15 14:30 |
| 2  | RepoGuard System     | 7      | 0%       | -       | 2024-01-14 09:15 |
| 3  | Multi-tenant SaaS    | 4      | 100%     | #98     | 2024-01-10 16:45 |
+----+----------------------+--------+----------+---------+------------------+

Commands:
  [V] View Epic Details    [N] New Epic        [S] Sync with GitHub
  [E] Edit Epic            [D] Delete Epic     [T] Testing Issues
  [R] Resume Epic          [B] Back

Select (1-3, or command):
```

#### Mobile Mode (width < 80)

```
+============================+
|     GITHUB EPICS          |
+============================+

[1] AI Agent (40%) #123
[2] RepoGuard (0%) -
[3] Multi-tenant (100%) #98

[V]iew [N]ew [S]ync
[E]dit [D]el [T]est
[R]esume [B]ack

Choice:
```

### Step 4: Handle Selection

Based on user input:

**Number (1-N):** Select epic for operations
**V:** View selected epic details
**N:** Create new epic (redirect to /create-github-epic)
**S:** Sync all epics with GitHub
**E:** Edit selected epic structure
**D:** Delete selected epic (with confirmation)
**T:** Create/view testing issues for epic
**R:** Resume work on selected epic
**B:** Back to main menu

### Step 5: Epic Details View

When viewing an epic:

```
+============================================================================+
|  EPIC: AI Agent Orchestrator                                                |
+============================================================================+

Description: Build a multi-tier agent system for autonomous task execution

Status: active          | Created: 2024-01-10
Progress: 40% (2/5)     | GitHub: #123

Phases:
+---+--------------------+------------+----------+---------+
| # | Phase              | Complexity | Status   | Deps    |
+---+--------------------+------------+----------+---------+
| 1 | Foundation         | M          | complete | -       |
| 2 | Agent Registry     | M          | complete | 1       |
| 3 | L2 Specialists     | L          | active   | 2       |
| 4 | L3 Workers         | M          | pending  | 3       |
| 5 | Integration        | L          | pending  | 3,4     |
+---+--------------------+------------+----------+---------+

Dependency Graph:
\`\`\`mermaid
graph LR
  P1[Foundation] --> P2[Agent Registry]
  P2 --> P3[L2 Specialists]
  P3 --> P4[L3 Workers]
  P3 --> P5[Integration]
  P4 --> P5
\`\`\`

Actions:
  [S] Start Next Phase (Phase 3: L2 Specialists)
  [G] Open GitHub Issue (#123)
  [T] Create Testing Issues
  [E] Edit Epic
  [B] Back to Epic List
```

### Step 6: Testing Issue Generation

When user selects Testing Issues (T):

1. For each completed phase in the epic:
   - Generate a testing issue template
   - Schedule testing for sequential days starting day after epic completion
   - Include RALPH loop testing configuration
   - Include manual user testing checklist

Testing Issue Structure:
```markdown
## Phase Testing: [Phase Name]

**Epic:** [Epic Name]
**Phase:** [Phase Number]
**Scheduled:** [Date - day N after epic completion]

### Automated Testing (RALPH Loop)

- [ ] Run unit tests: `npm test`
- [ ] Run integration tests: `npm run test:integration`
- [ ] Run E2E tests: `npm run test:e2e`

### Manual User Testing Checklist

- [ ] Feature works as described in acceptance criteria
- [ ] No visual regressions
- [ ] Responsive design verified
- [ ] Error states handled gracefully
- [ ] Performance acceptable
- [ ] Accessibility verified

### Web Research (Pre-Testing)
Agent will search for:
- Known issues with similar implementations
- Best practices for testing this feature type
- Common edge cases to verify

### Notes
_Add testing observations here_
```

## Session Restart Check

Before executing epic operations that require agents:

1. Check if `.claude/github-epics-initialized` exists
2. If not, display warning:

```
+============================================================================+
|  SESSION RESTART REQUIRED                                                   |
+============================================================================+

The GitHub Epic system with tech stack enabled agents has been initialized
but requires a session restart to activate the agent configurations.

Please:
1. Exit this Claude Code session
2. Restart Claude Code CLI
3. Run /github-epic-menu again

This ensures all agent configurations and hooks are properly loaded.
```

3. Create `.claude/github-epics-initialized` marker file
4. Return without proceeding

## Migration from Roadmaps

If legacy `.claude/roadmaps/` directory found:

1. Offer to migrate to `.claude/github-epics/`
2. Rename files while preserving content
3. Update internal references
4. Remove legacy directory after successful migration

## Error Handling

- If no epics found: Offer to create new epic
- If GitHub sync fails: Show error, offer retry
- If epic file corrupted: Show error, offer repair or delete

## Related Commands

- `/create-github-epic` - Create new GitHub Epic
- `/github-epic-status` - View epic progress dashboard
- `/github-epic-edit` - Edit epic phases and structure
- `/github-epic-track` - Track epic execution
- `/phase-track` - Track individual phase progress

---

*GitHub Epic Menu - Part of CCASP GitHub Epic System*
