"""Runs tests/engine and tests/unit against ModSecurity v2, gated by compat/known-gaps.md.

Gating (ADR-0023): a file without a known-gaps row for this engine must pass entirely; a
file with a row may fail (failures are printed as expected); a file with a row that passes
entirely fails with "known-gaps row is obsolete".
"""
from __future__ import annotations

import os
import unittest

import httpd  # first: puts adapters/libmodsecurity on sys.path
import data
import gaps
import v2_engine
import v2_unit

ENGINE = "ModSecurity v2"
# Extended anchors this engine implements; profiles requiring anything else are skipped.
IMPLEMENTED = {"05-variables.md#persistent-collections", "04-directives.md#secrequestbodyinmemorylimit"}
# Extended/Deprecated features v2 does not register; their files are skipped.
UNSUPPORTED_OPERATORS: set[str] = set()
UNSUPPORTED_TRANSFORMATIONS: set[str] = set()
UNSUPPORTED_ANCHORS: set[str] = set()

BACKEND: httpd.Backend | None = None


def setUpModule():
    global BACKEND
    for env in (httpd.ENV_HTTPD, v2_unit.ENV_MSC_TEST):
        if not os.environ.get(env):
            raise unittest.SkipTest(f"{env} not set")
    BACKEND = httpd.Backend().__enter__()


def tearDownModule():
    if BACKEND is not None:
        BACKEND.__exit__(None, None, None)


# Same as adapters/libmodsecurity/test_conformance.Gated; importing that module would make
# discovery here run its test classes too.
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
                self.report(p.path, known, v2_engine.run_profile(p, BACKEND))


class TestUnit(Gated):
    def test_files(self):
        root = data.repo_root()
        known = gaps.load_gaps(root / "compat" / "known-gaps.md", ENGINE)
        for path, cases in data.load_unit_cases(root).items():
            with self.subTest(path):
                first = cases[0] if cases else None
                if first and first.type == "op" and first.name in UNSUPPORTED_OPERATORS:
                    self.skipTest("operator not implemented by ModSecurity v2 (Extended)")
                if first and first.type == "tfn" and first.name in UNSUPPORTED_TRANSFORMATIONS:
                    self.skipTest("transformation not implemented by ModSecurity v2 (Extended)")
                if first and first.spec in UNSUPPORTED_ANCHORS:
                    self.skipTest("Extended feature not implemented: " + first.spec)
                self.report(path, known, v2_unit.run_unit_file(cases, BACKEND))


if __name__ == "__main__":
    unittest.main()
