/**
 * Codex Setup Helpers
 * Syncs slash command prompts and ensures AGENTS.md router instructions.
 */

import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from 'fs';
import { join } from 'path';

const ROUTER_START = '<!-- CCASP-CODEX-SLASH-ROUTER:START -->';
const ROUTER_END = '<!-- CCASP-CODEX-SLASH-ROUTER:END -->';

function getRouterBlock() {
  return [
    ROUTER_START,
    '## CCASP Codex Slash Router',
    '',
    'When the user enters a message that starts with `/`, treat it as a CCASP command alias.',
    '',
    'Command handling rules:',
    '- Parse the first token as the command id (remove leading `/`).',
    '- Read `.codex/prompts/<command-id>.md` if it exists.',
    '- Treat that prompt file as the primary instruction set for the task.',
    '- Apply cross-runtime compatibility: if a prompt references Claude-only tools, use Codex equivalents (ask user directly for AskUserQuestion, use web.search/open for WebSearch/WebFetch, and shell/file tools for Read/Write).',
    '- Treat remaining user text after the command as command arguments/context.',
    '- If the prompt file does not exist, list available commands from `.codex/prompts/*.md` and ask the user to choose one.',
    '',
    'Do not ignore valid `/command` messages and do not respond with "slash commands are unsupported" when a mapped prompt exists.',
    ROUTER_END
  ].join('\n');
}

function getCodexCompatibilityShim() {
  return [
    '<!-- CCASP-CODEX-COMPAT:START -->',
    '# Codex Runtime Compatibility',
    '',
    'This prompt was authored for Claude-style slash workflows. In Codex runtime, adapt tool calls as follows:',
    '- `AskUserQuestion` => ask the user directly in chat.',
    '- `WebSearch`/`WebFetch` => use available web tools (`search_query`, `open`, `find`) and cite links.',
    '- `Read`/`Write` => use shell/filesystem tools in this workspace.',
    '- Claude-only MCP calls (for example Playwright MCP names) => use available equivalents or clearly state fallback.',
    '- Keep intent and output format identical; only adapt execution mechanics.',
    '<!-- CCASP-CODEX-COMPAT:END -->',
    ''
  ].join('\n');
}

/**
 * Ensure AGENTS.md has slash-router block for Codex command routing.
 * @param {string} cwd
 * @returns {{created: boolean, updated: boolean}}
 */
export function ensureCodexSlashRouter(cwd) {
  const agentsPath = join(cwd, 'AGENTS.md');
  const block = getRouterBlock();

  if (!existsSync(agentsPath)) {
    writeFileSync(agentsPath, `# AGENTS\n\n${block}\n`, 'utf8');
    return { created: true, updated: false };
  }

  const current = readFileSync(agentsPath, 'utf8');
  const start = current.indexOf(ROUTER_START);
  const end = current.indexOf(ROUTER_END);

  if (start !== -1 && end !== -1 && end >= start) {
    const before = current.slice(0, start).replace(/\s*$/, '');
    const after = current.slice(end + ROUTER_END.length).replace(/^\s*/, '');
    const merged = [before, block, after].filter(Boolean).join('\n\n');
    if (merged.trim() !== current.trim()) {
      writeFileSync(agentsPath, `${merged.trimEnd()}\n`, 'utf8');
      return { created: false, updated: true };
    }
    return { created: false, updated: false };
  }

  writeFileSync(agentsPath, `${current.trimEnd()}\n\n${block}\n`, 'utf8');
  return { created: false, updated: true };
}

/**
 * Sync `.claude/commands/*.md` into `.codex/prompts/*.md`.
 * @param {string} cwd
 * @returns {{synced: number, skipped: number}}
 */
export function syncCodexPrompts(cwd) {
  const commandsDir = join(cwd, '.claude', 'commands');
  const promptsDir = join(cwd, '.codex', 'prompts');
  if (!existsSync(commandsDir)) {
    return { synced: 0, skipped: 0 };
  }

  mkdirSync(promptsDir, { recursive: true });

  const files = readdirSync(commandsDir).filter((f) => f.endsWith('.md'));
  let synced = 0;
  let skipped = 0;

  for (const file of files) {
    const src = join(commandsDir, file);
    const dst = join(promptsDir, file);
    try {
      const content = readFileSync(src, 'utf8');
      const shim = getCodexCompatibilityShim();
      const hasShim = content.includes('CCASP-CODEX-COMPAT:START');
      const rewritten = hasShim ? content : `${shim}${content}`;
      writeFileSync(dst, rewritten, 'utf8');
      synced += 1;
    } catch {
      skipped += 1;
    }
  }

  return { synced, skipped };
}

/**
 * Full Codex setup step for `ccasp init`.
 * @param {string} cwd
 * @returns {{promptsSynced: number, promptsSkipped: number, routerCreated: boolean, routerUpdated: boolean}}
 */
export function setupCodexSupport(cwd) {
  const promptResult = syncCodexPrompts(cwd);
  const routerResult = ensureCodexSlashRouter(cwd);
  return {
    promptsSynced: promptResult.synced,
    promptsSkipped: promptResult.skipped,
    routerCreated: routerResult.created,
    routerUpdated: routerResult.updated
  };
}
