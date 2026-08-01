#!/usr/bin/env node
/**
 * check-command-prompt-parity.mjs
 *
 * Enforces bidirectional parity between .claude/commands/ and .codex/prompts/.
 *
 * Two levels of validation:
 *  1. Filename parity — every Claude command must have a Codex prompt and vice versa.
 *  2. Content validation — every Codex prompt must meet minimum quality standards:
 *     - Non-empty (≥ 100 bytes)
 *     - Has runtime compat shim OR unsupported marker
 *     - Does not contain raw mcp__ calls without a CODEX-OVERRIDE or unsupported marker
 *     - Does not contain raw AskUserQuestion without a CODEX-OVERRIDE or unsupported marker
 *
 * Flags:
 *   --sync          Sync missing Codex prompts from Claude commands (filename parity only)
 *   --content-only  Run content validation only (skip filename diff)
 */

import { existsSync, readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { syncCodexPrompts } from '../src/commands/init/codex-setup.js';

const cwd = process.cwd();
const commandsDir = path.join(cwd, '.claude', 'commands');
const promptsDir = path.join(cwd, '.codex', 'prompts');
const shouldSync = process.argv.includes('--sync');
const contentOnly = process.argv.includes('--content-only');

// ─── Content validation rules ───────────────────────────────────────────────

const COMPAT_MARKER = 'CCASP-CODEX-COMPAT:START';
const UNSUPPORTED_MARKER = '<!-- CODEX-SUPPORT: unsupported -->';
const OVERRIDE_START = '<!-- CODEX-OVERRIDE:START -->';
const MCP_CALL_REGEX = /\bmcp__[\w-]+__[\w-]+\b/;
const ASK_USER_REGEX = /\bAskUserQuestion\b/;

/**
 * Validate a Codex prompt file's content.
 * @param {string} filePath
 * @returns {{ ok: boolean, failures: string[] }}
 */
function validatePromptContent(filePath) {
  const failures = [];
  let content;
  try {
    content = readFileSync(filePath, 'utf8');
  } catch {
    return { ok: false, failures: ['Cannot read file'] };
  }

  // Rule 1: Non-empty
  if (content.trim().length < 100) {
    failures.push('File is too short (< 100 chars) — likely empty or truncated');
  }

  const hasCompatShim = content.includes(COMPAT_MARKER);
  const hasUnsupportedMarker = content.includes(UNSUPPORTED_MARKER);
  const hasOverride = content.includes(OVERRIDE_START);

  // Rule 2: Must have compat shim or unsupported marker
  if (!hasCompatShim && !hasUnsupportedMarker) {
    failures.push(
      'Missing runtime compat shim (CCASP-CODEX-COMPAT:START) and no unsupported marker — ' +
      'run: npm run fix:runtime-compat'
    );
  }

  // Rule 3: Raw mcp__ calls without override/unsupported marker
  if (MCP_CALL_REGEX.test(content) && !hasOverride && !hasUnsupportedMarker) {
    failures.push(
      'Contains raw mcp__* call without CODEX-OVERRIDE block or unsupported marker — ' +
      'add a <!-- CODEX-OVERRIDE:START --> block with Codex-compatible instructions'
    );
  }

  // Rule 4: Raw AskUserQuestion without override/unsupported marker
  if (ASK_USER_REGEX.test(content) && !hasOverride && !hasUnsupportedMarker) {
    failures.push(
      'Contains AskUserQuestion without CODEX-OVERRIDE block or unsupported marker — ' +
      'the compat shim handles this, but consider adding an explicit override for clarity'
    );
  }

  return { ok: failures.length === 0, failures };
}

// ─── Filename parity ─────────────────────────────────────────────────────────

function listMarkdownNames(dir) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir)
    .filter((name) => name.endsWith('.md'))
    .sort();
}

function diffParity() {
  const commands = listMarkdownNames(commandsDir);
  const prompts = listMarkdownNames(promptsDir);
  const promptSet = new Set(prompts);
  const commandSet = new Set(commands);
  return {
    commands,
    prompts,
    missingInPrompts: commands.filter((name) => !promptSet.has(name)),
    extraInPrompts: prompts.filter((name) => !commandSet.has(name)),
  };
}

// ─── Content validation run ──────────────────────────────────────────────────

function runContentValidation(prompts) {
  const failures = [];
  for (const file of prompts) {
    const fullPath = path.join(promptsDir, file);
    const result = validatePromptContent(fullPath);
    if (!result.ok) {
      failures.push({ file, issues: result.failures });
    }
  }
  return failures;
}

// ─── Main ────────────────────────────────────────────────────────────────────

let exitCode = 0;

// Sync step (filename parity only)
if (shouldSync) {
  const result = syncCodexPrompts(cwd);
  console.log(`Synced prompts: ${result.synced}, skipped: ${result.skipped}`);
}

// Filename parity check
if (!contentOnly) {
  const { commands, prompts, missingInPrompts, extraInPrompts } = diffParity();
  console.log(`.claude/commands: ${commands.length}`);
  console.log(`.codex/prompts:   ${prompts.length}`);

  if (missingInPrompts.length === 0 && extraInPrompts.length === 0) {
    console.log('Filename parity OK: command and prompt file sets match.');
  } else {
    if (missingInPrompts.length > 0) {
      console.log(`\nMissing in .codex/prompts (${missingInPrompts.length}):`);
      for (const file of missingInPrompts) console.log(`  - ${file}`);
      console.log('  Fix: npm run fix:command-parity');
    }
    if (extraInPrompts.length > 0) {
      console.log(`\nExtra in .codex/prompts (${extraInPrompts.length}):`);
      for (const file of extraInPrompts) console.log(`  - ${file}`);
    }
    exitCode = 1;
  }
}

// Content validation check
const allPrompts = listMarkdownNames(promptsDir);
if (allPrompts.length > 0) {
  console.log(`\nContent validation: checking ${allPrompts.length} Codex prompts...`);
  const contentFailures = runContentValidation(allPrompts);

  if (contentFailures.length === 0) {
    console.log('Content validation OK: all Codex prompts pass quality checks.');
  } else {
    console.log(`\nContent validation FAILED (${contentFailures.length} files):`);
    for (const { file, issues } of contentFailures) {
      console.log(`\n  ${file}:`);
      for (const issue of issues) {
        console.log(`    ✗ ${issue}`);
      }
    }
    console.log(
      '\nContent failures require manual fixes — see issue descriptions above.'
    );
    exitCode = 1;
  }
} else {
  console.log('\nContent validation skipped: no Codex prompts found.');
}

process.exit(exitCode);
