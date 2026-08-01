from dataclasses import dataclass
from typing import List

from .env import OSDetection, RuntimeDetection
from .project import InitPlan, ProjectStatus


@dataclass
class WizardChoice:
    key: str
    label: str


def choose(prompt: str, choices: List[WizardChoice], default_key: str) -> str:
    print(prompt)
    for choice in choices:
        marker = "*" if choice.key == default_key else " "
        print(f"  {marker} [{choice.key}] {choice.label}")
    while True:
        value = input(f"Select [{default_key}]: ").strip().lower() or default_key
        if any(c.key == value for c in choices):
            return value
        print("Invalid selection.")


def yes_no(prompt: str, default: bool) -> bool:
    suffix = "Y/n" if default else "y/N"
    while True:
        value = input(f"{prompt} [{suffix}]: ").strip().lower()
        if not value:
            return default
        if value in {"y", "yes"}:
            return True
        if value in {"n", "no"}:
            return False
        print("Please enter y or n.")


def plan_from_wizard(status: ProjectStatus, os_info: OSDetection, runtime_info: RuntimeDetection) -> InitPlan:
    print("CCASP Wizard")
    print("=")
    print(f"OS: {os_info.system}{' (WSL)' if os_info.is_wsl else ''}")
    print(f"Claude CLI: {'yes' if runtime_info.claude_cli else 'no'}")
    print(f"Codex CLI: {'yes' if runtime_info.codex_cli else 'no'}")
    print("")

    choices = [
        WizardChoice("fresh", "Fresh setup"),
        WizardChoice("legacy_claude", "Convert legacy Claude project"),
        WizardChoice("legacy_codex", "Convert legacy Codex project"),
        WizardChoice("merge", "Merge dual runtime"),
        WizardChoice("repair", "Repair broken symlinks"),
    ]
    selection = choose("Choose a setup path:", choices, default_key="fresh")

    convert_legacy = selection in {"legacy_claude", "legacy_codex", "merge"}
    repair_links = selection == "repair"

    enable_claude = yes_no("Enable Claude runtime?", default=True)
    enable_codex = yes_no("Enable Codex runtime?", default=False)

    if selection == "legacy_codex":
        enable_codex = True
    if selection == "legacy_claude":
        enable_claude = True

    print("")
    dual_runtime = yes_no("Enable dual runtime mode?", default=enable_claude and enable_codex)
    hooks_enabled = yes_no("Enable hooks?", default=True)
    governance = choose(
        "Governance mode:",
        [
            WizardChoice("standard", "Standard"),
            WizardChoice("strict", "Strict enforcement"),
            WizardChoice("off", "Off"),
        ],
        default_key="standard",
    )

    default_runtime = "claude" if enable_claude else "codex"
    if enable_claude and enable_codex and dual_runtime:
        default_runtime = choose(
            "Default runtime:",
            [WizardChoice("claude", "Claude"), WizardChoice("codex", "Codex")],
            default_key="claude",
        )

    print("")
    print("Summary:")
    print(f"  Convert legacy: {'yes' if convert_legacy else 'no'}")
    print(f"  Repair links: {'yes' if repair_links else 'no'}")
    print(f"  Enable Claude: {'yes' if enable_claude else 'no'}")
    print(f"  Enable Codex: {'yes' if enable_codex else 'no'}")
    print(f"  Dual runtime: {'yes' if dual_runtime else 'no'}")
    print(f"  Hooks: {'yes' if hooks_enabled else 'no'}")
    print(f"  Governance: {governance}")
    print(f"  Default runtime: {default_runtime}")
    print("")
    confirm = yes_no("Apply changes?", default=True)
    if not confirm:
        return InitPlan(enable_claude=False, enable_codex=False, convert_legacy=False, repair_links=False)

    return InitPlan(
        enable_claude=enable_claude,
        enable_codex=enable_codex,
        convert_legacy=convert_legacy,
        repair_links=repair_links,
        config_updates={
            "default_runtime": default_runtime,
            "dual_runtime": str(dual_runtime).lower(),
            "hooks_enabled": str(hooks_enabled).lower(),
            "governance_mode": governance,
        },
    )
