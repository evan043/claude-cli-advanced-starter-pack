import json
import os

from .base import BaseAdapter
from ..commands import CommandSpec

_COMPAT_SHIM = """\
<!-- CCASP-CODEX-COMPAT:START -->
# Codex Runtime Compatibility

This prompt was authored for Claude-style slash workflows. In Codex runtime, adapt tool calls as follows:
- `AskUserQuestion` => ask the user directly in chat.
- `WebSearch`/`WebFetch` => use available web tools (`search_query`, `open`, `find`) and cite links.
- `Read`/`Write` => use shell/filesystem tools in this workspace.
- Claude-only MCP calls (for example Playwright MCP names) => use available equivalents or clearly state fallback.
- Keep intent and output format identical; only adapt execution mechanics.
<!-- CCASP-CODEX-COMPAT:END -->
"""


class CodexAdapter(BaseAdapter):
    name = "codex"

    def output_path(self, spec: CommandSpec) -> str:
        return f"{self.output_dir}/prompts/{spec.command_id}.md"

    def render(self, spec: CommandSpec) -> str:
        description = spec.description or f"Run CCASP command: {spec.title}"
        codex_support = getattr(spec, "codex_support", "partial") or "partial"
        lines = [
            "---",
            f"description: {json.dumps(description)}",
            f"argument-hint: {json.dumps('[optional context or args]')}",
            f"codex-support: {codex_support}",
            "---",
            "",
            _COMPAT_SHIM.rstrip(),
            "",
            "<!-- CCASP-CODEX-PROMPT -->",
            f"<!-- CCASP-COMMAND-ID: {spec.command_id} -->",
            "",
            f"Run CCASP command `{spec.command_id}` in the current Codex session.",
            "",
            "Behavior requirements:",
            "- Stay in this current session and working directory.",
            "- Do not paste, echo, or summarize the full command template verbatim.",
            "- Load detailed command instructions from `.claude/commands/<command-id>.md` when available.",
            "- If `.claude/commands/<command-id>.md` is unavailable, load `.ccasp/runtime/claude/commands/<command-id>.md`.",
            "- Treat any text entered after the command as initial arguments/context.",
            "- If required inputs are missing, ask only the minimum concise follow-up questions.",
            "- Otherwise start executing immediately.",
        ]
        return "\n".join(lines).rstrip() + "\n"

    def write(self, specs):
        """Override write to also clean up legacy .txt files."""
        result = super().write(specs)
        prompts_dir = os.path.join(self.output_dir, "prompts")
        if os.path.isdir(prompts_dir):
            for fname in os.listdir(prompts_dir):
                if fname.endswith(".txt"):
                    try:
                        os.remove(os.path.join(prompts_dir, fname))
                    except OSError:
                        pass
        return result
