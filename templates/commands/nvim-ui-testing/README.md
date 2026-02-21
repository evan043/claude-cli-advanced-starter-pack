<!-- CCASP-CODEX-COMPAT:START -->
# Codex Runtime Compatibility

This prompt was authored for Claude-style slash workflows. In Codex runtime, adapt tool calls as follows:
- `AskUserQuestion` => ask the user directly in chat.
- `WebSearch`/`WebFetch` => use available web tools (`search_query`, `open`, `find`) and cite links.
- `Read`/`Write` => use shell/filesystem tools in this workspace.
- Claude-only MCP calls (for example Playwright MCP names) => use available equivalents or clearly state fallback.
- Keep intent and output format identical; only adapt execution mechanics.
<!-- CCASP-CODEX-COMPAT:END -->
# Neovim UI Testing Commands

Slash commands for Neovim UI testing workflows.

## Available Commands

| Command | Template | Purpose |
|---------|----------|---------|
| `/ui-test` | `ui-test.template.md` | Run full UI test suite |
| `/ui-smoke` | `ui-smoke.template.md` | Quick smoke test |
| `/ui-snapshot` | `ui-snapshot.template.md` | Capture layout snapshot |
| `/ui-bug` | `ui-bug.template.md` | Report UI bug with structured data |
| `/ui-fix` | `ui-fix.template.md` | Guided debug/fix workflow |
| `/repo-guard` | `repo-guard.template.md` | Pre-commit quality gate |

## Usage

After `ccasp init`, these commands are available as `/command-name` in Claude Code CLI.

## Related

- Agents: `templates/agents/testing/` (ui-driver, ui-debugger, nvim-test-runner)
- Hooks: `templates/hooks/` (nvim-after-edit-test, agent-limit-compact)
- Skills: `templates/skills/nvim-ui-test/`
