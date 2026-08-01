---
description: Pre-commit guard - run UI tests and lint checks before committing
---

# Repository Guard

Pre-commit quality gate that runs Neovim UI tests, checks for common issues, and prevents commits with broken UI.

## Usage

```
/repo-guard
/repo-guard --quick
/repo-guard --full
```

## Checks Performed

### Quick Mode (default)
1. **Lua syntax** - Check all .lua files parse without errors
2. **Module loads** - Verify all ccasp modules can be required
3. **Smoke test** - Run ui_smoke_spec.lua

### Full Mode
1. Everything in quick mode, plus:
2. **Full test suite** - All spec files
3. **Layout snapshot** - Compare with last known-good snapshot
4. **Keymap validation** - All keymaps registered correctly

## Protocol

When the user runs `/repo-guard`:

1. Determine mode (quick or full)
2. Run Lua syntax check: `nvim --headless -c "luafile nvim-ccasp/lua/ccasp/init.lua" -c "qa"`
3. Run smoke test: `./scripts/nvim-smoke.ps1`
4. If full mode, run: `./scripts/nvim-test.ps1`
5. Report results with pass/fail for each check
6. If all pass: "Safe to commit"
7. If any fail: "Fix issues before committing" with details
