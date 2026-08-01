import os
import shutil
from dataclasses import dataclass
from datetime import datetime
from typing import Dict, List, Optional, Tuple

from .adapters.claude import ClaudeAdapter
from .adapters.codex import CodexAdapter
from .commands import CommandSpec, load_commands, require_yaml
from .env import OSDetection, RuntimeDetection
from .fs import LinkResult, link_dir


@dataclass
class ProjectStatus:
    root: str
    has_ccasp: bool
    has_claude: bool
    has_codex: bool
    has_claude_md: bool
    has_legacy_commands: bool
    has_legacy_hooks: bool
    legacy_detected: bool
    broken_claude_link: bool
    broken_codex_link: bool


@dataclass
class InitPlan:
    enable_claude: bool
    enable_codex: bool
    convert_legacy: bool
    repair_links: bool
    config_updates: Optional[Dict[str, str]] = None


@dataclass
class ApplyResult:
    links: List[LinkResult]
    commands_written: int
    output_dirs: List[str]


def scan_project(root: str) -> ProjectStatus:
    ccasp_dir = os.path.join(root, ".ccasp")
    claude_dir = os.path.join(root, ".claude")
    codex_dir = os.path.join(root, ".codex")
    claude_md = os.path.join(root, "CLAUDE.md")
    legacy_commands = os.path.join(claude_dir, "commands")
    legacy_hooks = os.path.join(claude_dir, "hooks")

    has_ccasp = os.path.isdir(ccasp_dir)
    has_claude = os.path.exists(claude_dir)
    has_codex = os.path.exists(codex_dir)
    has_claude_md = os.path.isfile(claude_md)
    has_legacy_commands = os.path.isdir(legacy_commands)
    has_legacy_hooks = os.path.isdir(legacy_hooks)

    broken_claude_link = False
    broken_codex_link = False
    if has_claude and os.path.islink(claude_dir):
        if not os.path.exists(os.path.realpath(claude_dir)):
            broken_claude_link = True
    if has_codex and os.path.islink(codex_dir):
        if not os.path.exists(os.path.realpath(codex_dir)):
            broken_codex_link = True

    legacy_detected = any([has_claude, has_codex, has_claude_md, has_legacy_commands, has_legacy_hooks])

    return ProjectStatus(
        root=root,
        has_ccasp=has_ccasp,
        has_claude=has_claude,
        has_codex=has_codex,
        has_claude_md=has_claude_md,
        has_legacy_commands=has_legacy_commands,
        has_legacy_hooks=has_legacy_hooks,
        legacy_detected=legacy_detected,
        broken_claude_link=broken_claude_link,
        broken_codex_link=broken_codex_link,
    )


def ensure_ccasp_layout(root: str, dry_run: bool) -> None:
    paths = [
        os.path.join(root, ".ccasp", "core"),
        os.path.join(root, ".ccasp", "commands"),
        os.path.join(root, ".ccasp", "agents"),
        os.path.join(root, ".ccasp", "hooks"),
        os.path.join(root, ".ccasp", "templates"),
        os.path.join(root, ".ccasp", "runtime", "claude"),
        os.path.join(root, ".ccasp", "runtime", "codex"),
        os.path.join(root, ".ccasp", "legacy_backup"),
    ]
    for path in paths:
        if dry_run:
            continue
        os.makedirs(path, exist_ok=True)


def write_default_config(root: str, dry_run: bool) -> None:
    config_path = os.path.join(root, ".ccasp", "config.yaml")
    if os.path.exists(config_path):
        return
    if dry_run:
        return
    content = (
        "version: 1\n"
        "default_runtime: claude\n"
        # Matches the JS writer in src/ccasp/init.js; a false default here left
        # projects without Codex artifacts depending on which CLI ran init.
        "dual_runtime: true\n"
        "hooks_enabled: true\n"
        "governance_mode: standard\n"
    )
    with open(config_path, "w", encoding="utf-8") as fh:
        fh.write(content)


