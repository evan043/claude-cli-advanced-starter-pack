<!-- CCASP-CODEX-COMPAT:START -->
# Codex Runtime Compatibility

This prompt was authored for Claude-style slash workflows. In Codex runtime, adapt tool calls as follows:
- `AskUserQuestion` => ask the user directly in chat.
- `WebSearch`/`WebFetch` => use available web tools (`search_query`, `open`, `find`) and cite links.
- `Read`/`Write` => use shell/filesystem tools in this workspace.
- Claude-only MCP calls (for example Playwright MCP names) => use available equivalents or clearly state fallback.
- Keep intent and output format identical; only adapt execution mechanics.
<!-- CCASP-CODEX-COMPAT:END -->
# Example: Smoke Test Workflow

## Scenario
You've made changes to the appshell icon rail and want to verify nothing broke.

## Steps

1. Run smoke test:
   ```
   /ui-smoke
   ```

2. Claude will execute `scripts/nvim-smoke.ps1` which:
   - Opens Neovim headless with minimal_init.lua
   - Loads ccasp in appshell layout
   - Traverses icon rail sections
   - Opens/closes flyout
   - Validates floating windows
   - Reports pass/fail

3. If failures occur, run the fix workflow:
   ```
   /ui-fix
   ```

## Expected Output
```
=== CCASP Smoke Test ===
[PASS] Plugin loads without errors
[PASS] Appshell opens with 6 zones
[PASS] Flyout toggles correctly
[PASS] Close tears down cleanly
4/4 tests passed
```
