
<!-- CODEX-OVERRIDE:START -->
# ui-bug — Codex Runtime

Investigate and fix a UI bug. Playwright MCP (browser screenshot/interaction) is unavailable in Codex.

## What I Can Do Without Playwright MCP

1. **Read the source code** of the affected component
2. **Analyze the bug** based on your description
3. **Propose a fix** with code changes
4. **Generate a test** to reproduce and verify the fix
5. **Run the test** via: `npx playwright test --grep "bug-description"`

## To Start

Describe the UI bug you're seeing (what component, what behavior, what's expected). I'll investigate the code and propose a fix.

**For live browser screenshot debugging, use Claude Code CLI: `/ui-bug`**
<!-- CODEX-OVERRIDE:END -->
---
description: File a structured bug report for Neovim UI issues
---

# Neovim UI Bug Report

Create a structured bug report for nvim-ccasp UI issues with automatic context gathering (layout snapshot, error logs, reproduction steps).

## Usage

```
/ui-bug
/ui-bug "flyout doesn't close when pressing Esc"
/ui-bug --with-snapshot
```

## Bug Report Template

The command generates a structured report containing:

1. **Summary** - One-line description
2. **Environment** - Neovim version, OS, terminal, ccasp version
3. **Steps to Reproduce** - Numbered list of actions
4. **Expected Behavior** - What should happen
5. **Actual Behavior** - What happens instead
6. **Layout Snapshot** - Auto-captured window state at time of bug
7. **Error Log** - Any Lua errors from vim.v.errmsg or :messages
8. **Affected Files** - Which Lua modules are likely involved

## Protocol

When the user runs `/ui-bug`:

1. Ask for a brief description of the issue (or use argument)
2. Run `./scripts/nvim-snapshot.ps1` to capture current state
3. Check `:messages` output for recent errors
4. Identify the likely affected module(s) based on description
5. Generate structured bug report in markdown
6. Optionally create a GitHub issue with `/github-task`
