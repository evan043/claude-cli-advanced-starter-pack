import path from 'path';
import fs from 'fs';
import os from 'os';
import { detectOS, detectRuntimes } from './detect.js';
import { ensureDir, exists, isBrokenLink, readFile, writeFile } from './fs.js';
import { linkDir } from './symlink.js';
import { loadCommands, renderClaude, renderCodex } from './commands.js';
import { convertLegacy } from './legacy.js';

export function scanProject(root) {
  const ccaspDir = path.join(root, '.ccasp');
  const claudeDir = path.join(root, '.claude');
  const codexDir = path.join(root, '.codex');
  const claudeMd = path.join(root, 'CLAUDE.md');
  const legacyCommands = path.join(claudeDir, 'commands');
  const legacyHooks = path.join(claudeDir, 'hooks');

  const hasCcasp = exists(ccaspDir);
  const hasClaude = exists(claudeDir);
  const hasCodex = exists(codexDir);
  const hasClaudeMd = exists(claudeMd);
  const hasLegacyCommands = exists(legacyCommands);
  const hasLegacyHooks = exists(legacyHooks);
  const legacyDetected = Boolean(hasClaude || hasCodex || hasClaudeMd || hasLegacyCommands || hasLegacyHooks);

  return {
    root,
    hasCcasp,
    hasClaude,
    hasCodex,
    hasClaudeMd,
    hasLegacyCommands,
    hasLegacyHooks,
    legacyDetected,
    brokenClaude: isBrokenLink(claudeDir),
    brokenCodex: isBrokenLink(codexDir),
  };
}

function ensureLayout(root, dryRun) {
  const dirs = [
    path.join(root, '.ccasp', 'core'),
    path.join(root, '.ccasp', 'commands'),
    path.join(root, '.ccasp', 'agents'),
    path.join(root, '.ccasp', 'hooks'),
    path.join(root, '.ccasp', 'templates'),
    path.join(root, '.ccasp', 'runtime', 'claude'),
    path.join(root, '.ccasp', 'runtime', 'codex'),
    path.join(root, '.ccasp', 'legacy_backup'),
  ];
  if (dryRun) return;
  for (const dir of dirs) ensureDir(dir);
}

function writeDefaultConfig(root, dryRun) {
  const configPath = path.join(root, '.ccasp', 'config.yaml');
  if (exists(configPath)) return;
  if (dryRun) return;
  const content = [
    'version: 1',
    'default_runtime: claude',
    'dual_runtime: true',
    'hooks_enabled: true',
    'governance_mode: standard',
  ].join('\n');
  writeFile(configPath, `${content}\n`);
}

function updateConfig(root, updates, dryRun) {
  if (!updates) return;
  const configPath = path.join(root, '.ccasp', 'config.yaml');
  if (dryRun) return;
  const existing = exists(configPath) ? readFile(configPath).split(/\r?\n/) : [];
  const map = new Map();
  for (const line of existing) {
    if (!line.includes(':')) continue;
    const [key, value] = line.split(':', 2);
    map.set(key.trim(), value.trim());
  }
  for (const [key, value] of Object.entries(updates)) {
    map.set(key, String(value));
  }
  const out = Array.from(map.entries()).map(([k, v]) => `${k}: ${v}`).join('\n');
  writeFile(configPath, `${out}\n`);
}

function writeDefaultCommand(root, dryRun) {
  const commandPath = path.join(root, '.ccasp', 'commands', 'plan.yaml');
  if (exists(commandPath)) return;
  if (dryRun) return;
  const content = [
    'id: plan',
    'title: Plan Tasks',
    'description: Create a focused, step-by-step plan before making changes.',
    'system: You are a senior systems architect.',
    'instructions:',
    '  - Restate the goal in one sentence.',
    '  - Propose a minimal plan with 2-6 steps.',
    '  - Call out risks and dependencies.',
  ].join('\n');
  writeFile(commandPath, `${content}\n`);
}

