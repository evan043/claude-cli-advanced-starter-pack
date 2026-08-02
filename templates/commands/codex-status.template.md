<!-- CODEX-SUPPORT: full -->

---
description: CCASP Codex runtime self-diagnostic — check what commands are available and their support tier
codex_support: full
---

# /codex-status — Codex Runtime Diagnostics

Run a self-diagnostic of the CCASP Codex installation and report what's available.

## Instructions

Run these shell commands to gather diagnostic data, then produce a formatted report:

```bash
# 1. Check .codex/prompts/ directory
ls .codex/prompts/*.md 2>/dev/null | wc -l

# 2. Count by tier (read frontmatter codex-support field)
grep -rl "codex-support: full" .codex/prompts/ 2>/dev/null | wc -l
grep -rl "codex-support: partial" .codex/prompts/ 2>/dev/null | wc -l
grep -rl "codex-support: unsupported" .codex/prompts/ 2>/dev/null | wc -l

# 3. Check AGENTS.md exists and has router
head -5 AGENTS.md 2>/dev/null

# 4. Check ccasp version
cat package.json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('version','unknown'))" 2>/dev/null || echo "unknown"
```

## Report Format

Present results as:

```
╔══════════════════════════════════════════════╗
║         CCASP Codex Status Report            ║
╠══════════════════════════════════════════════╣
║ CCASP Version:  {version}                    ║
║ Total Commands: {total}                      ║
║                                              ║
║ ✅ Full support:    {full}  commands          ║
║ ⚠️  Partial support: {partial} commands       ║
║ ❌ Unsupported:     {unsupported} commands    ║
║                                              ║
║ AGENTS.md router: {present|missing}          ║
║ .codex/prompts/:  {present|missing}          ║
╚══════════════════════════════════════════════╝

Full support commands work completely in Codex.
Partial commands work with some manual steps.
Unsupported commands require Claude Code CLI.

Run `/[command-name]` to use any available command.
```

If any directory is missing, show a repair instruction:
```
⚠ .codex/prompts/ not found.
  Fix: npx ccasp init --enable-codex
```
