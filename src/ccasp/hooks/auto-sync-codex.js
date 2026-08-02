/**
 * auto-sync-codex.js — PostToolUse hook
 *
 * Detects when a Write tool creates or modifies a .md file inside
 * .claude/commands/ and automatically syncs that single file to
 * .codex/prompts/ using the Codex compat pipeline.
 *
 * This prevents Codex prompt drift when new commands are added after init.
 *
 * Registration: add to .claude/settings.json under hooks.PostToolUse
 *   { "type": "command", "command": "node .claude/hooks/auto-sync-codex.js" }
 */

import { existsSync, mkdirSync, readFileSync, writeFileSync, readdirSync, unlinkSync } from 'node:fs';
import { resolve, join, basename } from 'node:path';

// Claude Code passes tool context via stdin as JSON
let rawInput = '';
process.stdin.on('data', (chunk) => { rawInput += chunk; });
process.stdin.on('end', () => {
  try {
    run(rawInput ? JSON.parse(rawInput) : {});
  } catch {
    // Non-fatal: hook failures should not block Claude's work
    process.exit(0);
  }
});

function run(ctx) {
  const root = process.cwd();
  const commandsDir = resolve(root, '.claude', 'commands');
  const promptsDir = resolve(root, '.codex', 'prompts');

  // Only act on Write tool targeting .claude/commands/*.md
  const toolName = ctx?.tool_name || ctx?.tool || '';
  const filePath = ctx?.tool_input?.file_path || ctx?.input?.file_path || '';

  if (toolName !== 'Write' && toolName !== 'Edit') {
    process.exit(0);
  }

  const absPath = resolve(filePath);
  if (!absPath.startsWith(commandsDir) || !absPath.endsWith('.md')) {
    process.exit(0);
  }

  // File is in .claude/commands/*.md — sync to .codex/prompts/
  const fname = basename(absPath);
  const dest = join(promptsDir, fname);

  try {
    if (!existsSync(absPath)) process.exit(0);

    const content = readFileSync(absPath, 'utf8');

    // Import prepareForCodex dynamically (ESM-compatible)
    import('../../../src/commands/init/runtime-compat.js').then(({ prepareForCodex }) => {
      mkdirSync(promptsDir, { recursive: true });
      writeFileSync(dest, prepareForCodex(content), 'utf8');

      // Clean up any legacy .txt version
      const txtDest = dest.replace(/\.md$/, '.txt');
      if (existsSync(txtDest)) {
        try { unlinkSync(txtDest); } catch { /* non-fatal */ }
      }

      process.stderr.write(`[CCASP] Auto-synced to Codex: ${fname}\n`);
      process.exit(0);
    }).catch(() => process.exit(0));
  } catch {
    process.exit(0);
  }
}
