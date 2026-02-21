#!/usr/bin/env node

import { mkdtempSync, readdirSync, existsSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import process from 'node:process';

import { runInit } from '../src/commands/init.js';

function listMarkdown(dir) {
  return readdirSync(dir).filter((f) => f.endsWith('.md')).sort();
}

const temp = mkdtempSync(join(tmpdir(), 'ccasp-cross-runtime-smoke-'));
const start = process.cwd();
const oldHome = process.env.HOME;
const oldCodexHome = process.env.CODEX_HOME;

try {
  process.env.HOME = temp;
  process.env.CODEX_HOME = join(temp, '.codex-home');
  process.chdir(temp);
  await runInit({ skipPrompts: true, features: [], preset: 'minimal' });

  const claudeCommandsDir = join(temp, '.claude', 'commands');
  const codexPromptsDir = join(temp, '.codex', 'prompts');
  const agentsPath = join(temp, 'AGENTS.md');

  if (!existsSync(claudeCommandsDir)) throw new Error('Missing .claude/commands');
  if (!existsSync(codexPromptsDir)) throw new Error('Missing .codex/prompts');
  if (!existsSync(agentsPath)) throw new Error('Missing AGENTS.md');

  const claude = listMarkdown(claudeCommandsDir);
  const codex = listMarkdown(codexPromptsDir);
  const missing = claude.filter((f) => !codex.includes(f));

  if (missing.length > 0) {
    throw new Error(`Missing codex prompts for: ${missing.join(', ')}`);
  }

  const agents = readFileSync(agentsPath, 'utf8');
  if (!agents.includes('CCASP-CODEX-SLASH-ROUTER:START')) {
    throw new Error('Router block missing in AGENTS.md');
  }

  const sample = readFileSync(join(codexPromptsDir, codex[0]), 'utf8');
  if (!sample.includes('CCASP-CODEX-COMPAT:START')) {
    throw new Error('Compatibility shim missing in codex prompt sync output');
  }

  console.log('SMOKE_OK');
  console.log(`commands=${claude.length}`);
  console.log(`temp=${temp}`);
} finally {
  if (oldHome === undefined) delete process.env.HOME;
  else process.env.HOME = oldHome;
  if (oldCodexHome === undefined) delete process.env.CODEX_HOME;
  else process.env.CODEX_HOME = oldCodexHome;
  process.chdir(start);
  rmSync(temp, { recursive: true, force: true });
}
