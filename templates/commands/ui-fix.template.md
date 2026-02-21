<!-- CCASP-CODEX-COMPAT:START -->
# Codex Runtime Compatibility

This prompt was authored for Claude-style slash workflows. In Codex runtime, adapt tool calls as follows:
- `AskUserQuestion` => ask the user directly in chat.
- `WebSearch`/`WebFetch` => use available web tools (`search_query`, `open`, `find`) and cite links.
- `Read`/`Write` => use shell/filesystem tools in this workspace.
- Claude-only MCP calls (for example Playwright MCP names) => use available equivalents or clearly state fallback.
- Keep intent and output format identical; only adapt execution mechanics.
<!-- CCASP-CODEX-COMPAT:END -->
<!-- CODEX-OVERRIDE:START -->
# ui-fix — Codex Runtime

Fix a UI issue. Playwright MCP screenshot/browser tools are unavailable in Codex, but I can fix code directly.

Describe what needs to be fixed and I'll:
1. Read the relevant component files
2. Identify the issue
3. Apply the fix
4. Optionally generate a regression test

**For live browser visual debugging, use Claude Code CLI: `/ui-fix`**
<!-- CODEX-OVERRIDE:END -->
---
description: Debug and fix Neovim UI issues with guided workflow
---

# Neovim UI Fix

Guided workflow to debug and fix nvim-ccasp UI issues. Reads a bug report or test failure, locates the root cause in Lua code, applies the smallest fix, and re-runs tests to verify.

## Usage

```
/ui-fix
/ui-fix "flyout doesn't close on Esc"
/ui-fix --from-test ui_smoke_spec
```

## Workflow

1. **Understand** - Read the bug report or test failure output
2. **Locate** - Identify the Lua module and function involved
3. **Diagnose** - Read the code, trace the logic, find the root cause
4. **Fix** - Apply the smallest change that resolves the issue
5. **Verify** - Run the specific test that failed (or smoke test)
6. **Report** - Summarize what was wrong and what was changed

## Fix Principles

- **Smallest fix first** - Don't refactor while fixing
- **One bug, one change** - Don't combine fixes
- **Test before and after** - Capture snapshot before fix, verify after
- **Don't break other tests** - Run full suite after fix

## Protocol

When the user runs `/ui-fix`:

1. If argument provided, use as bug description
2. If `--from-test`, read the specific test failure output
3. Search nvim-ccasp/lua/ for the relevant module
4. Read the code and identify the issue
5. Apply fix using Edit tool
6. Run `./scripts/nvim-smoke.ps1` to verify
7. If smoke passes, run `./scripts/nvim-test.ps1` for full suite
8. Report: what was wrong, what was changed, test results
