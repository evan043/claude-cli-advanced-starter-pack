#!/usr/bin/env node

import { mkdtempSync, readdirSync, existsSync, readFileSync, rmSync, statSync } from 'node:fs';
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

  // Check 1: first prompt has compat shim
  const sampleFile = codex[0];
  const sample = readFileSync(join(codexPromptsDir, sampleFile), 'utf8');
  if (!sample.includes('CCASP-CODEX-COMPAT:START')) {
    throw new Error(`Compatibility shim missing in ${sampleFile}`);
  }

  // Check 2: verify AGENTS.md contains tier-aware routing (cih-d1)
  const agentsContent = readFileSync(agentsPath, 'utf8');
  if (!agentsContent.includes('codex-support: unsupported')) {
    throw new Error('AGENTS.md router missing tier-aware routing instructions (codex-support: unsupported)');
  }
  if (!agentsContent.includes('codex-support: partial')) {
    throw new Error('AGENTS.md router missing tier-aware routing instructions (codex-support: partial)');
  }

  // Check 3: find a 'full' support prompt and verify correct structure
  const fullSupportFile = codex.find((f) => {
    const c = readFileSync(join(codexPromptsDir, f), 'utf8');
    return c.includes('codex-support: full') || !c.includes('codex-support:');
  });
  if (fullSupportFile) {
    const fullContent = readFileSync(join(codexPromptsDir, fullSupportFile), 'utf8');
    if (!fullContent.includes('CCASP-CODEX-COMPAT:START') && !fullContent.includes('CCASP-CODEX-PROMPT')) {
      throw new Error(`Full-support prompt ${fullSupportFile} has neither compat shim nor CCASP-CODEX-PROMPT marker`);
    }
  }

  // Check 4: no .txt files should exist (legacy cleanup)
  const txtFiles = readdirSync(codexPromptsDir).filter((f) => f.endsWith('.txt'));
  if (txtFiles.length > 0) {
    throw new Error(`Legacy .txt prompt files still exist (should have been cleaned up): ${txtFiles.slice(0, 3).join(', ')}`);
  }

  console.log('SMOKE_OK');
  console.log(`commands=${claude.length}`);
  console.log(`codex_prompts=${codex.length}`);
  console.log(`temp=${temp}`);
} finally {
  if (oldHome === undefined) delete process.env.HOME;
  else process.env.HOME = oldHome;
  if (oldCodexHome === undefined) delete process.env.CODEX_HOME;
  else process.env.CODEX_HOME = oldCodexHome;
  process.chdir(start);
  rmSync(temp, { recursive: true, force: true });
}
