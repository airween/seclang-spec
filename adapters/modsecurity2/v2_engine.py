"""Engine tier: one httpd per profile, one HTTP request per stage, results from the debug log.

v2.9.15 writes one line per matched rule (nolog included; for a chain only when every member
matched, with the chain head's id), at debug level 4 or lower; the line formats are pinned by
test_adapter.ParseDebugLogTests.
"""
from __future__ import annotations

import re
import socket
import tempfile
import time
from pathlib import Path

import httpd
from data import Input, Interruption, Profile
from engine_tier import Observed, check_stage

_MESSAGE = re.compile(rb"\]\[\d\] (.*)$", re.M)
_ID = re.compile(rb'\[id "(\d+)"\]')
# Every "Access ..." message names its rule (apache2/re.c, apache2/modsecurity.c): denied with
# code N / connection close / redirection to URL using status N / using proxy to; allowed /
# to phase allowed / to request allowed.
_TRIGGERED = (b"Warning. ", b"Access ")
_DISRUPTIVE = ((b"Access denied with connection close", "drop"),
               (b"Access denied with redirection to ", "redirect"),
               (b"Access denied with code ", "deny"),
               (b"Access denied using proxy to", "proxy"))
# The status v2 decided; Apache answers 500 for a code it has no reason phrase for (418).
_STATUS = re.compile(rb"^Access denied with code (\d+)|^Access denied with redirection to .* using status (\d+)")
# The logging phase always ends with one "Audit log: ..." line (apache2/modsecurity.c,
# modsecurity_process_phase_logging); phase 5 runs after the response has been sent.
_DONE = re.compile(rb"Starting phase LOGGING\.[\s\S]*Audit log: ")
_LOG_WAIT = 2.0


def parse_debug_log(data: bytes) -> tuple[set[int], tuple[int, str, int | None] | None]:
    """Triggered rule ids and the first disruptive (rule id, action, status) in a debug-log segment."""
    triggered: set[int] = set()
    disruptive = None
    for m in _MESSAGE.finditer(data):
        msg = m.group(1)
        if not msg.startswith(_TRIGGERED):
            continue
        rid = _ID.search(msg)
        if not rid:
            continue
        rid = int(rid.group(1))
        triggered.add(rid)
        if disruptive is None:
            for prefix, action in _DISRUPTIVE:
                if msg.startswith(prefix):
                    st = _STATUS.match(msg)
                    disruptive = (rid, action, int(st.group(1) or st.group(2)) if st else None)
                    break
    return triggered, disruptive


def request_bytes(i: Input) -> bytes:
    headers = dict(i.headers)
    names = {k.lower() for k in headers}
    body = i.data.encode("utf-8")  # engine-tier data is UTF-8 text
    if "host" not in names:
        headers["Host"] = "localhost"
    if body and "content-length" not in names and "transfer-encoding" not in names:
        headers["Content-Length"] = str(len(body))
    if "connection" not in names:
        headers["Connection"] = "close"
    if i.remote_addr != "127.0.0.1":
        headers[httpd.REMOTE_ADDR_HEADER] = i.remote_addr
    head = f"{i.method} {i.uri} {i.version}\r\n" + "".join(f"{k}: {v}\r\n" for k, v in headers.items())
    return head.encode("utf-8") + b"\r\n" + body


def send(port: int, raw: bytes) -> tuple[int | None, dict[str, str]]:
    """Status and headers of the response; None when the connection closed without one (drop)."""
    data = b""
    with socket.create_connection(("127.0.0.1", port), timeout=10) as s:
        s.sendall(raw)
        try:
            while chunk := s.recv(65536):
                data += chunk
        except ConnectionResetError:
            pass
    if not data:
        return None, {}
    head = data.split(b"\r\n\r\n", 1)[0].decode("latin-1").split("\r\n")
    headers = dict(h.split(": ", 1) for h in head[1:] if ": " in h)
    return int(head[0].split(" ")[1]), headers


def interruption(status: int | None, disruptive: tuple[int, str, int | None] | None,
                 backend_status: int) -> Interruption | None:
    """The transaction's interruption; a status the backend was not asked for, with no rule
    behind it, is a body-limit interruption (rule_id 0)."""
    if disruptive is not None:
        rid, action, logged = disruptive
        return Interruption(rid, action, logged or status or 0)
    if status is not None and status != backend_status:
        return Interruption(0, "deny", status)
    return None


def _segment(path: Path, start: int) -> bytes:
    return path.read_bytes()[start:] if path.exists() else b""


def _size(path: Path) -> int:
    return path.stat().st_size if path.exists() else 0


def log_sizes(root: Path) -> tuple[int, int]:
    return _size(root / "debug.log"), _size(root / "error.log")


def stage_logs(root: Path, start: tuple[int, int]) -> tuple[bytes, bytes]:
    """Debug- and error-log segments written since start, once the logging phase has finished."""
    debug = root / "debug.log"
    deadline = time.monotonic() + _LOG_WAIT
    while not _DONE.search(_segment(debug, start[0])) and time.monotonic() < deadline:
        time.sleep(0.01)
    return _segment(debug, start[0]), _segment(root / "error.log", start[1])


def run_profile(p: Profile, backend: httpd.Backend) -> list[str]:
    """Every failure of the profile in words; empty when it passes."""
    expect_error = any(st.output.expect_error for t in p.tests for st in t.stages)
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        conf, port = httpd.write_root(root, p.rules, p.files, backend.port)
        err = httpd.configtest(conf)
        if expect_error:
            return [] if err else ["configuration loaded but expect_error was set"]
        if err:
            return [f"configuration failed to load: {err}"]
        failures = []
        with httpd.Httpd(conf, port):
            for t in p.tests:
                for n, st in enumerate(t.stages, 1):
                    backend.respond(st.response)
                    start = log_sizes(root)
                    status, _ = send(port, request_bytes(st.input))
                    segment, log = stage_logs(root, start)
                    triggered, disruptive = parse_debug_log(segment)
                    backend_status = st.response.status if st.response else 200
                    it = interruption(status, disruptive, backend_status)
                    where = f"{t.title} / stage {n}"
                    if it and it.rule_id == 0 and b"ModSecurity:" not in log:
                        failures.append(f"{where}: apache rejected the request (status {status})")
                        continue
                    o = Observed(triggered, it, log.decode("utf-8", "replace"))
                    failures += [f"{where}: {m}" for m in check_stage(o, st.output)]
        return failures
