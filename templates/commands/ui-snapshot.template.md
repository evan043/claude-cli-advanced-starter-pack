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
# ui-snapshot — Codex Runtime

Capture UI snapshots for visual regression. Playwright MCP is unavailable in Codex.

## Alternative: Update Playwright Snapshots via Shell

```bash
# Update all snapshots
npx playwright test --update-snapshots

# Update snapshots for specific test
npx playwright test tests/visual.spec.ts --update-snapshots
```

**For live Playwright MCP snapshot capture, use Claude Code CLI: `/ui-snapshot`**
<!-- CODEX-OVERRIDE:END -->
---
description: Capture Neovim window layout snapshot for debugging
---

# Neovim UI Layout Snapshot

Capture a complete snapshot of all Neovim windows (including floating window configs) for debugging and regression tracking.

## Usage

```
/ui-snapshot
/ui-snapshot --json
/ui-snapshot --diff previous
```

## Snapshot Contents

For every window:
- Window ID and buffer number
- Buffer name and filetype
- Is floating (true/false)
- Float config: row, col, width, height, zindex, border
- Window highlight settings

Plus global state:
- Editor dimensions (columns x lines)
- Active window and cursor position
- Appshell state (active section, flyout visible, rail visible)
- Session list with running status

## Running

```powershell
# Capture to file
./scripts/nvim-snapshot.ps1

# Output is saved to:
# nvim-ccasp/tests/artifacts/last-snapshot.txt (human readable)
# nvim-ccasp/tests/artifacts/last-snapshot.json (machine readable)
```

## Protocol

When the user runs `/ui-snapshot`:

1. Execute `./scripts/nvim-snapshot.ps1`
2. Read and display the text snapshot
3. Note any anomalies (unexpected floats, missing windows, odd dimensions)
4. If `--diff` specified, compare with previous snapshot and highlight changes
