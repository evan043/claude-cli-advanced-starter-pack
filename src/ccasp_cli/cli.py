import argparse
import os
from typing import List, Optional

from .env import detect_os, detect_runtimes
from .project import InitPlan, apply_setup, scan_project
from .wizard import plan_from_wizard


def print_status(status) -> None:
    print("Status Summary")
    print("=")
    print(f"Project: {status.root}")
    print(f".ccasp/ present: {'yes' if status.has_ccasp else 'no'}")
    print(f".claude present: {'yes' if status.has_claude else 'no'}")
    print(f".codex present: {'yes' if status.has_codex else 'no'}")
    print(f"CLAUDE.md present: {'yes' if status.has_claude_md else 'no'}")
    print(f"Legacy commands: {'yes' if status.has_legacy_commands else 'no'}")
    print(f"Legacy hooks: {'yes' if status.has_legacy_hooks else 'no'}")
    if status.broken_claude_link:
        print("Broken .claude link detected")
    if status.broken_codex_link:
        print("Broken .codex link detected")
    print("")


def run_init(args: argparse.Namespace) -> int:
    root = os.getcwd()
    os_info = detect_os()
    runtime_info = detect_runtimes()
    status = scan_project(root)

    print_status(status)
    print(f"OS: {os_info.system}{' (WSL)' if os_info.is_wsl else ''}")
    print(f"Claude CLI: {'yes' if runtime_info.claude_cli else 'no'}")
    print(f"Codex CLI: {'yes' if runtime_info.codex_cli else 'no'}")
    print("")

    convert_legacy = status.legacy_detected and args.convert_legacy
    enable_claude = args.enable_claude
    enable_codex = args.enable_codex

    if not args.non_interactive:
        if status.legacy_detected and not args.convert_legacy:
            convert_legacy = input("Legacy detected. Convert? [y/N]: ").strip().lower() in {"y", "yes"}
        if not args.enable_claude:
            enable_claude = input("Enable Claude runtime? [Y/n]: ").strip().lower() not in {"n", "no"}
        if not args.enable_codex:
            enable_codex = input("Enable Codex runtime? [y/N]: ").strip().lower() in {"y", "yes"}

    plan = InitPlan(
        enable_claude=enable_claude,
        enable_codex=enable_codex,
        convert_legacy=convert_legacy,
        repair_links=args.repair_links,
    )

    result = apply_setup(status, os_info, runtime_info, plan, dry_run=args.dry_run)

    print("Applied")
    print("=")
    for link in result.links:
        print(link.message)
    print(f"Commands generated: {result.commands_written}")
    if args.dry_run:
        print("Dry-run mode: no changes applied")
    return 0


def run_wizard(args: argparse.Namespace) -> int:
    root = os.getcwd()
    os_info = detect_os()
    runtime_info = detect_runtimes()
    status = scan_project(root)

    print_status(status)
    plan = plan_from_wizard(status, os_info, runtime_info)
    if not plan.enable_claude and not plan.enable_codex and not plan.convert_legacy:
        print("No changes applied")
        return 0

    result = apply_setup(status, os_info, runtime_info, plan, dry_run=args.dry_run)
    print("Applied")
    print("=")
    for link in result.links:
        print(link.message)
    print(f"Commands generated: {result.commands_written}")
    if args.dry_run:
        print("Dry-run mode: no changes applied")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="ccasp", description="CCASP runtime-agnostic orchestration CLI")
    parser.add_argument("--dry-run", action="store_true", help="Preview changes without writing")
    parser.add_argument("--verbose", action="store_true", help="Verbose output")

    sub = parser.add_subparsers(dest="command")

    init = sub.add_parser("init", help="Initialize CCASP in the current directory")
    init.add_argument("--convert-legacy", action="store_true", help="Convert legacy Claude/Codex setup")
    init.add_argument("--enable-claude", action="store_true", help="Enable Claude runtime")
    init.add_argument("--enable-codex", action="store_true", help="Enable Codex runtime")
    init.add_argument("--repair-links", action="store_true", help="Repair broken links")
    init.add_argument("--non-interactive", action="store_true", help="Skip prompts")
    init.set_defaults(func=run_init)

    wizard = sub.add_parser("wizard", help="Interactive setup flow")
    wizard.set_defaults(func=run_wizard)

    return parser


def main(argv: Optional[List[str]] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if not args.command:
        parser.print_help()
        return 1
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