def update_config(root: str, updates: Optional[Dict[str, str]], dry_run: bool) -> None:
    if not updates:
        return
    config_path = os.path.join(root, ".ccasp", "config.yaml")
    if dry_run:
        return
    existing = {}
    if os.path.exists(config_path):
        with open(config_path, "r", encoding="utf-8") as fh:
            for line in fh:
                if ":" in line:
                    key, value = line.split(":", 1)
                    existing[key.strip()] = value.strip()
    existing.update(updates)
    lines = [f"{key}: {value}" for key, value in existing.items()]
    with open(config_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")


def write_default_command(root: str, dry_run: bool) -> None:
    commands_dir = os.path.join(root, ".ccasp", "commands")
    example_path = os.path.join(commands_dir, "plan.yaml")
    if os.path.exists(example_path):
        return
    if dry_run:
        return
    content = (
        "id: plan\n"
        "title: Plan Tasks\n"
        "description: Create a focused, step-by-step plan before making changes.\n"
        "system: You are a senior systems architect.\n"
        "instructions:\n"
        "  - Restate the goal in one sentence.\n"
        "  - Propose a minimal plan with 2-6 steps.\n"
        "  - Call out risks and dependencies.\n"
    )
    with open(example_path, "w", encoding="utf-8") as fh:
        fh.write(content)


def backup_legacy(root: str, paths: List[str], dry_run: bool) -> Optional[str]:
    if not paths:
        return None
    stamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    backup_root = os.path.join(root, ".ccasp", "legacy_backup", stamp)
    if dry_run:
        return backup_root
    os.makedirs(backup_root, exist_ok=True)
    for path in paths:
        if not os.path.exists(path):
            continue
        target = os.path.join(backup_root, os.path.basename(path))
        shutil.move(path, target)
    return backup_root


def convert_legacy_commands(root: str, dry_run: bool) -> int:
    legacy_commands_dir = os.path.join(root, ".claude", "commands")
    commands_dir = os.path.join(root, ".ccasp", "commands")
    if not os.path.isdir(legacy_commands_dir):
        return 0
    converted = 0
    for name in sorted(os.listdir(legacy_commands_dir)):
        if not name.endswith(".md"):
            continue
        src_path = os.path.join(legacy_commands_dir, name)
        command_id = os.path.splitext(name)[0]
        dest_path = os.path.join(commands_dir, f"{command_id}.yaml")
        if os.path.exists(dest_path):
            continue
        if dry_run:
            converted += 1
            continue
        with open(src_path, "r", encoding="utf-8") as fh:
            raw = fh.read().strip()
        title = command_id.replace("_", " ").title()
        body = raw
        if raw.startswith("#"):
            lines = raw.splitlines()
            title = lines[0].lstrip("# ").strip() or title
            body = "\n".join(lines[1:]).strip()
        content = (
            f"id: {command_id}\n"
            f"title: {title}\n"
            "description: Converted from legacy Claude command.\n"
            "system: You are a senior systems architect.\n"
            "instructions:\n"
            f"  - {body.replace('\n', '\n  - ')}\n"
        )
        with open(dest_path, "w", encoding="utf-8") as fh:
            fh.write(content)
        converted += 1
    return converted


def convert_legacy_hooks(root: str, dry_run: bool) -> int:
    legacy_hooks_dir = os.path.join(root, ".claude", "hooks")
    if not os.path.isdir(legacy_hooks_dir):
        return 0
    dest_dir = os.path.join(root, ".ccasp", "hooks")
    if dry_run:
        return len(os.listdir(legacy_hooks_dir))
    for name in os.listdir(legacy_hooks_dir):
        src_path = os.path.join(legacy_hooks_dir, name)
        dst_path = os.path.join(dest_dir, name)
        if os.path.exists(dst_path):
            continue
        if os.path.isdir(src_path):
            shutil.copytree(src_path, dst_path)
        else:
            shutil.copy2(src_path, dst_path)
    return len(os.listdir(legacy_hooks_dir))


def generate_runtime_outputs(root: str, dry_run: bool) -> Tuple[int, List[str]]:
    require_yaml()
    commands_dir = os.path.join(root, ".ccasp", "commands")
    specs = load_commands(commands_dir)
    if not specs:
        return 0, []
    outputs = []
    written_total = 0
    if dry_run:
        return len(specs) * 2, [
            os.path.join(root, ".ccasp", "runtime", "claude"),
            os.path.join(root, ".ccasp", "runtime", "codex"),
        ]
    claude_adapter = ClaudeAdapter(os.path.join(root, ".ccasp", "runtime", "claude"))
    codex_adapter = CodexAdapter(os.path.join(root, ".ccasp", "runtime", "codex"))
    for adapter in (claude_adapter, codex_adapter):
        result = adapter.write(specs)
        written_total += result.written
        outputs.append(result.output_dir)
    return written_total, outputs


def apply_setup(
    status: ProjectStatus,
    os_info: OSDetection,
    runtime_info: RuntimeDetection,
    plan: InitPlan,
    dry_run: bool,
) -> ApplyResult:
    ensure_ccasp_layout(status.root, dry_run)
    write_default_config(status.root, dry_run)
    write_default_command(status.root, dry_run)
    update_config(status.root, plan.config_updates, dry_run)

    links: List[LinkResult] = []

    if plan.convert_legacy and status.legacy_detected:
        convert_legacy_commands(status.root, dry_run)
        convert_legacy_hooks(status.root, dry_run)
        legacy_paths = []
        if os.path.exists(os.path.join(status.root, ".claude")):
            legacy_paths.append(os.path.join(status.root, ".claude"))
        if os.path.exists(os.path.join(status.root, ".codex")):
            legacy_paths.append(os.path.join(status.root, ".codex"))
        if os.path.exists(os.path.join(status.root, "CLAUDE.md")):
            legacy_paths.append(os.path.join(status.root, "CLAUDE.md"))
        backup_legacy(status.root, legacy_paths, dry_run)

    commands_written, output_dirs = generate_runtime_outputs(status.root, dry_run)

    claude_target = os.path.join(status.root, ".ccasp", "runtime", "claude")
    codex_target = os.path.join(status.root, ".ccasp", "runtime", "codex")

    if plan.enable_claude:
        links.append(
            link_dir(
                os.path.join(status.root, ".claude"),
                claude_target,
                is_windows=os_info.is_windows,
                dry_run=dry_run,
                repair=plan.repair_links,
            )
        )

    if plan.enable_codex:
        links.append(
            link_dir(
                os.path.join(status.root, ".codex"),
                codex_target,
                is_windows=os_info.is_windows,
                dry_run=dry_run,
                repair=plan.repair_links,
            )
        )

    return ApplyResult(links=links, commands_written=commands_written, output_dirs=output_dirs)
