import os
from dataclasses import dataclass
from typing import Any, Dict, List


try:
    import yaml  # type: ignore
except Exception:  # pragma: no cover
    yaml = None


@dataclass
class CommandSpec:
    command_id: str
    title: str
    description: str
    codex_support: str  # "full" | "partial" | "unsupported" — defaults to "partial"
    system: str
    instructions: List[str]
    metadata: Dict[str, Any]


def require_yaml() -> None:
    if yaml is None:
        raise RuntimeError("PyYAML is required. Install with: pip install pyyaml")


def load_command(path: str) -> CommandSpec:
    require_yaml()
    with open(path, "r", encoding="utf-8") as fh:
        data = yaml.safe_load(fh) or {}
    _known = {"id", "title", "description", "codex_support", "system", "instructions"}
    command_id = data.get("id") or os.path.splitext(os.path.basename(path))[0]
    instructions = data.get("instructions") or []
    if isinstance(instructions, str):
        instructions = [instructions]
    return CommandSpec(
        command_id=command_id,
        title=data.get("title", command_id),
        description=data.get("description", ""),
        codex_support=data.get("codex_support", "partial"),
        system=data.get("system", ""),
        instructions=list(instructions),
        metadata={k: v for k, v in data.items() if k not in _known},
    )


def load_commands(commands_dir: str) -> List[CommandSpec]:
    if not os.path.isdir(commands_dir):
        return []
    specs: List[CommandSpec] = []
    for name in sorted(os.listdir(commands_dir)):
        if not name.endswith(".yaml") and not name.endswith(".yml"):
            continue
        specs.append(load_command(os.path.join(commands_dir, name)))
    return specs
