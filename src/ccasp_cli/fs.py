import os
import shutil
import subprocess
from dataclasses import dataclass
from typing import Optional


@dataclass(frozen=True)
class LinkResult:
    created: bool
    repaired: bool
    skipped: bool
    message: str


def _is_link_to(path: str, target: str) -> bool:
    if not os.path.exists(path):
        return False
    if os.path.islink(path):
        return os.path.realpath(path) == os.path.realpath(target)
    try:
        return os.path.samefile(path, target)
    except OSError:
        return False


def _remove_path(path: str) -> None:
    if os.path.islink(path) or os.path.isfile(path):
        os.unlink(path)
        return
    if os.path.isdir(path):
        shutil.rmtree(path)


def link_dir(path: str, target: str, is_windows: bool, dry_run: bool, repair: bool) -> LinkResult:
    if _is_link_to(path, target):
        return LinkResult(False, False, True, f"Link ok: {path} -> {target}")

    if os.path.exists(path):
        if not repair:
            return LinkResult(False, False, True, f"Exists (repair disabled): {path}")
        if dry_run:
            return LinkResult(False, True, False, f"Would repair link: {path} -> {target}")
        _remove_path(path)

    if dry_run:
        return LinkResult(True, False, False, f"Would create link: {path} -> {target}")

    os.makedirs(os.path.dirname(path), exist_ok=True)

    if is_windows:
        try:
            os.symlink(target, path, target_is_directory=True)
            return LinkResult(True, False, False, f"Symlink created: {path} -> {target}")
        except (OSError, NotImplementedError):
            cmd = ["cmd", "/c", "mklink", "/J", path, target]
            try:
                subprocess.check_call(cmd)
                return LinkResult(True, False, False, f"Junction created: {path} -> {target}")
            except (OSError, subprocess.CalledProcessError) as exc:
                return LinkResult(False, False, False, f"Failed to create junction: {exc}")
    else:
        try:
            os.symlink(target, path)
            return LinkResult(True, False, False, f"Symlink created: {path} -> {target}")
        except OSError as exc:
            return LinkResult(False, False, False, f"Failed to create symlink: {exc}")
