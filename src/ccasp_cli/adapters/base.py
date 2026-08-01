import os
from dataclasses import dataclass
from typing import Iterable

from ..commands import CommandSpec


@dataclass(frozen=True)
class AdapterResult:
    written: int
    output_dir: str


class BaseAdapter:
    name = "base"

    def __init__(self, output_dir: str) -> None:
        self.output_dir = output_dir

    def prepare(self) -> None:
        os.makedirs(self.output_dir, exist_ok=True)

    def render(self, spec: CommandSpec) -> str:
        raise NotImplementedError

    def output_path(self, spec: CommandSpec) -> str:
        raise NotImplementedError

    def write(self, specs: Iterable[CommandSpec]) -> AdapterResult:
        self.prepare()
        written = 0
        for spec in specs:
            content = self.render(spec)
            path = self.output_path(spec)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(content)
            written += 1
        return AdapterResult(written=written, output_dir=self.output_dir)
