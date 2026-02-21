#!/usr/bin/env node

import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import process from 'node:process';

const root = process.argv[2] ? join(process.cwd(), process.argv[2]) : process.cwd();
const includeExt = new Set(['.md', '.js', '.mjs', '.cjs', '.ts']);
const ignoreDirs = new Set(['node_modules', '.git', 'dist', 'coverage']);

const patterns = [
  {
    id: 'ask_user_question',
    severity: 'high',
    regex: /\bAskUserQuestion\b/g,
    message: 'Claude-only AskUserQuestion flow detected'
  },
  {
    id: 'webfetch_tool',
    severity: 'medium',
    regex: /\bWebFetch\b/g,
    message: 'Claude-style WebFetch tool reference detected'
  },
  {
    id: 'websearch_tool',
    severity: 'medium',
    regex: /\bWebSearch\b/g,
    message: 'Claude-style WebSearch tool reference detected'
  },
  {
    id: 'claude_mcp_call',
    severity: 'medium',
    regex: /\bmcp__[\w-]+__[\w-]+\b/g,
    message: 'MCP tool alias may be runtime-specific'
  },
  {
    id: 'generic_read_write_tools',
    severity: 'low',
    regex: /\b(Read|Write)\b(?=\s+tool|\s*\()/g,
    message: 'Generic Read/Write tooling assumption detected'
  },
  {
    id: 'claude_code_phrase',
    severity: 'low',
    regex: /\bClaude Code\b/g,
    message: 'Claude Code runtime wording found (confirm Codex equivalent exists)'
  }
];

function walk(dir, out = []) {
  const entries = readdirSync(dir);
  for (const entry of entries) {
    const abs = join(dir, entry);
    const st = statSync(abs);
    if (st.isDirectory()) {
      if (!ignoreDirs.has(entry)) {
        walk(abs, out);
      }
      continue;
    }
    if (!st.isFile()) continue;
    const dot = entry.lastIndexOf('.');
    const ext = dot >= 0 ? entry.slice(dot) : '';
    if (includeExt.has(ext)) out.push(abs);
  }
  return out;
}

function scanFile(file) {
  const txt = readFileSync(file, 'utf8');
  const hasCodexShim = txt.includes('CCASP-CODEX-COMPAT:START');
  const shimAdaptable = new Set([
    'ask_user_question',
    'webfetch_tool',
    'websearch_tool',
    'claude_mcp_call',
    'generic_read_write_tools',
    'claude_code_phrase'
  ]);
  const findings = [];
  for (const p of patterns) {
    const matches = txt.match(p.regex);
    if (matches?.length) {
      const adaptedByShim = hasCodexShim && shimAdaptable.has(p.id);
      findings.push({
        id: p.id,
        severity: adaptedByShim ? 'info' : p.severity,
        message: p.message,
        count: matches.length,
        adaptedByShim
      });
    }
  }
  return findings;
}

const files = walk(root);
const perFile = [];
const totals = new Map();
const shimAdaptedTotals = new Map();

for (const file of files) {
  const findings = scanFile(file);
  if (!findings.length) continue;
  perFile.push({
    file: relative(root, file) || '.',
    findings
  });
  for (const finding of findings) {
    if (finding.adaptedByShim) {
      const prevAdapted = shimAdaptedTotals.get(finding.id) || 0;
      shimAdaptedTotals.set(finding.id, prevAdapted + finding.count);
      continue;
    }
    const prev = totals.get(finding.id) || { severity: finding.severity, count: 0 };
    prev.count += finding.count;
    totals.set(finding.id, prev);
  }
}

const summary = {
  scannedFiles: files.length,
  matchedFiles: perFile.length,
  totals: Object.fromEntries(totals.entries()),
  shimAdaptedTotals: Object.fromEntries(shimAdaptedTotals.entries()),
  findings: perFile
};

console.log(JSON.stringify(summary, null, 2));
