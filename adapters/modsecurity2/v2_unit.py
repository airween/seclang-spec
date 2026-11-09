"""Unit tier: v2's own msc_test for operators and transformations; re_groups cases through httpd
with the v3 adapter's capture rules, since msc_test reports only the operator's return code."""
from __future__ import annotations

import os
import subprocess
import tempfile
from pathlib import Path

import httpd
import v2_engine
from data import UnitCase, byte_string, latin1
from unit_tier import UnitResult, check_unit, messages, unit_rules

ENV_MSC_TEST = "MODSECURITY2_MSC_TEST"
# v2 leaves REQUEST_BODY absent without a body processor; the ctl is the specified way to
# get it (05-variables.md#request_body, ADR-0022). The v3 rules' ids are 2 and 10-19.
_FORCE_BODY = b'\nSecAction "id:1,phase:1,pass,nolog,ctl:forceRequestBodyVariable=On"\n'


def msc_escape(s: str) -> str:
    """Byte string -> msc_test -p argument; msc_test decodes \\xNN (tests/msc_test.c, unescape_inplace)."""
    return "".join(ch if 0x21 <= ord(ch) <= 0x7E and ch != "\\" else f"\\x{ord(ch):02x}" for ch in s)


def msc_test_args(c: UnitCase) -> list[str]:
    if c.type == "tfn":
        return ["-t", "tfn", "-n", c.name, "-p", msc_escape(c.output)]
    return ["-t", "op", "-n", c.name, "-p", msc_escape(c.param or ""), "-r", str(c.ret)]


def _label(c: UnitCase) -> str:
    return f"t:{c.name} on {c.input!r}" if c.type == "tfn" else f"@{c.name} {c.param!r} on {c.input!r}"


def _run_msc_test(c: UnitCase) -> list[str]:
    r = subprocess.run([os.environ[ENV_MSC_TEST], *msc_test_args(c)], input=latin1(c.input), capture_output=True)
    if r.returncode == 0:
        return []
    return [f"{_label(c)}: msc_test exit {r.returncode}: " + " | ".join(
        r.stderr.decode("latin-1").strip().splitlines())]


def _run_re_groups(c: UnitCase, backend: httpd.Backend) -> list[str]:
    if c.param and any(ord(ch) < 0x20 for ch in c.param):
        return []  # a control character cannot be written inside a directive argument
    body = latin1(c.input)
    raw = (b"POST / HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/octet-stream\r\n"
           b"Content-Length: %d\r\nConnection: close\r\n\r\n" % len(body)) + body
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        conf, port = httpd.write_root(root, unit_rules(c) + _FORCE_BODY, {}, backend.port)
        err = httpd.configtest(conf)
        if err:
            return [f"{_label(c)}: rule failed to load: {err}"]
        with httpd.Httpd(conf, port):
            start = v2_engine.log_sizes(root)
            v2_engine.send(port, raw)
            _, log = v2_engine.stage_logs(root, start)
    msgs = messages(log.splitlines())
    r = UnitResult(matched=2 in msgs)
    for i in range(10):
        if 10 + i not in msgs:
            break
        r.groups.append(byte_string(bytes.fromhex(msgs[10 + i].decode())))
    return check_unit(c, r)


def run_unit_file(cases: list[UnitCase], backend: httpd.Backend) -> list[str]:
    """Every failing case of a unit file in words; empty when all pass."""
    failures = []
    for c in cases:
        failures += _run_re_groups(c, backend) if c.re_groups else _run_msc_test(c)
    return failures
