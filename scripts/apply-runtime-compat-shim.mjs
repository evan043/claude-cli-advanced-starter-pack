#!/usr/bin/env node

import { existsSync, readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import process from 'node:process';
import { prepareForCodex, hasRuntimeCompatibilityShim } from '../src/commands/init/runtime-compat.js';

function collectMarkdown(dir, out = []) {
  if (!existsSync(dir)) return out;
  const entries = readdirSync(dir);
  for (const entry of entries) {
    const abs = join(dir, entry);
    const st = statSync(abs);
    if (st.isDirectory()) {
      collectMarkdown(abs, out);
      continue;
    }
    if (st.isFile() && entry.endsWith('.md')) {
      out.push(abs);
    }
  }
  return out;
}

const defaultDirs = [
  'templates/commands',
  '.claude/commands',
  '.ccasp/runtime/claude/commands',
  '.ccasp/runtime/codex/prompts'
];

const dirs = process.argv.slice(2).length > 0 ? process.argv.slice(2) : defaultDirs;
let updated = 0;
let skipped = 0;
let files = 0;

for (const dir of dirs) {
  const markdownFiles = collectMarkdown(join(process.cwd(), dir));
  for (const file of markdownFiles) {
    files += 1;
    const content = readFileSync(file, 'utf8');
    if (hasRuntimeCompatibilityShim(content)) {
      skipped += 1;
      continue;
    }
    writeFileSync(file, prepareForCodex(content), 'utf8');
    updated += 1;
  }
}

console.log(JSON.stringify({ files, updated, skipped, dirs }, null, 2));
