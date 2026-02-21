/**
 * Cross-runtime prompt compatibility helpers.
 *
 * Ensures command prompts remain executable in both Claude and Codex runtimes.
 */

const COMPAT_START = '<!-- CCASP-CODEX-COMPAT:START -->';
const COMPAT_END = '<!-- CCASP-CODEX-COMPAT:END -->';

export function getRuntimeCompatibilityShim() {
  return [
    COMPAT_START,
    '# Codex Runtime Compatibility',
    '',
    'This prompt was authored for Claude-style slash workflows. In Codex runtime, adapt tool calls as follows:',
    '- `AskUserQuestion` => ask the user directly in chat.',
    '- `WebSearch`/`WebFetch` => use available web tools (`search_query`, `open`, `find`) and cite links.',
    '- `Read`/`Write` => use shell/filesystem tools in this workspace.',
    '- Claude-only MCP calls (for example Playwright MCP names) => use available equivalents or clearly state fallback.',
    '- Keep intent and output format identical; only adapt execution mechanics.',
    COMPAT_END,
    ''
  ].join('\n');
}

export function hasRuntimeCompatibilityShim(content) {
  return content.includes(COMPAT_START) && content.includes(COMPAT_END);
}

export function injectRuntimeCompatibilityShim(content) {
  if (hasRuntimeCompatibilityShim(content)) {
    return content;
  }
  return `${getRuntimeCompatibilityShim()}${content}`;
}

