import fs from 'fs';
import path from 'path';
import yaml from 'yaml';
import { copyRecursive, ensureDir, exists, movePath, readFile, writeFile } from './fs.js';

function timestamp() {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getUTCFullYear()}${pad(d.getUTCMonth() + 1)}${pad(d.getUTCDate())}_${pad(d.getUTCHours())}${pad(d.getUTCMinutes())}${pad(d.getUTCSeconds())}`;
}

export function convertLegacy(root, dryRun) {
  const claudeDir = path.join(root, '.claude');
  const codexDir = path.join(root, '.codex');
  const claudeMd = path.join(root, 'CLAUDE.md');
  const legacyCommands = path.join(claudeDir, 'commands');
  const legacyHooks = path.join(claudeDir, 'hooks');
  const ccaspRoot = path.join(root, '.ccasp');
  const backupRoot = path.join(ccaspRoot, 'legacy_backup', timestamp());
  const commandsDir = path.join(ccaspRoot, 'commands');
  const hooksDir = path.join(ccaspRoot, 'hooks');

  let commandsConverted = 0;
  let hooksCopied = 0;

  if (!dryRun) {
    ensureDir(backupRoot);
  }

  if (exists(legacyCommands)) {
    for (const file of fs.readdirSync(legacyCommands)) {
      if (!file.endsWith('.md')) continue;
      const commandId = path.basename(file, path.extname(file));
      const srcPath = path.join(legacyCommands, file);
      const destPath = path.join(commandsDir, `${commandId}.yaml`);
      if (exists(destPath)) continue;

      commandsConverted += 1;
      if (dryRun) continue;

      const raw = readFile(srcPath).trim();
      let title = commandId.replace(/[_-]/g, ' ').replace(/\b\w/g, (m) => m.toUpperCase());
      let body = raw;
      if (raw.startsWith('#')) {
        const lines = raw.split(/\r?\n/);
        title = lines[0].replace(/^#+\s*/, '').trim() || title;
        body = lines.slice(1).join('\n').trim();
      }

      const yamlDoc = yaml.stringify({
        id: commandId,
        title,
        description: 'Converted from legacy Claude command.',
        system: 'You are a senior systems architect.',
        instructions: body ? body.split(/\r?\n/).filter(Boolean) : [],
      });
      writeFile(destPath, yamlDoc);
    }
  }

  if (exists(legacyHooks)) {
    if (!dryRun) {
      ensureDir(hooksDir);
      copyRecursive(legacyHooks, hooksDir);
    }
    hooksCopied = fs.readdirSync(legacyHooks).length;
  }

  const moveTargets = [claudeDir, codexDir, claudeMd].filter(exists);
  if (!dryRun) {
    for (const target of moveTargets) {
      movePath(target, path.join(backupRoot, path.basename(target)));
    }
  }

  return {
    backupPath: backupRoot,
    commandsConverted,
    hooksCopied,
  };
}
