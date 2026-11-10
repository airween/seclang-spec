"""Rows of compat/known-gaps.md for one engine: {test path: behaviour today}."""
from __future__ import annotations

import os
import re
import sys
import unittest
from pathlib import Path

_PATH = re.compile(r"`(tests/[^`]+)`")
# "warn" turns an obsolete row into a GitHub warning instead of a failure: an engine's own CI
# (action.yml) must not fail because it fixed a known gap.
OBSOLETE_ENV = "SECLANG_OBSOLETE_GAPS"


def load_gaps(path: Path, engine: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in Path(path).read_text().splitlines():
        if not line.startswith("| `tests/"):
            continue
        cells = line.strip("| ").split(" | ")
        if len(cells) < 3 or engine.lower() not in cells[1].lower():
            continue
        for p in _PATH.findall(cells[0]):
            out[p] = cells[2].strip()
    return out


def report(case: unittest.TestCase, path: str, known: dict[str, str], failures: list[str]) -> None:
    """Gate one file's failures by its known-gaps row (ADR-0023)."""
    reason = known.get(path)
    if reason is None:
        if failures:
            case.fail("\n".join(failures))
        return
    if not failures:
        msg = f"known-gaps row is obsolete: remove the row for {path} ({reason})"
        if os.environ.get(OBSOLETE_ENV) == "warn":
            print(f"::warning::{msg}")
            return
        case.fail(msg)
    for f in failures:
        print(f"expected (known gap: {reason}): {path}: {f}", file=sys.stderr)
