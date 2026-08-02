#!/usr/bin/env node
/**
 * report-codex-capability.mjs
 *
 * Reads all .ccasp/commands/*.yaml files and groups them by codex_support tier.
 * Outputs a markdown capability table to stdout and a JSON report to
 * .ccasp/reports/codex-capability.json.
 *
 * Usage:  npm run report:codex-capability
 */

import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import process from 'node:process';

// Minimal YAML value extraction (avoids needing yaml package at script level)
function extractField(content, field) {
  const regex = new RegExp(`^${field}:\\s*(.+)$`, 'm');
  const match = content.match(regex);
  return match ? match[1].trim().replace(/^["']|["']$/g, '') : null;
}

const cwd = process.cwd();
const commandsDir = path.join(cwd, '.ccasp', 'commands');
const reportsDir = path.join(cwd, '.ccasp', 'reports');
const reportPath = path.join(reportsDir, 'codex-capability.json');

if (!existsSync(commandsDir)) {
  console.error(`Commands directory not found: ${commandsDir}`);
  process.exit(1);
}

const tiers = { full: [], partial: [], unsupported: [], unknown: [] };
const files = readdirSync(commandsDir)
  .filter((f) => f.endsWith('.yaml') || f.endsWith('.yml'))
  .sort();

for (const file of files) {
  const content = readFileSync(path.join(commandsDir, file), 'utf8');
  const id = extractField(content, 'id') || path.basename(file, path.extname(file));
  const title = extractField(content, 'title') || id;
  const support = extractField(content, 'codex_support') || 'unknown';
  const description = extractField(content, 'description') || '';

  const tier = ['full', 'partial', 'unsupported'].includes(support) ? support : 'unknown';
  tiers[tier].push({ id, title, description, file });
}

// ─── Build report ──────────────────────────────────────────────────────────

const total = files.length;
const counts = {
  full: tiers.full.length,
  partial: tiers.partial.length,
  unsupported: tiers.unsupported.length,
  unknown: tiers.unknown.length,
};

const pct = (n) => total > 0 ? `${Math.round((n / total) * 100)}%` : '0%';

const report = {
  generated: new Date().toISOString(),
  total,
  summary: {
    full: { count: counts.full, percentage: pct(counts.full) },
    partial: { count: counts.partial, percentage: pct(counts.partial) },
    unsupported: { count: counts.unsupported, percentage: pct(counts.unsupported) },
    unknown: { count: counts.unknown, percentage: pct(counts.unknown) },
  },
  commands: {
    full: tiers.full,
    partial: tiers.partial,
    unsupported: tiers.unsupported,
    unknown: tiers.unknown,
  },
};

// ─── Markdown output ───────────────────────────────────────────────────────

const lines = [
  '# CCASP Codex Capability Report',
  '',
  `Generated: ${report.generated}`,
  `Total commands: ${total}`,
  '',
  '## Summary',
  '',
  '| Tier | Count | % of Total | Description |',
  '|------|-------|------------|-------------|',
  `| ✅ full | ${counts.full} | ${pct(counts.full)} | Works fully in Codex (no MCP/Task() required) |`,
  `| ⚠️  partial | ${counts.partial} | ${pct(counts.partial)} | Works with limitations; some steps need manual action |`,
  `| ❌ unsupported | ${counts.unsupported} | ${pct(counts.unsupported)} | Requires Claude Code CLI infrastructure |`,
  `| ❓ unknown | ${counts.unknown} | ${pct(counts.unknown)} | Not yet tagged (defaults to partial behaviour) |`,
  '',
];

for (const [tier, label, icon] of [
  ['full', 'Full Support Commands', '✅'],
  ['partial', 'Partial Support Commands', '⚠️'],
  ['unsupported', 'Unsupported Commands (Claude Code CLI required)', '❌'],
  ['unknown', 'Untagged Commands', '❓'],
]) {
  if (tiers[tier].length === 0) continue;
  lines.push(`## ${icon} ${label} (${tiers[tier].length})`, '');
  lines.push('| Command | Title |');
  lines.push('|---------|-------|');
  for (const cmd of tiers[tier]) {
    lines.push(`| \`${cmd.id}\` | ${cmd.title} |`);
  }
  lines.push('');
}

console.log(lines.join('\n'));

// ─── Write JSON report ─────────────────────────────────────────────────────

mkdirSync(reportsDir, { recursive: true });
writeFileSync(reportPath, JSON.stringify(report, null, 2), 'utf8');
console.error(`\nJSON report written to: ${reportPath}`);
