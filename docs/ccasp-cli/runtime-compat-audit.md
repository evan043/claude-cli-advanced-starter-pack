# Claude/Codex Runtime Compatibility Audit

Date: 2026-02-21

## Web-validated assumptions to scan

The following assumptions are runtime-specific and should be treated as portability risks:

- `AskUserQuestion` style tool calls (Claude-specific workflow helper)
- `WebSearch`/`WebFetch` symbolic tool names (agent-runtime aliases, not universal APIs)
- Claude MCP alias calls (for example `mcp__playwright-ext__...`) where transport/name can differ by runtime
- Generic `Read`/`Write` tool references that assume a specific tool namespace instead of shell/filesystem

Primary references:
- Anthropic Claude Code docs (settings + slash command behavior): https://docs.anthropic.com/en/docs/claude-code/settings
- Anthropic Claude Code slash command docs: https://docs.anthropic.com/en/docs/claude-code/slash-commands
- OpenAI Codex repo docs (AGENTS, runtime workflow): https://github.com/openai/codex
- OpenAI Codex issue tracker (slash command + prompt path behavior discussion): https://github.com/openai/codex/issues

## Scanner and smoke scripts

- `scripts/scan-runtime-compat.mjs`
  - Scans markdown/code files for cross-runtime tool assumptions.
  - Reports `totals` and `shimAdaptedTotals`.
- `scripts/smoke-codex-claude-sync.mjs`
  - Runs `runInit()` in an isolated temp project.
  - Verifies:
    - `.claude/commands/*.md` sync to `.codex/prompts/*.md`
    - `AGENTS.md` slash-router block exists
    - Codex compatibility shim is injected into synced prompts

## Current scan summary (full repo)

From `npm run scan:runtime-compat`:

- Scanned files: `2076`
- Matched files: `707`
- Unadapted totals:
  - `ask_user_question`: `407`
  - `websearch_tool`: `95`
  - `webfetch_tool`: `51`
  - `claude_mcp_call`: `106`
  - `generic_read_write_tools`: `88`
  - `claude_code_phrase`: `630`
- Adapted by Codex shim:
  - `ask_user_question`: `377`
  - `websearch_tool`: `263`
  - `webfetch_tool`: `251`
  - `claude_mcp_call`: `8`
  - `generic_read_write_tools`: `19`
  - `claude_code_phrase`: `107`

## Highest-priority source prompts to harden further

These are source prompts with the highest unadapted cross-runtime assumptions:

- `templates/commands/project-implementation-for-ccasp.template.md`
- `templates/commands/vision-init.template.md`
- `templates/commands/create-task-list.template.md`
- `templates/commands/vision-new-product.template.md`

Note: many additional hits are from backup/runtime mirror folders under `.ccasp/` and `.claude-backup/`.
