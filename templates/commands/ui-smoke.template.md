
<!-- CODEX-OVERRIDE:START -->
# ui-smoke — Codex Runtime

Run smoke tests via shell. Playwright MCP is unavailable in Codex.

```bash
# Run only smoke-tagged tests
npx playwright test --grep "smoke"

# Or run the smoke test suite file directly
npx playwright test e2e/smoke.spec.ts
```

If no smoke tests exist yet, tell me and I'll generate a basic smoke test file.

**For Playwright MCP browser integration, use Claude Code CLI: `/ui-smoke`**
<!-- CODEX-OVERRIDE:END -->
---
description: Run quick Neovim UI smoke test for nvim-ccasp
---

# Neovim UI Smoke Test

Run a fast smoke test that opens the CCASP UI, traverses key menu items, opens popouts, validates windows/buffers, then closes cleanly.

## Usage

```
/ui-smoke
```

## What It Does

1. Launch nvim headless with ccasp plugin
2. Call `require("ccasp").setup({layout="appshell"})` and `open()`
3. Verify icon rail, header, and footer windows exist
4. Toggle flyout for each of the 5 sections
5. Toggle right panel on/off
6. Close everything and verify clean state (no lingering floats)

## Pass/Fail Criteria

- **PASS**: All steps complete, no Lua errors, no orphaned windows
- **FAIL**: Any step throws, windows don't appear, or cleanup leaves orphans

## Running

```powershell
./scripts/nvim-smoke.ps1
```

## Protocol

When the user runs `/ui-smoke`:

1. Execute `./scripts/nvim-smoke.ps1`
2. Parse output for PASS/FAIL
3. If FAIL: capture snapshot, show exact failure step
4. If PASS: report clean result with timing
