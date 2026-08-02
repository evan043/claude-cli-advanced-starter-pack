
<!-- CODEX-OVERRIDE:START -->
# ui-test — Codex Runtime

This command runs Playwright E2E tests. Playwright MCP is unavailable in Codex, but I can run tests via shell if Playwright is installed.

## Run Tests via Shell

```bash
# Run all E2E tests
npx playwright test

# Run with headed browser (if display available)
npx playwright test --headed

# Run specific test file
npx playwright test tests/auth.spec.ts

# Run with specific grep pattern
npx playwright test --grep "login"
```

## View Test Results

```bash
# Show HTML report
npx playwright show-report

# Show test output in terminal
npx playwright test --reporter=list
```

Tell me which tests to run and I'll execute them via shell commands.

**For Playwright MCP integration with visual browser control, use Claude Code CLI: `/ui-test`**
<!-- CODEX-OVERRIDE:END -->
---
description: Run Neovim UI tests for the nvim-ccasp plugin
---

# Run Neovim UI Tests

Execute the full plenary.nvim test suite for the nvim-ccasp Neovim plugin, covering smoke tests, keymap validation, and layout structure verification.

## Usage

```
/ui-test
/ui-test --filter smoke
/ui-test --filter keymaps
/ui-test --filter layout
```

## What It Does

1. **Detect Environment** - Verify nvim and plenary.nvim are available
2. **Run Tests** - Execute headless Neovim tests via PlenaryBusted
3. **Report Results** - Parse output and display pass/fail summary
4. **Capture Artifacts** - Save layout snapshots on failure

## Test Categories

### Smoke Tests (`ui_smoke_spec.lua`)
- Setup loads without errors
- Appshell chrome opens (icon rail, header, footer)
- Flyout opens/closes for each section
- Clean teardown with no lingering windows

### Keymap Tests (`keymaps_spec.lua`)
- Ctrl+B, Ctrl+Shift+B, Ctrl+Shift+P registered in appshell mode
- Alt+1 through Alt+5 section shortcuts
- Session management keymaps (Ctrl+Tab, backtick)
- All CcaspXxx commands exist

### Layout Tests (`layout_spec.lua`)
- Zone calculations produce correct bounds
- Icon rail width = 3 columns
- Content zone fills remaining space
- Footer positioned at bottom
- Zones update when config changes

## Running Manually

```powershell
# Full suite
./scripts/nvim-test.ps1

# Smoke only
./scripts/nvim-smoke.ps1

# With filter
./scripts/nvim-test.ps1 -Filter "smoke"
```

## On Failure

When tests fail:
1. A layout snapshot is automatically captured to `nvim-ccasp/tests/artifacts/`
2. The failing assertion and line number are printed
3. Use `/ui-snapshot` to manually inspect current state
4. Use `/ui-bug` to file a structured bug report

## Protocol

When the user runs `/ui-test`:

1. Run `./scripts/nvim-test.ps1` and capture output
2. Parse the output for pass/fail counts
3. If failures exist:
   - Show the exact failing test name and assertion
   - Run `./scripts/nvim-snapshot.ps1` to capture state
   - Suggest running `/ui-fix` with the failure details
4. If all pass: report success with test count
