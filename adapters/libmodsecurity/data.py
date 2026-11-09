"""Loaders for tests/engine and tests/unit; the dataclasses mirror tests/schema/*."""
from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path

import yaml


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


@dataclass
class Input:
    method: str = "GET"
    uri: str = "/"
    version: str = "HTTP/1.1"
    headers: dict[str, str] = field(default_factory=dict)
    data: str = ""
    remote_addr: str = "127.0.0.1"


@dataclass
class Response:
    status: int = 200
    headers: dict[str, str] = field(default_factory=dict)
    data: str = ""


@dataclass
class Interruption:
    rule_id: int = 0
    action: str = ""
    status: int = 0


@dataclass
class Output:
    triggered_rules: list[int] = field(default_factory=list)
    non_triggered_rules: list[int] = field(default_factory=list)
    interruption: Interruption | None = None
    no_interruption: bool = False
    log_contains: str = ""
    no_log_contains: str = ""
    audit_log_contains: str = ""
    no_audit_log_contains: str = ""
    expect_error: bool = False


@dataclass
class Stage:
    input: Input
    response: Response | None
    output: Output


@dataclass
class Test:
    title: str
    stages: list[Stage]


@dataclass
class Profile:
    path: str  # relative to the repository root, POSIX separators
    requires: list[str]
    files: dict[str, str]
    rules: str
    tests: list[Test]


@dataclass
class UnitCase:
    type: str
    name: str
    param: str | None  # None when the case has no "param" key
    input: str
    output: str
    ret: int
    spec: str
    re_groups: list[str]


def _headers(d: dict | None) -> dict[str, str]:
    return {str(k): str(v) for k, v in (d or {}).items()}


def _input(d: dict) -> Input:
    return Input(
        method=d.get("method") or "GET",
        uri=d.get("uri") or "/",
        version=d.get("version") or "HTTP/1.1",
        headers=_headers(d.get("headers")),
        data=d.get("data") or "",
        remote_addr=d.get("remote_addr") or "127.0.0.1",
    )


def _response(d: dict | None) -> Response | None:
    if d is None:
        return None
    return Response(status=d.get("status") or 200, headers=_headers(d.get("headers")), data=d.get("data") or "")


def _output(d: dict) -> Output:
    it = d.get("interruption")
    return Output(
        triggered_rules=list(d.get("triggered_rules") or []),
        non_triggered_rules=list(d.get("non_triggered_rules") or []),
        interruption=Interruption(it.get("rule_id", 0), it.get("action", ""), it.get("status", 0)) if it else None,
        no_interruption=bool(d.get("no_interruption", False)),
        log_contains=d.get("log_contains") or "",
        no_log_contains=d.get("no_log_contains") or "",
        audit_log_contains=d.get("audit_log_contains") or "",
        no_audit_log_contains=d.get("no_audit_log_contains") or "",
        expect_error=bool(d.get("expect_error", False)),
    )


def load_profiles(root: Path) -> list[Profile]:
    out = []
    for path in sorted((root / "tests" / "engine").rglob("*.yaml")):
        doc = yaml.safe_load(path.read_text())
        tests = [Test(t.get("test_title", ""),
                      [Stage(_input(s["stage"].get("input") or {}),
                             _response(s["stage"].get("response")),
                             _output(s["stage"].get("output") or {}))
                       for s in t.get("stages") or []])
                 for t in doc.get("tests") or []]
        out.append(Profile(path.relative_to(root).as_posix(), list(doc.get("requires") or []),
                           dict(doc.get("files") or {}), doc.get("rules") or "", tests))
    return out


def load_unit_cases(root: Path) -> dict[str, list[UnitCase]]:
    out = {}
    for path in sorted((root / "tests" / "unit").rglob("*.json")):
        out[path.relative_to(root).as_posix()] = [
            UnitCase(c["type"], c["name"], c.get("param"), c.get("input", ""), c.get("output", ""),
                     int(c.get("ret", 0)), c.get("spec", ""), list(c.get("re_groups") or []))
            for c in json.loads(path.read_text())]
    return out


def latin1(s: str) -> bytes:
    """Byte string (one code point per byte) to bytes."""
    return s.encode("latin-1")


def byte_string(b: bytes) -> str:
    return b.decode("latin-1")
