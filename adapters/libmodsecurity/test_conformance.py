"""Runs tests/engine and tests/unit against libmodsecurity, gated by compat/known-gaps.md.

Gating (ADR-0023): a file without a known-gaps row for this engine must pass entirely; a
file with a row may fail (failures are printed as expected); a file with a row that passes
entirely fails with "known-gaps row is obsolete".
"""
from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path

import data
import engine_tier
import gaps
import mscapi
import unit_tier

ENGINE = "libmodsecurity v3"
# Extended anchors this engine implements; profiles requiring anything else are skipped.
IMPLEMENTED = {"05-variables.md#persistent-collections"}
# Extended/Deprecated features the library does not register; their files are skipped.
UNSUPPORTED_OPERATORS: set[str] = set()
UNSUPPORTED_TRANSFORMATIONS: set[str] = set()
UNSUPPORTED_ANCHORS: set[str] = set()

MS: mscapi.ModSecurity | None = None


def setUpModule():
    global MS
    if not os.environ.get(mscapi.ENV):
        raise unittest.SkipTest(f"{mscapi.ENV} not set")
    MS = mscapi.ModSecurity()


def run_profile(p: data.Profile) -> list[str]:
    expect_error = any(st.output.expect_error for t in p.tests for st in t.stages)
    with tempfile.TemporaryDirectory() as d:
        try:
            rules, debug = engine_tier.build_rules(MS, p, Path(d))
        except mscapi.LoadError as e:
            return [] if expect_error else [f"configuration failed to load: {e}"]
        try:
            if expect_error:
                return ["configuration loaded but expect_error was set"]
            failures = []
            for t in p.tests:
                for i, st in enumerate(t.stages, 1):
                    o = engine_tier.run_stage(MS, rules, debug, st)
                    failures += [f"{t.title} / stage {i}: {m}" for m in engine_tier.check_stage(o, st.output)]
            return failures
        finally:
            rules.close()


def has_control_chars(s: str | None) -> bool:
    return bool(s) and any(ord(ch) < 0x20 for ch in s)


def run_unit_file(cases: list[data.UnitCase]) -> list[str]:
    failures = []
    with tempfile.TemporaryDirectory() as d:
        loaded: dict[tuple, mscapi.RulesSet | None] = {}
        try:
            for c in cases:
                if has_control_chars(c.param):
                    continue  # a control character cannot be written inside a directive argument
                key = unit_tier.group_key(c)
                if key not in loaded:
                    try:
                        loaded[key] = unit_tier.load_rules(MS, c, Path(d))
                    except mscapi.LoadError as e:
                        loaded[key] = None
                        failures.append(f"@{c.name} {c.param!r}: rule failed to load: {e}")
                rules = loaded[key]
                if rules is None:
                    continue
                failures += unit_tier.check_unit(c, unit_tier.run_unit(MS, rules, c))
        finally:
            for r in loaded.values():
                if r is not None:
                    r.close()
    return failures


class Gated(unittest.TestCase):
    def report(self, path: str, known: dict[str, str], failures: list[str]):
        gaps.report(self, path, known, failures)


class TestEngine(Gated):
    def test_profiles(self):
        root = data.repo_root()
        known = gaps.load_gaps(root / "compat" / "known-gaps.md", ENGINE)
        for p in data.load_profiles(root):
            with self.subTest(p.path):
                missing = [r for r in p.requires if r not in IMPLEMENTED]
                if missing:
                    self.skipTest("requires " + missing[0])
                self.report(p.path, known, run_profile(p))


class TestUnit(Gated):
    def test_files(self):
        root = data.repo_root()
        known = gaps.load_gaps(root / "compat" / "known-gaps.md", ENGINE)
        for path, cases in data.load_unit_cases(root).items():
            with self.subTest(path):
                first = cases[0] if cases else None
                if first and first.type == "op" and first.name in UNSUPPORTED_OPERATORS:
                    self.skipTest("operator not implemented by libmodsecurity (Extended)")
                if first and first.type == "tfn" and first.name in UNSUPPORTED_TRANSFORMATIONS:
                    self.skipTest("transformation not implemented by libmodsecurity (Extended)")
                if first and first.spec in UNSUPPORTED_ANCHORS:
                    self.skipTest("Extended feature not implemented: " + first.spec)
                self.report(path, known, run_unit_file(cases))


if __name__ == "__main__":
    unittest.main()
