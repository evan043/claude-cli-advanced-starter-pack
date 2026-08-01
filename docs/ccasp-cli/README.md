# CCASP CLI (Draft)

CCASP is a cross-platform, runtime-agnostic AI orchestration framework that unifies Claude and Codex runtimes under a single `.ccasp/` source of truth.

## Quick Start

### macOS

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install pyyaml
python -m ccasp_cli.cli init
```

### Windows (PowerShell)

```powershell
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install pyyaml
python -m ccasp_cli.cli init
```

## Dual Runtime Explained

CCASP generates runtime adapters for both Claude and Codex from the same YAML command definitions in `.ccasp/commands/`. The `.claude` and `.codex` directories are symlinks (or junctions on Windows) pointing to `.ccasp/runtime/claude` and `.ccasp/runtime/codex`.

## Legacy Conversion Guide

If `.claude/`, `.codex/`, or `CLAUDE.md` are present, CCASP offers conversion. Legacy files are preserved in `.ccasp/legacy_backup/<timestamp>/`. Custom Claude commands and hooks are converted into unified YAML and copied into `.ccasp/commands/` and `.ccasp/hooks/`.

## Architecture Diagram

```text
.ccasp/
  core/
  commands/           # YAML command definitions
  agents/
  hooks/
  templates/
  runtime/
    claude/           # Claude-compatible artifacts
    codex/            # Codex-compatible artifacts
  legacy_backup/
  config.yaml

.claude  -> .ccasp/runtime/claude
.codex   -> .ccasp/runtime/codex
```

## Extending Commands

1. Add a new YAML file to `.ccasp/commands/`.
2. Re-run `ccasp init` or `ccasp wizard` to regenerate runtime artifacts.

Example:

```yaml
id: review
title: Review Changes
description: Provide a high-level review summary and risks.
system: You are a senior systems architect.
instructions:
  - Summarize key changes.
  - Identify regressions and risks.
  - Recommend tests and next steps.
```

## Runtime Comparison: Claude Code CLI vs Codex

CCASP commands are tagged with a `codex_support` tier. Commands are grouped into three categories:

| Tier | Claude Code CLI | Codex | Examples |
|------|-----------------|-------|---------|
| ✅ **full** | Native | Full support | `ask-claude`, `create-roadmap`, `phase-dev-plan`, `security-scan`, `refactor-analyze` |
| ⚠️  **partial** | Native | Works with manual steps | `vision-run`, `vision-init`, `ccasp-setup`, `db-migrate`, `orchestration-guide` |
| ❌ **unsupported** | Native | Cannot run | `vdb-init`, `vdb-execute-next`, `happy-start`, `happy-start-cd`, `ui-test` (Playwright MCP) |

### What Works in Codex

- All research, planning, analysis, and documentation commands (Category A / full)
- File read/write operations (shell equivalents)
- GitHub issue/epic management (via API)
- Roadmap and phase planning
- Code refactoring guidance

### What Requires Claude Code CLI

- **Railway MCP deployment** (`deploy-full`, `happy-start-cd`, `monitoring-setup`)
- **Playwright browser testing** (`ui-test`, `ui-smoke`, `ui-bug`)
- **Vision Driver Bot** (`vdb-*`) — autonomous execution with hooks
- **Happy Engineering MCP** (`happy-start`, `happy-start-cd`)
- **Task() multi-agent orchestration** — parallel agent spawning

Run `/codex-status` in Codex to see the current tier breakdown for your installation.

## Command Capability Tiers

Each command YAML in `.ccasp/commands/` has a `codex_support` field:

```yaml
id: review
title: Review Changes
description: Provide a high-level review summary and risks.
codex_support: full          # full | partial | unsupported
system: You are a senior systems architect.
instructions:
  - Summarize key changes.
  - Identify regressions and risks.
  - Recommend tests and next steps.
```

Generate a full capability report:
```bash
npm run report:codex-capability
```

## Extending Commands

1. Add a new YAML file to `.ccasp/commands/` with `codex_support` field.
2. Re-run `ccasp init` or `ccasp wizard` to regenerate runtime artifacts.
3. Codex prompts auto-sync via the PostToolUse hook when you add new commands.

For commands that use MCP tools, add a `CODEX-OVERRIDE` block to your template:
```markdown
<!-- CODEX-OVERRIDE:START -->
# my-command — Codex Runtime
[Codex-specific instructions without MCP calls]
<!-- CODEX-OVERRIDE:END -->
```

## Repair and Troubleshooting

| Problem | Fix |
|---------|-----|
| `.claude/` symlink broken | `npx ccasp init --repair-links` |
| Missing Codex prompts | `npm run fix:command-parity` |
| Compat shim missing | `npm run fix:runtime-compat` |
| Parity drift after adding commands | `npm run check:command-parity` |
| Stale adapters | `ccasp init` (re-run) |
| PyYAML missing | `pip install pyyaml` |
| `.txt` files in `.codex/prompts/` | `npm run fix:command-parity` (cleans up legacy files) |

## CI/CD Integration

The included GitHub Actions workflow (`.github/workflows/vision-driver-bot.yml`) runs on every push to `main`/`master` that touches command files:

1. **Filename parity check** — every Claude command has a Codex equivalent
2. **Content quality check** — every Codex prompt has compat shim or unsupported marker
3. **High-severity scan** — no raw `AskUserQuestion` or `mcp__*` calls without adaptation

Failing either of the first two checks blocks PR merge.

## Design Principles

- Cross-platform (Windows junction, Unix symlink)
- Runtime-agnostic (same YAML → Claude + Codex)
- Idempotent (safe to re-run init)
- Explicit capability tiers (no false parity claims)
- Fail loudly (symlink health check, content validation, CI gates)
