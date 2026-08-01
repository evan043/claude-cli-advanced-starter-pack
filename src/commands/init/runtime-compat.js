/**
 * Cross-runtime prompt compatibility helpers.
 *
 * Ensures command prompts remain executable in both Claude and Codex runtimes.
 *
 * Two mechanisms:
 *
 * 1. CCASP-CODEX-COMPAT shim — injected at the top of every Codex prompt.
 *    Instructs Codex how to adapt Claude-only tool calls (AskUserQuestion,
 *    WebSearch/WebFetch, MCP calls, etc.).
 *
 * 2. CODEX-OVERRIDE blocks — optional per-template override content.
 *    When a template contains <!-- CODEX-OVERRIDE:START --> ... <!-- CODEX-OVERRIDE:END -->
 *    the sync pipeline extracts that block and uses it as the Codex prompt body
 *    instead of the full Claude template. This enables real divergent prompts for
 *    MCP-heavy commands where the compat shim alone is insufficient.
 */

const COMPAT_START = '<!-- CCASP-CODEX-COMPAT:START -->';
const COMPAT_END = '<!-- CCASP-CODEX-COMPAT:END -->';

const OVERRIDE_START = '<!-- CODEX-OVERRIDE:START -->';
const OVERRIDE_END = '<!-- CODEX-OVERRIDE:END -->';

const UNSUPPORTED_MARKER = '<!-- CODEX-SUPPORT: unsupported -->';

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

/**
 * Extract the CODEX-OVERRIDE block content if present.
 * Returns the trimmed body between the markers, or null if no override block exists.
 */
export function extractCodexOverride(content) {
  const start = content.indexOf(OVERRIDE_START);
  const end = content.indexOf(OVERRIDE_END);
  if (start === -1 || end === -1 || end <= start) return null;
  return content.slice(start + OVERRIDE_START.length, end).trim();
}

/**
 * Returns true if the file is marked as unsupported in Codex.
 */
export function isCodexUnsupported(content) {
  return content.includes(UNSUPPORTED_MARKER);
}

/**
 * Split leading YAML frontmatter from the body.
 * Returns { frontmatter, body }; frontmatter is '' when the file has none.
 */
function splitFrontmatter(content) {
  if (!content.startsWith('---\n')) return { frontmatter: '', body: content };
  const end = content.indexOf('\n---\n', 3);
  if (end === -1) return { frontmatter: '', body: content };
  const cut = end + '\n---\n'.length;
  return { frontmatter: content.slice(0, cut), body: content.slice(cut) };
}

/**
 * Inject the compat shim into a prompt, but only if it's not already present.
 * Standard path for files without a CODEX-OVERRIDE block.
 *
 * The shim goes *after* any YAML frontmatter — prepending it would push the
 * opening `---` off byte 0 and silently break frontmatter parsing.
 */
export function injectRuntimeCompatibilityShim(content) {
  if (hasRuntimeCompatibilityShim(content)) {
    return content;
  }
  const { frontmatter, body } = splitFrontmatter(content);
  return `${frontmatter}${getRuntimeCompatibilityShim()}${body}`;
}

/**
 * Remove a previously-injected compat shim, restoring the original content.
 * Used to clean Claude-side files that were shimmed by mistake.
 */
export function stripRuntimeCompatibilityShim(content) {
  const start = content.indexOf(COMPAT_START);
  if (start === -1) return content;
  const end = content.indexOf(COMPAT_END, start);
  if (end === -1) return content;

  let cut = end + COMPAT_END.length;
  if (content[cut] === '\n') cut += 1;
  return content.slice(0, start) + content.slice(cut);
}

/**
 * Prepare content for Codex runtime. Handles three cases:
 *
 *  1. CODEX-SUPPORT: unsupported — prepend shim with unsupported notice, return as-is.
 *  2. CODEX-OVERRIDE block present — extract override body, wrap with shim.
 *  3. No override — inject shim into the full content (existing behaviour).
 *
 * @param {string} content  Raw template file content
 * @returns {string}        Content ready to write to .codex/prompts/
 */
export function prepareForCodex(content) {
  // Case 1: explicitly unsupported — keep full content (unsupported marker visible to router)
  if (isCodexUnsupported(content)) {
    return injectRuntimeCompatibilityShim(content);
  }

  // Case 2: CODEX-OVERRIDE block present — use override body only
  const override = extractCodexOverride(content);
  if (override !== null) {
    return `${getRuntimeCompatibilityShim()}${override}\n`;
  }

  // Case 3: no override — inject shim into full content
  return injectRuntimeCompatibilityShim(content);
}

