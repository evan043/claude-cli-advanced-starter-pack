from .base import BaseAdapter
from ..commands import CommandSpec


class ClaudeAdapter(BaseAdapter):
    name = "claude"

    def output_path(self, spec: CommandSpec) -> str:
        return f"{self.output_dir}/commands/{spec.command_id}.md"

    def render(self, spec: CommandSpec) -> str:
        parts = [f"# {spec.title}"]
        if spec.description:
            parts.append("")
            parts.append(spec.description)
        if spec.system:
            parts.append("")
            parts.append("## System")
            parts.append(spec.system)
        if spec.instructions:
            parts.append("")
            parts.append("## Instructions")
            for item in spec.instructions:
                parts.append(f"- {item}")
        return "\n".join(parts).rstrip() + "\n"