function upsertCodexSlashRouter(root, dryRun) {
  const agentsPath = path.join(root, 'AGENTS.md');
  const startMarker = '<!-- CCASP-CODEX-SLASH-ROUTER:START -->';
  const endMarker = '<!-- CCASP-CODEX-SLASH-ROUTER:END -->';
  const block = [
    startMarker,
    '## CCASP Codex Slash Router',
    '',
    'When the user enters a message that starts with `/`, treat it as a CCASP command alias.',
    '',
    'Command handling rules:',
    '1. Parse the first token as the command id (remove leading `/`).',
    '2. Look up `.codex/prompts/<command-id>.md` (preferred) or `.codex/prompts/<command-id>.txt` (legacy fallback).',
    '3. Check the `codex-support:` field in the YAML frontmatter of the prompt file:',
    '   - `codex-support: unsupported` — Respond: "This command requires Claude Code CLI and cannot run in Codex. [reason from prompt file]. To use it, switch to Claude Code CLI and run `/<command-id>`." Then stop — do not attempt execution.',
    '   - `codex-support: partial` — Prepend a brief disclaimer: "Note: This command has partial Codex support. Some steps may require manual action or have limited functionality compared to Claude Code CLI." Then execute using the prompt body.',
    '   - `codex-support: full` (or field absent) — Execute normally with no disclaimer.',
    '4. Treat remaining user text after the command as command arguments/context.',
    '5. If the prompt file does not exist, list available commands from `.codex/prompts/*.md` grouped by codex-support tier (full first, then partial, then unsupported) and ask the user to choose.',
    '',
    'Do not ignore valid `/command` messages. Do not respond with "slash commands are unsupported" when a mapped prompt exists.',
    endMarker,
    '',
  ].join('\n');

  if (dryRun) return;

  if (!exists(agentsPath)) {
    const content = ['# AGENTS', '', block].join('\n');
    writeFile(agentsPath, content);
    return;
  }

  const current = readFile(agentsPath);
  const startIndex = current.indexOf(startMarker);
  const endIndex = current.indexOf(endMarker);
  if (startIndex !== -1 && endIndex !== -1 && endIndex >= startIndex) {
    const before = current.slice(0, startIndex).replace(/\s*$/, '');
    const after = current.slice(endIndex + endMarker.length).replace(/^\s*/, '');
    const merged = [before, '', block.trimEnd(), after].filter(Boolean).join('\n\n');
    writeFile(agentsPath, `${merged.trimEnd()}\n`);
    return;
  }

  const merged = `${current.trimEnd()}\n\n${block}`;
  writeFile(agentsPath, merged);
}

function syncCodexPromptMenu(root, dryRun) {
  const runtimePromptsDir = path.join(root, '.ccasp', 'runtime', 'codex', 'prompts');
  const homePromptsDir = path.join(os.homedir(), '.codex', 'prompts');
  if (!exists(runtimePromptsDir)) {
    return { linked: 0, copied: 0, skipped: 0, conflicts: 0, warning: '' };
  }
  if (dryRun) {
    const count = fs.readdirSync(runtimePromptsDir).filter((file) => file.endsWith('.md')).length;
    return { linked: count, copied: 0, skipped: 0, conflicts: 0, warning: '' };
  }

  try {
    ensureDir(homePromptsDir);
  } catch (error) {
    return {
      linked: 0,
      copied: 0,
      skipped: 0,
      conflicts: 0,
      warning: `menu sync unavailable (${error.code || 'error'})`,
    };
  }
  const promptFiles = fs.readdirSync(runtimePromptsDir).filter((file) => file.endsWith('.md')).sort();
  let linked = 0;
  let copied = 0;
  let skipped = 0;
  let conflicts = 0;

  for (const file of promptFiles) {
    const src = path.join(runtimePromptsDir, file);
    const dest = path.join(homePromptsDir, file);
    if (exists(dest)) {
      let existing = '';
      try {
        existing = readFile(dest);
      } catch {
        skipped += 1;
        continue;
      }
      if (!existing.includes('CCASP-CODEX-PROMPT')) {
        conflicts += 1;
        continue;
      }
      try {
        fs.unlinkSync(dest);
      } catch {
        skipped += 1;
        continue;
      }
    }

    try {
      fs.linkSync(src, dest);
      linked += 1;
    } catch (error) {
      if (error && (error.code === 'EXDEV' || error.code === 'EPERM')) {
        fs.copyFileSync(src, dest);
        copied += 1;
      } else {
        skipped += 1;
      }
    }
  }
  return { linked, copied, skipped, conflicts, warning: '' };
}

