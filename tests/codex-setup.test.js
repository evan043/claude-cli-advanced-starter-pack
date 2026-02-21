import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { ensureCodexSlashRouter, syncCodexPrompts, setupCodexSupport } from '../src/commands/init/codex-setup.js';

function tempProject() {
  return mkdtempSync(join(tmpdir(), 'ccasp-codex-setup-'));
}

test('syncCodexPrompts copies .claude/commands into .codex/prompts', () => {
  const root = tempProject();
  try {
    mkdirSync(join(root, '.claude', 'commands'), { recursive: true });
    writeFileSync(join(root, '.claude', 'commands', 'vision-init.md'), '# Vision Init', 'utf8');
    writeFileSync(join(root, '.claude', 'commands', 'menu.md'), '# Menu', 'utf8');

    const result = syncCodexPrompts(root);
    assert.equal(result.synced, 2);
    assert.equal(result.skipped, 0);
    assert.equal(existsSync(join(root, '.codex', 'prompts', 'vision-init.md')), true);
    assert.equal(existsSync(join(root, '.codex', 'prompts', 'menu.md')), true);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('ensureCodexSlashRouter creates AGENTS.md block and can update in-place', () => {
  const root = tempProject();
  try {
    const created = ensureCodexSlashRouter(root);
    assert.equal(created.created, true);
    const first = readFileSync(join(root, 'AGENTS.md'), 'utf8');
    assert.match(first, /CCASP-CODEX-SLASH-ROUTER:START/);

    writeFileSync(join(root, 'AGENTS.md'), `${first}\nExtra line\n`, 'utf8');
    const updated = ensureCodexSlashRouter(root);
    assert.equal(typeof updated.updated, 'boolean');
    const second = readFileSync(join(root, 'AGENTS.md'), 'utf8');
    assert.match(second, /CCASP-CODEX-SLASH-ROUTER:END/);
    assert.match(second, /Extra line/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('setupCodexSupport performs both prompt sync and router setup', () => {
  const root = tempProject();
  try {
    mkdirSync(join(root, '.claude', 'commands'), { recursive: true });
    writeFileSync(join(root, '.claude', 'commands', 'phase-dev-plan.md'), '# Phase Plan', 'utf8');
    const result = setupCodexSupport(root);
    assert.equal(result.promptsSynced, 1);
    assert.equal(result.routerCreated, true);
    assert.equal(existsSync(join(root, '.codex', 'prompts', 'phase-dev-plan.md')), true);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
