---
description: Mobile-optimized menu for Happy CLI (40-char width, no overflow)
model: sonnet
---

# /menu-happy - Mobile Mode Menu

## Purpose

Display CCASP menu in mobile-friendly format. Use from Happy CLI sessions.

**Session-Specific**: This command always shows mobile format. Desktop users should use `/menu` instead. Each session uses its own command - no shared config files.

## Instructions for Claude

When this command is invoked:

### Step 1: Read Update State

Read `.claude/config/ccasp-state.json` for version info:

```bash
cat .claude/config/ccasp-state.json 2>/dev/null || echo "{}"
```

Parse the JSON to extract:
- `currentVersion`: Installed CCASP version
- `latestVersion`: Latest version on npm
- `updateAvailable`: Boolean indicating if update exists

### Step 2: Display Mobile Menu

**ALWAYS use this mobile format (40 characters max width):**

```
┌────────────────────────────────────┐
│ CCASP Menu                         │
│ v{{VERSION}}                       │
└────────────────────────────────────┘

 ✓ Configured

──────────────────────────────────────
Quick Actions:
──────────────────────────────────────

[T] Run Tests
    E2E tests with Playwright

[G] GitHub Task
    Create tasks from issues

[P] Phase Dev Plan
    95%+ success rate planning

[A] Create Agent
    L1/L2/L3 orchestrators

[H] Create Hook
    Enforcement hooks

[S] Create Skill
    RAG-enhanced skills

[M] Explore MCP
    Discover MCP servers

[C] Claude Audit
    Best practices check

[E] Explore Codebase
    Structure analysis

──────────────────────────────────────
Resources:
──────────────────────────────────────

[1] View Agents
[2] View Skills
[3] View Hooks
[4] All Commands

──────────────────────────────────────
Project:
──────────────────────────────────────

[I] /project-impl
    Setup & configuration

[5] Settings

──────────────────────────────────────
Navigation:
──────────────────────────────────────

[U] Check Updates
[R] Refresh Menu
[?] Help
[Q] Exit

Enter key:
```

### Step 3: Handle Selection

Process user input using these key bindings:

| Key | Action | Command |
|-----|--------|---------|
| **T** | Run E2E Tests | `/e2e-test` |
| **G** | Create GitHub Task | `/github-task` |
| **P** | Create Phase Dev Plan | `/phase-dev-plan` |
| **A** | Create Agent | `/create-agent` |
| **H** | Create Hook | `/create-hook` |
| **S** | Create Skill | `/create-skill` |
| **M** | Explore MCP Servers | `/explore-mcp` |
| **C** | Claude Audit | `/claude-audit` |
| **E** | Explore Codebase | `/codebase-explorer` |
| **1** | List project agents | Read `.claude/agents/` |
| **2** | List project skills | Read `.claude/skills/` |
| **3** | List active hooks | Read `.claude/hooks/` |
| **4** | List all commands | Read `.claude/commands/INDEX.md` |
| **I** | Project Implementation | `/project-impl` |
| **5** | View/edit settings | Read `.claude/settings.json` |
| **U** | Check for Updates | `/update-check` |
| **N** | Update Now | Run npm update (if update available) |
| **R** | Refresh and redisplay menu | Re-invoke `/menu-happy` |
| **?** | Show help | Display command descriptions |
| **Q** | Exit menu | End menu interaction |

### Mobile Response Formatting

**CRITICAL**: When executing actions from this menu, format ALL responses for mobile:

- **Max 40 characters per line**
- **Stacked single-column layouts** (no side-by-side content)
- **Minimal decorations** (simple box chars only)
- **No wide tables** (use stacked key-value pairs instead)
- **Word wrap at word boundaries** (no mid-word breaks)

#### Mobile Formatting Rules

1. **Box characters**: Use `┌─┐│└┘` for boxes
2. **Separators**: Use `─` repeated 36 times
3. **Lists**: One item per line with indent
4. **No multi-column**: Everything stacked vertically
5. **Truncate long text**: Use `...` if needed

#### Example Mobile Response Format

Instead of wide table:
```
| Command | Description | Category |
|---------|-------------|----------|
| /menu   | Main menu   | Nav      |
```

Use stacked format:
```
──────────────────────────────────────
/menu
  Main menu
  Category: Nav
──────────────────────────────────────
```

### Settings Submenu (Mobile)

When user selects **[5] Settings**, show mobile-formatted settings:

```
┌────────────────────────────────────┐
│ Settings                           │
└────────────────────────────────────┘

[1] Edit permissions
[2] Testing config
[3] GitHub config
[4] Deployment
[5] Tunnel service

[B] Back to menu
```

### Update Banner (Mobile)

If `updateAvailable: true`, show compact banner:

```
┌────────────────────────────────────┐
│ 📦 Update: v1.0.5 → v1.0.6        │
│ Press [N] to update               │
└────────────────────────────────────┘
```

## Related Commands

- `/menu` - Desktop menu (always desktop format)
- `/menu-for-happy-ui` - Alias for this command
- `/happy-start` - Initialize Happy Mode session

---

*Mobile menu for Happy.Engineering CLI users*
