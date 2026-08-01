import os
import platform
import shutil
from dataclasses import dataclass
from typing import Optional


@dataclass(frozen=True)
class RuntimeDetection:
    claude_cli: bool
    codex_cli: bool
    claude_path: Optional[str]
    codex_path: Optional[str]


@dataclass(frozen=True)
class OSDetection:
    system: str
    is_windows: bool
    is_macos: bool
    is_linux: bool
    is_wsl: bool


def detect_os() -> OSDetection:
    system = platform.system()
    is_windows = system.lower().startswith("win")
    is_macos = system == "Darwin"
    is_linux = system == "Linux"
    is_wsl = False
    if is_linux:
        if os.environ.get("WSL_DISTRO_NAME") or os.environ.get("WSL_INTEROP"):
            is_wsl = True
        else:
            try:
                with open("/proc/version", "r", encoding="utf-8") as fh:
                    if "microsoft" in fh.read().lower():
                        is_wsl = True
            except OSError:
                pass
    return OSDetection(
        system=system,
        is_windows=is_windows,
        is_macos=is_macos,
        is_linux=is_linux,
        is_wsl=is_wsl,
    )


def detect_runtimes() -> RuntimeDetection:
    claude_path = shutil.which("claude") or shutil.which("claude.exe")
    codex_path = shutil.which("codex") or shutil.which("codex.exe")
    return RuntimeDetection(
        claude_cli=bool(claude_path),
        codex_cli=bool(codex_path),
        claude_path=claude_path,
        codex_path=codex_path,
    )
