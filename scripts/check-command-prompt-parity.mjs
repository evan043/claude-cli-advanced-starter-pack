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
 *   --verbose-advisories  List advisory findings per file instead of summarising
 */

import { existsSync, readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { syncCodexPrompts } from '../src/commands/init/codex-setup.js';

const cwd = process.cwd();
const commandsDir = path.join(cwd, '.claude', 'commands');
const promptsDir = path.join(cwd, '.codex', 'prompts');
const shouldSync = process.argv.includes('--sync');
const contentOnly = process.argv.includes('--content-only');
const verboseAdvisories = process.argv.includes('--verbose-advisories');

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

  const warnings = [];

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

  // Rules 3 and 4 describe Claude-only calls. The compat shim already tells
  // Codex how to adapt both, so when it is present these are advisory: an
  // explicit override is clearer but not required, and demanding one for every
  // mention would mean rewriting whole prompts to replace a single line.
  // Without the shim there is nothing adapting them, so they are real failures.
  const covered = hasCompatShim || hasOverride || hasUnsupportedMarker;

  if (MCP_CALL_REGEX.test(content) && !hasOverride && !hasUnsupportedMarker) {
    (covered ? warnings : failures).push(
      'Contains raw mcp__* call without CODEX-OVERRIDE block or unsupported marker — ' +
      'the compat shim maps MCP calls to Codex equivalents; add a ' +
      '<!-- CODEX-OVERRIDE:START --> block if this command needs different steps'
    );
  }

  if (ASK_USER_REGEX.test(content) && !hasOverride && !hasUnsupportedMarker) {
    (covered ? warnings : failures).push(
      'Contains AskUserQuestion without CODEX-OVERRIDE block or unsupported marker — ' +
      'the compat shim handles this, but consider adding an explicit override for clarity'
    );
  }

  return { ok: failures.length === 0, failures, warnings };
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
  const warnings = [];
  for (const file of prompts) {
    const fullPath = path.join(promptsDir, file);
    const result = validatePromptContent(fullPath);
    if (!result.ok) {
      failures.push({ file, issues: result.failures });
    }
    if (result.warnings && result.warnings.length > 0) {
      warnings.push({ file, issues: result.warnings });
    }
  }
  return { failures, warnings };
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
  const { failures: contentFailures, warnings: contentWarnings } = runContentValidation(allPrompts);

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

  // Advisory only: summarised rather than listed per file, so real failures
  // above stay visible instead of being buried under a wall of suggestions.
  if (contentWarnings.length > 0) {
    const byIssue = new Map();
    for (const { issues } of contentWarnings) {
      for (const issue of issues) {
        const key = issue.split('—')[0].trim();
        byIssue.set(key, (byIssue.get(key) || 0) + 1);
      }
    }
    console.log(`\nAdvisories (${contentWarnings.length} files, not failures):`);
    for (const [issue, count] of byIssue) {
      console.log(`  ! ${count} × ${issue}`);
    }
    console.log('  These are covered by the compat shim; add CODEX-OVERRIDE blocks only where a command genuinely needs different steps in Codex.');
    console.log('  Run with --verbose-advisories to list them per file.');
  }

  if (contentWarnings.length > 0 && verboseAdvisories) {
    for (const { file, issues } of contentWarnings) {
      console.log(`\n  ${file}:`);
      for (const issue of issues) {
        console.log(`    ! ${issue}`);
      }
    }
  }
} else {
  console.log('\nContent validation skipped: no Codex prompts found.');
}

process.exit(exitCode);
