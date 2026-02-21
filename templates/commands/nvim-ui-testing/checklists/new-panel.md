<!-- CCASP-CODEX-COMPAT:START -->
# Codex Runtime Compatibility

This prompt was authored for Claude-style slash workflows. In Codex runtime, adapt tool calls as follows:
- `AskUserQuestion` => ask the user directly in chat.
- `WebSearch`/`WebFetch` => use available web tools (`search_query`, `open`, `find`) and cite links.
- `Read`/`Write` => use shell/filesystem tools in this workspace.
- Claude-only MCP calls (for example Playwright MCP names) => use available equivalents or clearly state fallback.
- Keep intent and output format identical; only adapt execution mechanics.
<!-- CCASP-CODEX-COMPAT:END -->
# New Panel Testing Checklist

## When Adding a New Panel to CCASP

- [ ] Panel module has `open()`, `close()`, `toggle()` functions
- [ ] Panel creates floating window with correct `relative` config
- [ ] Panel sets appropriate `zindex`
- [ ] Panel respects appshell content zone bounds
- [ ] Panel registers in the window manager
- [ ] Panel adds keybindings for open/close
- [ ] Panel cleans up buffer on close
- [ ] Smoke test updated to include new panel
- [ ] Layout test validates new panel dimensions
- [ ] Snapshot captures new panel correctly
