import fs from 'fs';
import path from 'path';
import yaml from 'yaml';

export function loadCommands(commandsDir) {
  if (!fs.existsSync(commandsDir)) return [];
  const KNOWN_FIELDS = ['id', 'title', 'description', 'codex_support', 'system', 'instructions'];
  const specs = [];
  for (const file of fs.readdirSync(commandsDir).sort()) {
    if (!file.endsWith('.yaml') && !file.endsWith('.yml')) continue;
    const full = path.join(commandsDir, file);
    const raw = fs.readFileSync(full, 'utf8');
    const data = yaml.parse(raw) || {};
    const id = data.id || path.basename(file, path.extname(file));
    const instructions = Array.isArray(data.instructions) ? data.instructions : (data.instructions ? [data.instructions] : []);
    specs.push({
      id,
      title: data.title || id,
      description: data.description || '',
      codexSupport: data.codex_support || 'partial',
      system: data.system || '',
      instructions,
      metadata: Object.fromEntries(Object.entries(data).filter(([k]) => !KNOWN_FIELDS.includes(k))),
    });
  }
  return specs;
}

// Metadata keys promoted into the rendered frontmatter, in emit order.
const FRONTMATTER_KEYS = [
  'argument-hint', 'allowed-tools', 'model', 'category', 'type', 'complexity', 'options'
];

export function renderClaude(spec) {
  // Emit real YAML frontmatter. Claude Code reads `description` from here; a
  // command without it falls back to showing its first line instead.
  const frontmatter = {};
  if (spec.description) frontmatter.description = spec.description;
  for (const key of FRONTMATTER_KEYS) {
    const value = spec.metadata?.[key];
    if (value !== undefined && value !== null && value !== '') {
      frontmatter[key] = value;
    }
  }
  if (spec.codexSupport) frontmatter['codex-support'] = spec.codexSupport;

  const parts = [];
  if (Object.keys(frontmatter).length > 0) {
    parts.push('---', yaml.stringify(frontmatter, { lineWidth: 0 }).trimEnd(), '---', '');
  }
  parts.push(`# ${spec.title}`);
  if (spec.system) {
    parts.push('', '## System', spec.system);
  }
  if (spec.instructions && spec.instructions.length > 0) {
    parts.push('', '## Instructions');
    for (const item of spec.instructions) {
      parts.push(`- ${item}`);
    }
  }
  return `${parts.join('\n').trim()}\n`;
}

export function renderCodex(spec) {
  const description = spec.description || `Run CCASP command: ${spec.title}`;
  const codexSupport = spec.codexSupport || 'partial';
  const lines = [
    '---',
    `description: ${JSON.stringify(description)}`,
    `argument-hint: ${JSON.stringify('[optional context or args]')}`,
    `codex-support: ${codexSupport}`,
    '---',
    '',
    '<!-- CCASP-CODEX-PROMPT -->',
    `<!-- CCASP-COMMAND-ID: ${spec.id} -->`,
    '',
    `Run CCASP command \`${spec.id}\` in the current Codex session.`,
    '',
    'Behavior requirements:',
    '- Stay in this current session and working directory.',
    '- Do not paste, echo, or summarize the full command template verbatim.',
    '- Load detailed command instructions from `.claude/commands/<command-id>.md` when available.',
    '- If `.claude/commands/<command-id>.md` is unavailable, load `.ccasp/runtime/claude/commands/<command-id>.md`.',
    '- Treat any text entered after the command as initial arguments/context.',
    '- If required inputs are missing, ask only the minimum concise follow-up questions.',
    '- Otherwise start executing immediately.',
  ];
  return `${lines.join('\n').trim()}\n`;
}