function generateRuntimeOutputs(root, dryRun) {
  const commandsDir = path.join(root, '.ccasp', 'commands');
  const specs = loadCommands(commandsDir);
  if (specs.length === 0) return 0;
  if (dryRun) return specs.length * 2;

  let written = 0;
  for (const spec of specs) {
    const claudeOut = path.join(root, '.ccasp', 'runtime', 'claude', 'commands', `${spec.id}.md`);
    const codexOut = path.join(root, '.ccasp', 'runtime', 'codex', 'prompts', `${spec.id}.md`);
    writeFile(claudeOut, renderClaude(spec));
    writeFile(codexOut, renderCodex(spec));
    written += 2;
  }
  return written;
}

export async function runInit(options = {}) {
  const root = process.cwd();
  const osInfo = detectOS();
  const runtimeInfo = detectRuntimes();
  const status = scanProject(root);

  console.log('Status Summary\n=');
  console.log(`Project: ${status.root}`);
  console.log(`.ccasp/ present: ${status.hasCcasp ? 'yes' : 'no'}`);
  console.log(`.claude present: ${status.hasClaude ? 'yes' : 'no'}`);
  console.log(`.codex present: ${status.hasCodex ? 'yes' : 'no'}`);
  console.log(`CLAUDE.md present: ${status.hasClaudeMd ? 'yes' : 'no'}`);
  console.log(`Legacy commands: ${status.hasLegacyCommands ? 'yes' : 'no'}`);
  console.log(`Legacy hooks: ${status.hasLegacyHooks ? 'yes' : 'no'}`);
  if (status.brokenClaude) console.log('Broken .claude link detected');
  if (status.brokenCodex) console.log('Broken .codex link detected');
  console.log('');

  console.log(`OS: ${osInfo.platform}${osInfo.isWSL ? ' (WSL)' : ''}`);
  console.log(`Claude CLI: ${runtimeInfo.claude ? 'yes' : 'no'}`);
  console.log(`Codex CLI: ${runtimeInfo.codex ? 'yes' : 'no'}`);
  console.log('');

  const enableClaude = options.enableClaude ?? true;
  const enableCodex = options.enableCodex ?? runtimeInfo.codex;
  const shouldConvertLegacy = options.convertLegacy ?? status.legacyDetected;

  ensureLayout(root, options.dryRun);
  writeDefaultConfig(root, options.dryRun);
  writeDefaultCommand(root, options.dryRun);
  updateConfig(root, options.configUpdates, options.dryRun);

  if (shouldConvertLegacy && status.legacyDetected) {
    const legacyResult = convertLegacy(root, options.dryRun);
    console.log(`Legacy conversion: ${legacyResult.commandsConverted} commands, ${legacyResult.hooksCopied} hooks`);
  }

  const commandsWritten = generateRuntimeOutputs(root, options.dryRun);

  const links = [];
  if (enableClaude) {
    const result = linkDir(
      path.join(root, '.claude'),
      path.join(root, '.ccasp', 'runtime', 'claude'),
      osInfo.isWindows,
      options.dryRun,
      options.repairLinks,
    );
    links.push(result.message);
  }

  if (enableCodex) {
    upsertCodexSlashRouter(root, options.dryRun);
    const syncResult = syncCodexPromptMenu(root, options.dryRun);
    const result = linkDir(
      path.join(root, '.codex'),
      path.join(root, '.ccasp', 'runtime', 'codex'),
      osInfo.isWindows,
      options.dryRun,
      options.repairLinks,
    );
    links.push(result.message);
    if (syncResult.warning) {
      links.push(`Codex menu prompts sync: ${syncResult.warning}`);
    } else {
      links.push(`Codex menu prompts synced: linked=${syncResult.linked}, copied=${syncResult.copied}, conflicts=${syncResult.conflicts}, skipped=${syncResult.skipped}`);
    }
  }

  console.log('Applied\n=');
  for (const msg of links) console.log(msg);
  console.log(`Commands generated: ${commandsWritten}`);
  if (options.dryRun) console.log('Dry-run mode: no changes applied');
  return 0;
}
